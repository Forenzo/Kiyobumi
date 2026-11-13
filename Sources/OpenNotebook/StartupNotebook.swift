import SwiftUI
import AppKit

enum StartupNotebookFailure: LocalizedError {
    case chooseSavedNotebook, unavailableBookmark, missingNotebook
    var errorDescription: String? {
        switch self {
        case .chooseSavedNotebook: return "Choose an existing, saved .onbook notebook package."
        case .unavailableBookmark: return "The startup notebook location could not be restored. Choose it again in Settings."
        case .missingNotebook: return "The startup notebook is unavailable. Reconnect its drive or choose another notebook in Settings."
        }
    }
}

struct StartupNotebookAccess {
    let url: URL
    let scoped: Bool
    func release() { if scoped { url.stopAccessingSecurityScopedResource() } }
}

@MainActor
final class StartupNotebookPreferences: ObservableObject {
    static let shared = StartupNotebookPreferences()
    static let lastUsed = StartupNotebookPreferences(keyPrefix: "Kiyobumi.lastNotebook")
    private let bookmarkKey: String
    private let pathKey: String
    private let defaults: UserDefaults
    @Published private(set) var bookmark: Data?
    @Published private(set) var displayPath: String
    @Published var reopenLastUsed: Bool {
        didSet { defaults.set(reopenLastUsed, forKey: "Kiyobumi.reopenLastNotebook") }
    }
    var hasStartupNotebook: Bool { bookmark != nil }

    init(defaults: UserDefaults = .standard, keyPrefix: String = "Kiyobumi.startupNotebook") {
        self.defaults = defaults
        bookmarkKey = keyPrefix + ".bookmark"
        pathKey = keyPrefix + ".path"
        bookmark = defaults.data(forKey: keyPrefix + ".bookmark")
        displayPath = defaults.string(forKey: keyPrefix + ".path") ?? ""
        reopenLastUsed = defaults.object(forKey: "Kiyobumi.reopenLastNotebook") as? Bool ?? true
    }
    func choose(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        try Self.validate(url)
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: bookmarkKey)
        defaults.set(url.path, forKey: pathKey)
        bookmark = data; displayPath = url.path
    }
    func clear() {
        defaults.removeObject(forKey: bookmarkKey)
        defaults.removeObject(forKey: pathKey)
        bookmark = nil; displayPath = ""
    }
    func resolve() throws -> StartupNotebookAccess? {
        guard let bookmark = bookmark else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            throw StartupNotebookFailure.unavailableBookmark
        }
        let access = StartupNotebookAccess(url: url, scoped: url.startAccessingSecurityScopedResource())
        do {
            try Self.validate(url)
            if stale { try choose(url) }
            if displayPath != url.path {
                displayPath = url.path; defaults.set(url.path, forKey: pathKey)
            }
            return access
        } catch { access.release(); throw error }
    }
    func rememberIfChanged(_ url: URL) {
        guard !hasStartupNotebook || displayPath != url.path else { return }
        try? choose(url)
    }
    private static func validate(_ url: URL) throws {
        guard url.isFileURL, url.pathExtension.lowercased() == "onbook" else {
            throw StartupNotebookFailure.chooseSavedNotebook
        }
        var directory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &directory) else {
            throw StartupNotebookFailure.missingNotebook
        }
        guard directory.boolValue else { throw StartupNotebookFailure.chooseSavedNotebook }
    }
}

@MainActor
final class StartupNotebookController {
    static let shared = StartupNotebookController()
    private var opening = false
    private var access: [StartupNotebookAccess] = []
    func openDefault(orChoose: Bool = false) {
        guard !opening else { return }
        do {
            let preferences = StartupNotebookPreferences.shared
            // Retain the previous pinned notebook as a first-launch fallback
            // until this version has observed a notebook becoming active.
            let selected = preferences.reopenLastUsed && StartupNotebookPreferences.lastUsed.hasStartupNotebook
                ? StartupNotebookPreferences.lastUsed : preferences
            guard let location = try selected.resolve() else {
                if orChoose {
                    NotebookCollection.shared.showLibrary()
                }
                return
            }
            opening = true
            NSDocumentController.shared.openDocument(withContentsOf: location.url, display: true) { [weak self] _, alreadyOpen, error in
                DispatchQueue.main.async {
                    guard let self = self else { location.release(); return }
                    self.opening = false
                    if let error = error {
                        location.release(); self.present(error, startup: true)
                        if orChoose { NotebookCollection.shared.showLibrary() }
                    }
                    else if alreadyOpen { location.release() }
                    else { self.access.append(location) }
                }
            }
        } catch {
            present(error, startup: true)
            if orChoose { NotebookCollection.shared.showLibrary() }
        }
    }
    func openExplicit(_ urls: [URL]) {
        for url in urls {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { [weak self] _, _, error in
                if let error = error { DispatchQueue.main.async { self?.present(error, startup: false) } }
            }
        }
    }
    private func present(_ error: Error, startup: Bool) {
        let alert = NSAlert()
        alert.messageText = startup ? "Could not open the startup notebook" : "Could not open notebook"
        let recovery = startup ? "\n\nUse Kiyobumi > Settings to change or clear the startup notebook." : ""
        alert.informativeText = String(error.localizedDescription.prefix(800)) + recovery
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    func releaseAccess() { access.forEach { $0.release() }; access.removeAll() }
}

@MainActor
final class KiyobumiAppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowObserver: NSObjectProtocol?
    private var explicitOpen = false
    private var bypassStartup = false
    func applicationWillFinishLaunching(_ notification: Notification) {
        bypassStartup = NSEvent.modifierFlags.contains(.option)
        mainWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor in
                guard window.isMainWindow, let document = NSDocumentController.shared.documents.first(where: {
                    $0.windowControllers.contains { $0.window === window }
                }), let url = document.fileURL, url.pathExtension.lowercased() == "onbook" else { return }
                StartupNotebookPreferences.lastUsed.rememberIfChanged(url)
            }
        }
    }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearancePreferences.shared.apply()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.explicitOpen else { return }
            if self.bypassStartup {
                if NSDocumentController.shared.documents.isEmpty { NotebookCollection.shared.showLibrary() }
            } else { StartupNotebookController.shared.openDefault(orChoose: true) }
        }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        explicitOpen = true
        StartupNotebookController.shared.openExplicit(urls)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { StartupNotebookController.shared.openDefault(orChoose: true); return false }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let mainWindowObserver { NotificationCenter.default.removeObserver(mainWindowObserver) }
        StartupNotebookController.shared.releaseAccess(); NotebookCollection.shared.releaseAccess()
    }
}
