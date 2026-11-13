import Foundation

// MARK: - Document model (deliberately platform-neutral: JSON, hex colors, UTF-8)
//
// One notebook on disk = one folder package:
//   manifest.json        notebook + sections + page ordering
//   pages/<uuid>.json    page contents (elements)
//   media/<name>         images & attachments

struct Notebook: Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var sections: [Section] = []
    var pages: [UUID: Page] = [:]
}

struct Section: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var colorHex: String = "#3B82F6"
    var pageIDs: [UUID] = []
}

struct Page: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String = "Untitled page"
    var createdAt = Date()
    var modifiedAt = Date()
    var elements: [PageElement] = []
    var level: Int = 0
    var background: PageBackground = .plain
    var paperDesign: PaperDesign? = nil

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled page" : title
    }

    var searchableText: String {
        ([title] + elements.flatMap { $0.flowBlocks ?? [$0] }.map { element in
            switch element.content {
            case .text(let md): return md
            case .richText(let value): return value.text
            case .table(let rows): return rows.flatMap { $0 }.joined(separator: " ")
            case .attachment(_, let name): return name
            default: return ""
            }
        }).joined(separator: "\n")
    }
}

enum PageBackground: String, Codable, CaseIterable, Sendable { case plain, ruled, grid }

extension Page {
    private enum CodingKeys: String, CodingKey { case id, title, createdAt, modifiedAt, elements, level, background, paperDesign }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        modifiedAt = try c.decode(Date.self, forKey: .modifiedAt)
        elements = try c.decode([PageElement].self, forKey: .elements)
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? 0
        background = try c.decodeIfPresent(PageBackground.self, forKey: .background) ?? .plain
        paperDesign = try c.decodeIfPresent(PaperDesign.self, forKey: .paperDesign)
    }
}

struct PageElement: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var frame: Frame                 // position on the page, in logical canvas units (1/96 inch)
    var content: ElementContent
    var minimumHeight: Double? = nil
    var tableColumnWidths: [Double]? = nil
    var tableCellColors: [String: String]? = nil
    // Schema 5: an ordered, non-nested sequence within a single movable box.
    // The container content is empty rich text; blocks carry the actual content.
    var flowBlocks: [PageElement]? = nil

    var isText: Bool {
        switch content { case .text, .richText, .table: return true; default: return false }
    }
}

struct Frame: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let zero = Frame(x: 0, y: 0, width: 0, height: 0)
}

enum ElementContent: Codable, Equatable, Sendable {
    case text(markdown: String)
    case richText(RichTextContent)
    case ink(strokes: [Stroke])
    case image(mediaName: String)
    case attachment(mediaName: String, fileName: String)
    case table(rows: [[String]])
}

// Portable rich text. Ranges use UTF-16 code units, matching Cocoa and OneNote.
// No opaque RTF blob or platform font object is required to read a notebook.
struct TextFormat: Codable, Equatable, Sendable {
    var fontName = "Helvetica"
    var fontSize: Double = 14
    var bold = false
    var italic = false
    var underline = false
    var colorHex = "#111111"
    var link: String?
    var highlightHex: String? = nil
}

struct TextSpan: Codable, Equatable, Sendable {
    var location: Int
    var length: Int
    var format: TextFormat
}

struct RichTextContent: Codable, Equatable, Sendable {
    var text = ""
    var runs: [TextSpan] = []
    var defaultFormat = TextFormat()
}

// MARK: - Ink

enum Tool: String, Codable, CaseIterable {
    case select, text, pen, highlighter, eraser
}

enum StrokeKind: String, Codable, Sendable {
    case pen, highlighter
}

struct Stroke: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var kind: StrokeKind = .pen
    var colorHex: String = "#111111"
    var width: Double = 2.5
    var points: [StrokePoint] = []   // coordinates relative to the element's frame
    var opacity: Double? = nil       // v3 imported ink; nil keeps the native pen/highlighter default
}

struct StrokePoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var pressure: Double = 1.0       // unused on trackpad; hook Force Touch later
}
// Explicit JSON discriminators, independent of Swift's synthesized enum layout.
extension ElementContent {
    private enum Keys: String, CodingKey { case type, markdown, value, strokes, mediaName, fileName, rows }
    private enum Kind: String, Codable { case text, richText, ink, image, attachment, table }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .text: self = .text(markdown: try c.decode(String.self, forKey: .markdown))
        case .richText: self = .richText(try c.decode(RichTextContent.self, forKey: .value))
        case .ink: self = .ink(strokes: try c.decode([Stroke].self, forKey: .strokes))
        case .image: self = .image(mediaName: try c.decode(String.self, forKey: .mediaName))
        case .attachment: self = .attachment(mediaName: try c.decode(String.self, forKey: .mediaName), fileName: try c.decode(String.self, forKey: .fileName))
        case .table: self = .table(rows: try c.decode([[String]].self, forKey: .rows))
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .text(let text):
            try c.encode(Kind.text, forKey: .type)
            try c.encode(text, forKey: .markdown)
        case .richText(let value):
            try c.encode(Kind.richText, forKey: .type)
            try c.encode(value, forKey: .value)
        case .ink(let strokes):
            try c.encode(Kind.ink, forKey: .type)
            try c.encode(strokes, forKey: .strokes)
        case .image(let name):
            try c.encode(Kind.image, forKey: .type)
            try c.encode(name, forKey: .mediaName)
        case .attachment(let name, let fileName):
            try c.encode(Kind.attachment, forKey: .type)
            try c.encode(name, forKey: .mediaName)
            try c.encode(fileName, forKey: .fileName)
        case .table(let rows):
            try c.encode(Kind.table, forKey: .type)
            try c.encode(rows, forKey: .rows)
        }
    }
}
