import SwiftUI
import AppKit

struct NotebookCollectionEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var path: String
    var name: String
    var color: String
    var bookmark: Data?
}

@MainActor
final class NotebookCollection: NSObject, ObservableObject {
    static let shared = NotebookCollection()
    @Published private(set) var entries: [NotebookCollectionEntry] = []
    @Published private(set) var folderPath: String
    @Published private(set) var opening = false
    private var homeWindow: NSWindow?
    private var newWindow: NSWindow?
    private var access: [URL] = []
    private var pendingClose: [ObjectIdentifier: UUID] = [:]
    private let entriesKey = "Kiyobumi.notebookCollection"

    override init() {
        folderPath = UserDefaults.standard.string(forKey: "Kiyobumi.notebookFolder")
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Kiyobumi Notebooks").path
        super.init()
        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let saved = try? JSONDecoder().decode([NotebookCollectionEntry].self, from: data) { entries = saved }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: entriesKey) }
    }
    func remember(_ url: URL, name: String, color: String? = nil) {
        let path = url.standardizedFileURL.path
        if let index = entries.firstIndex(where: { $0.path == path }) {
            guard entries[index].name != name || (color != nil && entries[index].color != color) else { return }
            entries[index].name = name
            if let color { entries[index].color = color }
        } else {
            let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            entries.append(NotebookCollectionEntry(path: path, name: name, color: color ?? "#607D8B", bookmark: bookmark))
        }
        persist()
    }
    func relocated(from oldURL: URL, to newURL: URL, name: String) {
        let oldPath = oldURL.standardizedFileURL.path
        let newPath = newURL.standardizedFileURL.path
        let prior = entries.first { $0.path == oldPath }
        entries.removeAll { $0.path == oldPath || $0.path == newPath }
        let bookmark = try? newURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        entries.append(NotebookCollectionEntry(id: prior?.id ?? UUID(), path: newPath,
                                               name: name, color: prior?.color ?? "#3B82F6", bookmark: bookmark))
        persist()
    }
    func setColor(_ color: String, entry: NotebookCollectionEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].color = color; persist()
    }
    private func resolve(_ entry: NotebookCollectionEntry) -> URL {
        if let data = entry.bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                                  relativeTo: nil, bookmarkDataIsStale: &stale) {
                if let index = entries.firstIndex(where: { $0.id == entry.id }), stale || entries[index].path != url.path {
                    entries[index].path = url.path
                    entries[index].bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    persist()
                }
                return url
            }
        }
        return URL(fileURLWithPath: entry.path)
    }
    func open(_ entry: NotebookCollectionEntry) { openURL(resolve(entry)) }
    func openURL(_ url: URL) {
        guard !opening else { return }
        let source = NSApp.keyWindow
        source?.makeFirstResponder(nil)
        let sourceIsNotebook = source.map { window in
            NSDocumentController.shared.documents.contains { $0.windowControllers.contains { $0.window === window } }
        } ?? false
        opening = true
        let scoped = url.startAccessingSecurityScopedResource()
        NSDocumentController.shared.openDocument(withContentsOf: url, display: false) { [weak self] document, alreadyOpen, error in
            DispatchQueue.main.async {
                guard let self else { if scoped { url.stopAccessingSecurityScopedResource() }; return }
                self.opening = false
                if let error {
                    if scoped { url.stopAccessingSecurityScopedResource() }
                    self.present(error); return
                }
                if scoped {
                    if alreadyOpen { url.stopAccessingSecurityScopedResource() } else { self.access.append(url) }
                }
                guard let document else { return }
                // Prepare the destination while hidden: showing before sizing causes
                // a visible pop at its old/default frame on every notebook switch.
                if document.windowControllers.isEmpty { document.makeWindowControllers() }
                if let target = document.windowControllers.first?.window {
                    let targetAnimation = target.animationBehavior
                    target.animationBehavior = .none
                    let replacesSource = source.map {
                        $0 !== target && sourceIsNotebook &&
                        !$0.styleMask.contains(.fullScreen) && !target.styleMask.contains(.fullScreen)
                    } ?? false
                    if replacesSource, let source {
                        target.setFrame(source.frame, display: false, animate: false)
                    }
                    target.makeKeyAndOrderFront(nil)
                    // Keep the previous notebook visible until the new one covers it.
                    if replacesSource, let source {
                        let sourceAnimation = source.animationBehavior
                        source.animationBehavior = .none
                        source.orderOut(nil)
                        source.animationBehavior = sourceAnimation
                    }
                    target.animationBehavior = targetAnimation
                } else {
                    document.showWindows()
                }
                self.homeWindow?.orderOut(nil)
            }
        }
    }
    func chooseExisting() {
        let panel = NSOpenPanel()
        panel.title = "Open notebook"; panel.allowedContentTypes = [.openNotebook]
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { openURL(url) }
    }
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Notebook folder"; panel.prompt = "Choose"
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: folderPath)
        if panel.runModal() == .OK, let url = panel.url {
            folderPath = url.path
            UserDefaults.standard.set(folderPath, forKey: "Kiyobumi.notebookFolder")
        }
    }
    static func fileStem(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/\\:").union(.controlCharacters)).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = String(cleaned.prefix(80))
        return stem.isEmpty || stem == "." || stem == ".." ? "Notebook" : stem
    }
    func create(name: String, color: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw NotebookFailure.invalid("Enter a notebook name.") }
        let folder = URL(fileURLWithPath: folderPath, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stem = Self.fileStem(name)
        var destination = folder.appendingPathComponent(stem).appendingPathExtension("onbook")
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = folder.appendingPathComponent("\(stem) \(suffix)").appendingPathExtension("onbook")
            suffix += 1
        }
        var document = NotebookDocument(); document.notebook.name = name
        let temporary = folder.appendingPathComponent(".kiyobumi-create-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try document.package().write(to: temporary, options: .atomic, originalContentsURL: nil)
        // Move fails if another creator won the destination; never overwrite a notebook.
        try FileManager.default.moveItem(at: temporary, to: destination)
        remember(destination, name: name, color: color)
        newWindow?.close(); newWindow = nil
        openURL(destination)
    }
    func closeNotebook(_ entry: NotebookCollectionEntry) {
        let url = resolve(entry)
        guard let document = NSDocumentController.shared.document(for: url) else {
            entries.removeAll { $0.id == entry.id }; persist(); return
        }
        for controller in document.windowControllers { controller.window?.makeFirstResponder(nil) }
        if document.isDocumentEdited { document.showWindows() }
        pendingClose[ObjectIdentifier(document)] = entry.id
        document.canClose(withDelegate: self, shouldClose: #selector(didCheckClose(_:shouldClose:contextInfo:)), contextInfo: nil)
    }
    @objc private func didCheckClose(_ document: NSDocument, shouldClose: Bool, contextInfo: UnsafeMutableRawPointer?) {
        guard let id = pendingClose.removeValue(forKey: ObjectIdentifier(document)), shouldClose else { return }
        let wasVisible = document.windowControllers.contains { $0.window?.isVisible == true }
        document.close()
        entries.removeAll { $0.id == id }; persist()
        if wasVisible { showLibrary() }
    }
    func showLibrary() {
        if homeWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: NotebookLibraryView()))
            window.title = "Kiyobumi Notebooks"; window.setContentSize(NSSize(width: 560, height: 440))
            window.isReleasedWhenClosed = false; window.center(); homeWindow = window
        }
        homeWindow?.makeKeyAndOrderFront(nil)
    }
    func showNew() {
        if newWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: NewNotebookView()))
            window.title = "New Notebook"; window.setContentSize(NSSize(width: 420, height: 230))
            window.isReleasedWhenClosed = false; window.center(); newWindow = window
        }
        newWindow?.makeKeyAndOrderFront(nil)
    }
    func cancelNew() { newWindow?.close(); newWindow = nil }
    func present(_ error: Error) {
        let alert = NSAlert(); alert.messageText = "Could not open notebook"
        alert.informativeText = String(error.localizedDescription.prefix(800)); alert.runModal()
    }
    func releaseAccess() { access.forEach { $0.stopAccessingSecurityScopedResource() }; access.removeAll() }
}

struct NotebookCover: View {
    let color: String
    let active: Bool
    var body: some View {
        Image(systemName: active ? "book.fill" : "book.closed.fill")
            .font(.system(size: 22)).foregroundStyle(Color(hex: color))
            .frame(width: 30, height: 30).accessibilityLabel(active ? "Active notebook" : "Inactive notebook")
    }
}

@MainActor
struct NotebookCollectionList: View {
    @ObservedObject private var collection = NotebookCollection.shared
    var currentURL: URL? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Notebooks").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { collection.showNew() } label: { Image(systemName: "plus") }.help("New notebook")
                Button { collection.chooseExisting() } label: { Image(systemName: "folder") }.help("Open notebook")
            }.buttonStyle(.borderless)
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(collection.entries) { entry in
                        let active = currentURL?.standardizedFileURL.path == entry.path
                        Button { collection.open(entry) } label: {
                            HStack(spacing: 8) {
                                NotebookCover(color: entry.color, active: active)
                                Text(entry.name).lineLimit(2).foregroundStyle(.primary)
                                Spacer(minLength: 0)
                            }.padding(4).background(active ? Color.accentColor.opacity(0.13) : Color.clear)
                                .cornerRadius(5).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(collection.opening)
                        .contextMenu {
                            Menu("Notebook colour") {
                                ForEach(SectionTabColor.palette) { color in
                                    Button(color.name) { collection.setColor(color.hex, entry: entry) }
                                }
                            }
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)]) }
                            Button("Close notebook") { collection.closeNotebook(entry) }
                        }
                    }
                }
            }.frame(maxHeight: 170)
        }.padding(.horizontal, 10)
    }
}

@MainActor
private struct NotebookLibraryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your notebooks").font(.title)
            Text("Choose a notebook, create one, or open an existing .onbook file.").foregroundStyle(.secondary)
            NotebookCollectionList()
            Spacer()
            Text("Closing a notebook removes it from this list. Its saved file stays on disk.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24)
    }
}

@MainActor
private struct NewNotebookView: View {
    @KiyobumiState private var name = ""
    @KiyobumiState private var color = "#3B82F6"
    @KiyobumiState private var errorMessage: String?
    @ObservedObject private var collection = NotebookCollection.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Notebook name", text: $name)
            Picker("Cover colour", selection: $color) {
                ForEach(SectionTabColor.palette) { choice in Text(choice.name).tag(choice.hex) }
            }
            Text("Save in: " + collection.folderPath).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            HStack {
                Button("Cancel") { collection.cancelNew() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    do { try collection.create(name: name, color: color) }
                    catch { errorMessage = error.localizedDescription }
                }.keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || collection.opening)
            }
        }.padding(24)
        .alert("Could not create notebook", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

@MainActor
struct NotebookCollectionCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Notebook…") { NotebookCollection.shared.showNew() }.keyboardShortcut("n", modifiers: .command)
            Button("Open Notebook…") { NotebookCollection.shared.chooseExisting() }.keyboardShortcut("o", modifiers: .command)
            Button("Notebook Collection") { NotebookCollection.shared.showLibrary() }
        }
    }
}
