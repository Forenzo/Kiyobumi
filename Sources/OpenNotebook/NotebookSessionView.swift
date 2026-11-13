import SwiftUI
import AppKit
import UniformTypeIdentifiers

// DocumentGroup remains the single owner of loading, coordinated writes,
// Save/Save As, and the close/quit save guard. This view asks its NSDocument
// to autosave; it never writes a second copy behind the document system.
@MainActor
struct NotebookSessionView: View {
    @Binding var document: NotebookDocument
    let fileURL: URL?
    @StateObject private var autosave = NotebookAutosave()

    var body: some View {
        NotebookRootView(notebook: $document.notebook, media: $document.media,
                         ancillary: $document.ancillary, fileURL: fileURL)
            .background(DocumentWindowReader(autosave: autosave, fileURL: fileURL)
                .frame(width: 0, height: 0))
            .environmentObject(autosave)
            .onAppear { rememberNotebook() }
            .onChange(of: fileURL) { _ in rememberNotebook() }
            .onChange(of: document.notebook.name) { _ in rememberNotebook() }
            .onDisappear { autosave.stop() }
    }
    private func rememberNotebook() {
        if let url = autosave.currentFileURL ?? fileURL { NotebookCollection.shared.remember(url, name: document.notebook.name) }
    }
}

@MainActor
final class NotebookAutosave: ObservableObject {
    static var renamesInProgress: Set<ObjectIdentifier> = []
    var currentFileURL: URL? { nativeDocument?.fileURL }
    @Published private(set) var status = "macOS manages saving"
    @Published private(set) var errorMessage: String?
    @Published private(set) var isAttached = false
    private weak var nativeDocument: NSDocument?
    private var titleObservation: NSKeyValueObservation?
    private weak var observedWindow: NSWindow?
    private var renaming = false
    private var timer: Timer?
    private var saving = false
    private var retryAfter = Date.distantPast

    func attach(window: NSWindow?, fileURL: URL?) {
        if let window, observedWindow !== window {
            observedWindow = window
            titleObservation = window.observe(\.titleVisibility, options: [.new]) { window, _ in
                if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
            }
        }
        window?.titleVisibility = .hidden
        // Resolve this particular notebook, never the application's key window.
        var owner = window?.windowController?.document as? NSDocument
        if owner == nil, let window = window {
            owner = NSDocumentController.shared.documents.first { document in
                document.windowControllers.contains { $0.window === window }
            }
        }
        if owner == nil, let url = fileURL {
            owner = NSDocumentController.shared.document(for: url)
        }
        guard let owner = owner else { return }
        if window?.isMainWindow == true, let url = owner.fileURL {
            StartupNotebookPreferences.lastUsed.rememberIfChanged(url)
        }
        monitor(owner)
    }

    func monitor(_ owner: NSDocument) {
        nativeDocument = owner
        if !isAttached { isAttached = true }
        if timer == nil {
            let newTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.saveIfNeeded() }
            }
            RunLoop.main.add(newTimer, forMode: .common)
            timer = newTimer
        }
        refreshStatus()
    }

    func filenameMatches(_ name: String) -> Bool {
        nativeDocument?.fileURL?.deletingPathExtension().lastPathComponent == name
    }

    func rename(to name: String, completion: @escaping (Error?) -> Void) {
        guard !saving, !renaming else {
            completion(NotebookFailure.invalid("A save is still finishing. Please try the rename again.")); return
        }
        guard let document = nativeDocument, let oldURL = document.fileURL else {
            completion(NotebookFailure.invalid("Save this notebook before renaming it.")); return
        }
        let destination = oldURL.deletingLastPathComponent().appendingPathComponent(name).appendingPathExtension("onbook")
        if destination.standardizedFileURL == oldURL.standardizedFileURL { completion(nil); return }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            completion(NotebookFailure.invalid("A notebook with that filename already exists. Choose another name.")); return
        }
        renaming = true
        Self.renamesInProgress.insert(ObjectIdentifier(document))
        flushEditors()
        document.move(to: destination) { [weak self] error in
            DispatchQueue.main.async {
                self?.renaming = false
                Self.renamesInProgress.remove(ObjectIdentifier(document))
                if error == nil {
                    NotebookCollection.shared.relocated(from: oldURL, to: destination, name: name)
                    let startup = StartupNotebookPreferences.shared
                    if startup.displayPath == oldURL.path { try? startup.choose(destination) }
                    let last = StartupNotebookPreferences.lastUsed
                    if last.displayPath == oldURL.path { try? last.choose(destination) }
                }
                completion(error)
            }
        }
    }

    func chooseSaveLocation() {
        if let document = nativeDocument {
            document.save(nil)
        } else {
            NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
        }
    }

    func saveNow() {
        flushEditors()
        chooseSaveLocation()
    }

    func showInFinder() {
        if let url = nativeDocument?.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    private func flushEditors() {
        func walk(_ view: NSView) {
            if let editor = view as? CanvasTextView, editor.editorMode { editor.flushModel?() }
            for child in view.subviews { walk(child) }
        }
        for controller in nativeDocument?.windowControllers ?? [] {
            if let root = controller.window?.contentView { walk(root) }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refreshStatus() {
        guard !saving, let document = nativeDocument else { return }
        // A later native Command-S can succeed after our request failed.
        if document.fileURL != nil, !document.hasUnautosavedChanges, errorMessage != nil {
            errorMessage = nil
            retryAfter = .distantPast
        }
        guard errorMessage == nil else { return }
        let next = document.fileURL == nil ? "Choose a location once with Save…" :
            (document.hasUnautosavedChanges ? "Changes waiting to save…" : "Saved · Autosave on")
        // Publishing the same value here would trigger another representable
        // update, attachment, and publication indefinitely.
        if status != next { status = next }
    }

    func saveIfNeeded() {
        guard let document = nativeDocument, !saving, !renaming else { return }
        flushEditors()
        refreshStatus()
        // Untitled documents use the native first-save panel and close guard.
        // Never report them as saved or silently assign a hidden file location.
        guard let url = document.fileURL, document.hasUnautosavedChanges,
              Date() >= retryAfter else { return }
        saving = true
        status = "Saving…"
        let completion: (Error?) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.saving = false
                self.errorMessage = error?.localizedDescription
                if let error = error {
                    self.status = "Save failed — " + error.localizedDescription
                    self.retryAfter = Date().addingTimeInterval(10)
                } else {
                    self.retryAfter = .distantPast
                    self.refreshStatus()
                }
            }
        }
        if type(of: document).autosavesInPlace {
            document.autosave(withImplicitCancellability: false, completionHandler: completion)
        } else {
            // Explicit coordinated save for a document host without in-place
            // autosaving; do not mistake an autosaved recovery draft for a save.
            document.save(to: url, ofType: document.fileType ?? UTType.openNotebook.identifier,
                          for: .saveOperation, completionHandler: completion)
        }
    }
}

@MainActor
private struct DocumentWindowReader: NSViewRepresentable {
    let autosave: NotebookAutosave
    let fileURL: URL?

    func makeNSView(context: Context) -> WindowProbe {
        let view = WindowProbe()
        view.onWindow = { window in autosave.attach(window: window, fileURL: fileURL) }
        view.onStop = { autosave.stop() }
        return view
    }

    static func dismantleNSView(_ view: WindowProbe, coordinator: ()) {
        view.onWindow = nil
        view.onStop?()
        view.onStop = nil
    }

    func updateNSView(_ view: WindowProbe, context: Context) {
        view.onWindow = { window in autosave.attach(window: window, fileURL: fileURL) }
        // Defer state publication until SwiftUI finishes this update pass.
        DispatchQueue.main.async { view.onWindow?(view.window) }
    }

    final class WindowProbe: NSView {
        var onWindow: ((NSWindow?) -> Void)?
        var onStop: (() -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onWindow?(self.window)
            }
        }
    }
}
