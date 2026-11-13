import SwiftUI
import AppKit

struct PageTemplate: Identifiable {
    var id: String
    var name: String
    var page: Page
    var media: [String: StoredFile] = [:]
    var subtitle = ""
    var url: URL?

    func freshPage() -> (Page, [String: StoredFile]) {
        var result = page
        result.id = UUID(); result.level = 0; result.createdAt = Date(); result.modifiedAt = Date()
        var copiedMedia: [String: StoredFile] = [:]
        var names: [String: String] = [:]
        func clone(_ original: PageElement) -> PageElement {
            var element = original; element.id = UUID()
            func mediaName(_ name: String) -> String {
                if let mapped = names[name] { return mapped }
                let suffix = String((name as NSString).pathExtension.prefix(20))
                let mapped = UUID().uuidString.lowercased() + (suffix.isEmpty ? "" : "." + suffix)
                names[name] = mapped; copiedMedia[mapped] = media[name]; return mapped
            }
            switch element.content {
            case .image(let name): element.content = .image(mediaName: mediaName(name))
            case .attachment(let name, let file): element.content = .attachment(mediaName: mediaName(name), fileName: file)
            case .ink(let strokes): element.content = .ink(strokes: strokes.map { stroke in var copy = stroke; copy.id = UUID(); return copy })
            default: break
            }
            element.flowBlocks = original.flowBlocks?.map(clone)
            return element
        }
        result.elements = page.elements.map(clone)
        return (result, copiedMedia)
    }
}

enum PageTemplates {
    static func folder() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let url = root.appendingPathComponent("Kiyobumi/Templates", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static var builtins: [PageTemplate] {
        [PageBackground.plain, .ruled, .grid].map { (background: PageBackground) in
            var page = Page(title: "Untitled page"); page.background = background
            var design = PaperDesign()
            if background == .ruled { design.marginEnabled = true; design.paperColor = "#FFFEF5" }
            page.paperDesign = design
            return PageTemplate(id: "builtin-" + background.rawValue, name: background.rawValue.capitalized, page: page)
        }
    }
    static func load() throws -> [PageTemplate] {
        var result = builtins
        for url in try FileManager.default.contentsOfDirectory(at: folder(), includingPropertiesForKeys: nil).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension == "onbook" {
            let document = try NotebookDocument.read(FileWrapper(url: url, options: .immediate))
            guard let id = document.notebook.sections.first?.pageIDs.first, let page = document.notebook.pages[id] else { continue }
            let headers = try PageHeaderMetadata.read(document.ancillary[PageHeaderMetadata.fileName])
            result.append(PageTemplate(id: url.lastPathComponent, name: document.notebook.name, page: page, media: document.media, subtitle: headers.text(for: id), url: url))
        }
        return result
    }
    static func save(name: String, page: Page, media: [String: StoredFile], subtitle: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw NotebookFailure.invalid("Give the template a name.") }
        let source = PageTemplate(id: "", name: name, page: page, media: media, subtitle: subtitle)
        let (copy, copiedMedia) = source.freshPage()
        var document = NotebookDocument(notebook: Notebook(name: name, sections: [Section(name: "Template", pageIDs: [copy.id])], pages: [copy.id: copy]))
        document.media = copiedMedia
        var headers = PageHeaderMetadata(); headers.set(subtitle, for: copy.id)
        document.ancillary[PageHeaderMetadata.fileName] = try headers.storedFile()
        let url = try folder().appendingPathComponent(UUID().uuidString.lowercased() + ".onbook")
        try document.package().write(to: url, options: .atomic, originalContentsURL: nil)
    }
}

@MainActor
struct PageTemplateSheet: View {
    let page: Page
    let media: [String: StoredFile]
    let subtitle: String
    let create: (Page, [String: StoredFile], String) -> Void
    @Environment(\.dismiss) private var dismiss
    @KiyobumiState private var templates = PageTemplates.builtins
    @KiyobumiState private var selected: String?
    @KiyobumiState private var name = ""
    @KiyobumiState private var error: String?
    @KiyobumiState private var pendingDelete: PageTemplate?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Page templates").font(.title2)
            Text("Create a new page with saved content, tables, attachments and paper design.").foregroundStyle(.secondary)
            List(selection: $selected) {
                ForEach(templates) { item in
                    HStack { Image(systemName: "doc.richtext"); Text(item.name); Spacer(); if item.url == nil { Text("Built-in").foregroundStyle(.secondary) } }.tag(item.id)
                }
            }.frame(height: 220)
            HStack {
                TextField("Template name", text: $name)
                Button("Save current page") {
                    do { try PageTemplates.save(name: name, page: page, media: media, subtitle: subtitle); reload(); name = "" }
                    catch { self.error = error.localizedDescription }
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error { Text(error).foregroundStyle(.red).lineLimit(4).textSelection(.enabled) }
            HStack {
                Button("Delete template…") { pendingDelete = templates.first { $0.id == selected } }
                    .disabled(templates.first { $0.id == selected }?.url == nil)
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create page") {
                    guard let template = templates.first(where: { $0.id == selected }) else { return }
                    let (copy, files) = template.freshPage()
                    dismiss()
                    DispatchQueue.main.async { create(copy, files, template.subtitle) }
                }.disabled(selected == nil).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 560).onAppear { reload() }
        .alert("Delete this template?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                do { if let url = pendingDelete?.url { try FileManager.default.removeItem(at: url) }; pendingDelete = nil; selected = nil; reload() }
                catch { self.error = error.localizedDescription; pendingDelete = nil }
            }
        } message: { Text("Pages already created from this template will be kept.") }
    }
    private func reload() {
        do { templates = try PageTemplates.load(); error = nil }
        catch { self.error = error.localizedDescription }
    }
}
