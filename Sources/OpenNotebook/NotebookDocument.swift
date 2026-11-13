import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let openNotebook = UTType(exportedAs: "org.opennotebook.notebook", conformingTo: .package)
}

struct NotebookManifest: Codable, Equatable {
    var format = "org.opennotebook.notebook"
    var schemaVersion = 3
    var id: UUID
    var name: String
    var sections: [Section]
}

enum NotebookFailure: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

struct NotebookDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.openNotebook] }
    static var writableContentTypes: [UTType] { [.openNotebook] }
    var notebook: Notebook
    // Preserve attachments and ancillary files even before their editors exist.
    var media: [String: StoredFile] = [:]
    var ancillary: [String: StoredFile] = [:]

    init() {
        var page = Page(title: "Welcome")
        page.elements = [PageElement(
            frame: Frame(x: 48, y: 40, width: 560, height: 180),
            content: .text(markdown: "Welcome to Kiyobumi\n\nChoose Text and click to write. Click text to edit; drag its border to move it.\nUse Pen or Highlighter to draw, Select to move text, and Eraser to remove strokes.\nEdit the page title above. New notebooks save in your chosen notebook folder and autosave as you work."))]
        notebook = Notebook(name: "My Notebook",
                            sections: [Section(name: "Getting Started", pageIDs: [page.id])],
                            pages: [page.id: page])
    }
    init(notebook: Notebook) { self.notebook = notebook }

    init(configuration: ReadConfiguration) throws {
        self = try Self.read(configuration.file)
    }

    static func read(_ root: FileWrapper) throws -> NotebookDocument {
        guard root.isDirectory, let files = root.fileWrappers,
              let manifestData = files["manifest.json"]?.regularFileContents,
              let pagesDir = files["pages"], pagesDir.isDirectory,
              let pageFiles = pagesDir.fileWrappers else {
            throw NotebookFailure.invalid("This notebook needs manifest.json and a pages folder.")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        try Self.checkJSONKeys(manifestData, kind: "manifest")
        let manifest = try decoder.decode(NotebookManifest.self, from: manifestData)
        guard manifest.format == "org.opennotebook.notebook", (1...6).contains(manifest.schemaVersion) else {
            throw NotebookFailure.invalid("This notebook format or version is not supported. No changes were made.")
        }
        var pages: [UUID: Page] = [:]
        for (name, wrapper) in pageFiles where name != ".DS_Store" {
            guard name.hasSuffix(".json"), let data = wrapper.regularFileContents else {
                throw NotebookFailure.invalid("Unexpected item in pages: \(name).")
            }
            try Self.checkJSONKeys(data, kind: "page")
            let page = try decoder.decode(Page.self, from: data)
            guard name == page.id.uuidString.lowercased() + ".json", pages[page.id] == nil else {
                throw NotebookFailure.invalid("Page ID and filename disagree: \(name).")
            }
            pages[page.id] = page
        }
        var result = NotebookDocument(notebook: Notebook(id: manifest.id, name: manifest.name,
                                                         sections: manifest.sections, pages: pages))
        if let media = files["media"] {
            guard media.isDirectory else { throw NotebookFailure.invalid("media must be a folder.") }
            result.media = try (media.fileWrappers ?? [:]).mapValues { try StoredFile(snapshot: $0) }
        }
        result.ancillary = try files.filter { !["manifest.json", "pages", "media", ".DS_Store"].contains($0.key) }.mapValues { try StoredFile(snapshot: $0) }
        try result.validate()
        return result
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try package()
    }

    func package() throws -> FileWrapper {
        try validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var manifest = NotebookManifest(id: notebook.id, name: notebook.name, sections: notebook.sections)
        if notebook.pages.values.contains(where: { page in page.elements.contains { element in
            if element.minimumHeight != nil || element.tableColumnWidths != nil { return true }
            if case .richText(let value) = element.content {
                return value.defaultFormat.highlightHex != nil || value.runs.contains { $0.format.highlightHex != nil }
            }
            return false
        } }) { manifest.schemaVersion = 4 }
        if notebook.pages.values.contains(where: { $0.elements.contains { $0.flowBlocks != nil } }) {
            manifest.schemaVersion = 5
        }
        if notebook.pages.values.contains(where: { page in
            page.paperDesign != nil || page.elements.flatMap { [$0] + ($0.flowBlocks ?? []) }.contains { $0.tableCellColors != nil }
        }) { manifest.schemaVersion = 6 }
        var files = ancillary.mapValues { $0.wrapper() }
        files["manifest.json"] = FileWrapper(regularFileWithContents: try encoder.encode(manifest))
        var pageFiles: [String: FileWrapper] = [:]
        for page in notebook.pages.values {
            pageFiles[page.id.uuidString.lowercased() + ".json"] = FileWrapper(regularFileWithContents: try encoder.encode(page))
        }
        files["pages"] = FileWrapper(directoryWithFileWrappers: pageFiles)
        files["media"] = FileWrapper(directoryWithFileWrappers: media.mapValues { $0.wrapper() })
        return FileWrapper(directoryWithFileWrappers: files)
    }

    private static func validColor(_ color: String) -> Bool {
        color.count == 7 && color.hasPrefix("#") && color.dropFirst().allSatisfy { $0.isASCII && $0.isHexDigit }
    }

    // Unknown fields are rejected until the codec gains extension dictionaries.
    // This prevents editable saves from silently dropping same-version additions.
    private static func checkJSONKeys(_ data: Data, kind: String) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        try checkObject(object, kind: kind)
    }
    private static func checkObject(_ value: Any, kind: String, flowDepth: Int = 0) throws {
        let allowed: [String: Set<String>] = [
            "manifest": ["format", "schemaVersion", "id", "name", "sections"],
            "section": ["id", "name", "colorHex", "pageIDs"],
            "page": ["id", "title", "createdAt", "modifiedAt", "elements", "level", "background", "paperDesign"],
            "element": ["id", "frame", "content", "minimumHeight", "tableColumnWidths", "flowBlocks", "tableCellColors"],
            "paperDesign": ["paperColor", "ruleColor", "spacing", "marginEnabled", "marginPosition", "marginColor"],
            "frame": ["x", "y", "width", "height"],
            "text": ["type", "markdown"], "image": ["type", "mediaName"],
            "richText": ["type", "value"],
            "richValue": ["text", "runs", "defaultFormat"],
            "textSpan": ["location", "length", "format"],
            "textFormat": ["fontName", "fontSize", "bold", "italic", "underline", "colorHex", "link", "highlightHex"],
            "ink": ["type", "strokes"],
            "attachment": ["type", "mediaName", "fileName"], "table": ["type", "rows"],
            "stroke": ["id", "kind", "colorHex", "width", "points", "opacity"],
            "point": ["x", "y", "pressure"]
        ]
        guard let fields = value as? [String: Any], let keys = allowed[kind],
              Set(fields.keys).isSubset(of: keys) else {
            throw NotebookFailure.invalid("Unexpected fields or object type in \(kind). This file was not changed.")
        }
        if kind == "page", let design = fields["paperDesign"] { try checkObject(design, kind: "paperDesign") }
        let children: [String: [(String, String)]] = [
            "manifest": [("sections", "section")], "page": [("elements", "element")],
            "ink": [("strokes", "stroke")], "stroke": [("points", "point")]
        ]
        for (key, childKind) in children[kind] ?? [] {
            guard let items = fields[key] as? [Any] else { continue }
            for item in items { try checkObject(item, kind: childKind) }
        }
        if kind == "element" {
            if let raw = fields["flowBlocks"], !(raw is NSNull) {
                guard flowDepth == 0, let blocks = raw as? [Any], !blocks.isEmpty, blocks.count <= 10_000 else {
                    throw NotebookFailure.invalid("A mixed box must contain 1–10,000 non-nested blocks.")
                }
                for block in blocks { try checkObject(block, kind: "element", flowDepth: 1) }
            }
            if let frame = fields["frame"] { try checkObject(frame, kind: "frame") }
            if let content = fields["content"] as? [String: Any], let type = content["type"] as? String {
                try checkObject(content, kind: type)
            }
        }
        if kind == "richText", let child = fields["value"] { try checkObject(child, kind: "richValue") }
        if kind == "richValue" {
            if let base = fields["defaultFormat"] { try checkObject(base, kind: "textFormat") }
            for run in fields["runs"] as? [Any] ?? [] { try checkObject(run, kind: "textSpan") }
        }
        if kind == "textSpan", let format = fields["format"] { try checkObject(format, kind: "textFormat") }
    }

    func validate() throws {
        let sectionIDs = notebook.sections.map(\.id)
        let pageIDs = notebook.sections.flatMap(\.pageIDs)
        guard Set(sectionIDs).count == sectionIDs.count,
              Set(pageIDs).count == pageIDs.count,
              Set(pageIDs) == Set(notebook.pages.keys) else {
            throw NotebookFailure.invalid("Duplicate IDs, missing pages, or unreferenced pages were found.")
        }
        guard notebook.sections.allSatisfy({ Self.validColor($0.colorHex) }) else {
            throw NotebookFailure.invalid("Invalid section color.")
        }
        for (id, page) in notebook.pages {
            guard id == page.id, (0...2).contains(page.level), Set(page.elements.map(\.id)).count == page.elements.count else {
                throw NotebookFailure.invalid("A page or element ID is inconsistent.")
            }
            if let design = page.paperDesign {
                guard [design.paperColor, design.ruleColor, design.marginColor].allSatisfy(Self.validColor),
                      design.spacing.isFinite, (8...96).contains(design.spacing),
                      design.marginPosition.isFinite, (0...400).contains(design.marginPosition) else {
                    throw NotebookFailure.invalid("Invalid paper design.")
                }
            }
            for container in page.elements where container.flowBlocks != nil {
                let blocks = container.flowBlocks ?? []
                guard !blocks.isEmpty, blocks.count <= 10_000,
                      blocks.allSatisfy({ $0.flowBlocks == nil }),
                      blocks.allSatisfy({ if case .ink = $0.content { return false }; return true }),
                      case .richText(let placeholder) = container.content, placeholder == RichTextContent() else {
                    throw NotebookFailure.invalid("Invalid mixed-content box.")
                }
            }
            let allElements = page.elements.flatMap { [$0] + ($0.flowBlocks ?? []) }
            guard Set(allElements.map(\.id)).count == allElements.count else {
                throw NotebookFailure.invalid("Duplicate mixed-content block IDs.")
            }
            for element in allElements {
                if let colors = element.tableCellColors {
                    guard case .table(let rows) = element.content,
                          colors.allSatisfy({ key, color in
                              let indices = key.split(separator: ":").compactMap { Int($0) }
                              return indices.count == 2 && key == "\(indices[0]):\(indices[1])" && rows.indices.contains(indices[0]) && rows[indices[0]].indices.contains(indices[1]) && Self.validColor(color)
                          }) else { throw NotebookFailure.invalid("Invalid table cell shading.") }
                }
                let f = element.frame
                if let height = element.minimumHeight, !height.isFinite || height < 0 || height > 1_000_000 {
                    throw NotebookFailure.invalid("Invalid minimum box height.")
                }
                if let widths = element.tableColumnWidths {
                    guard case .table(let rows) = element.content, widths.count == rows.first?.count,
                          widths.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 1_000_000 }) else {
                        throw NotebookFailure.invalid("Invalid table column widths.")
                    }
                }
                guard [f.x, f.y, f.width, f.height].allSatisfy({ $0.isFinite }), f.width >= 0, f.height >= 0 else {
                    throw NotebookFailure.invalid("Invalid element geometry.")
                }
                switch element.content {
                case .text: break
                case .richText(let value):
                    let length = value.text.utf16.count
                    let formats = [value.defaultFormat] + value.runs.map(\.format)
                    guard formats.allSatisfy({ $0.highlightHex.map(Self.validColor) ?? true }) else {
                        throw NotebookFailure.invalid("Invalid text highlight color.")
                    }
                    guard value.runs.count <= 100_000,
                          value.runs.allSatisfy({ $0.location >= 0 && $0.length > 0 && $0.location <= length && $0.length <= length - $0.location }),
                          formats.allSatisfy({ !$0.fontName.isEmpty && $0.fontSize.isFinite && (6...288).contains($0.fontSize) && Self.validColor($0.colorHex) && ($0.link == nil || ["http", "https", "mailto"].contains(URL(string: $0.link ?? "")?.scheme?.lowercased() ?? "")) }) else {
                        throw NotebookFailure.invalid("Invalid rich-text range, font or link.")
                    }
                case .image(let name), .attachment(let name, _):
                    guard !name.isEmpty, !name.contains("/"), !name.contains("\\"), name != ".", name != "..", media[name]?.isRegularFile == true else {
                        throw NotebookFailure.invalid("An attachment is missing or has an invalid name.")
                    }
                case .table(let rows):
                    guard let first = rows.first, !first.isEmpty, rows.count <= 1000, first.count <= 100,
                          rows.count * first.count <= 20_000, rows.allSatisfy({ $0.count == first.count }) else {
                        throw NotebookFailure.invalid("A table must have a rectangular grid of up to 20,000 cells.")
                    }
                case .ink(let strokes):
                    for stroke in strokes {
                        guard Self.validColor(stroke.colorHex), stroke.width.isFinite, stroke.width > 0,
                              stroke.opacity.map({ $0.isFinite && (0...1).contains($0) }) ?? true,
                              stroke.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.pressure.isFinite && (0...1).contains($0.pressure) }) else {
                            throw NotebookFailure.invalid("Invalid ink geometry or pressure.")
                        }
                    }
                }
            }
        }
    }
}
