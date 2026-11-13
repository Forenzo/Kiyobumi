import AppKit
import PDFKit
import UniformTypeIdentifiers

struct PrintoutSheet {
    let data: Data
    let size: CGSize
}

@MainActor
enum PrintoutImporter {
    static let contentTypes: [UTType] = ["pdf", "doc", "docx", "odt", "rtf", "txt", "md"].compactMap {
        UTType(filenameExtension: $0)
    }
    static func load(_ url: URL, progress: (String) -> Void) async throws -> [PrintoutSheet] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= 50 * 1024 * 1024 else {
            throw NotebookFailure.invalid("Choose a document no larger than 50 MB.")
        }
        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            guard let document = PDFDocument(data: data), !document.isLocked else {
                throw NotebookFailure.invalid("This PDF is unreadable or password protected. Save an unlocked copy first.")
            }
            guard document.pageCount > 0, document.pageCount <= 200 else {
                throw NotebookFailure.invalid("Import up to 200 PDF pages at a time.")
            }
            var result: [PrintoutSheet] = []
            var total = 0
            for index in 0..<document.pageCount {
                try Task.checkCancellation()
                guard let page = document.page(at: index), let bytes = page.dataRepresentation else {
                    throw NotebookFailure.invalid("PDF page \(index + 1) could not be read. Nothing was inserted.")
                }
                var size = page.bounds(for: .cropBox).size
                if abs(page.rotation) % 180 == 90 { size = CGSize(width: size.height, height: size.width) }
                guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
                    throw NotebookFailure.invalid("The PDF has an invalid page size.")
                }
                total += bytes.count
                guard total <= 200 * 1024 * 1024 else { throw NotebookFailure.invalid("This printout exceeds 200 MB. Import a smaller page range.") }
                result.append(PrintoutSheet(data: bytes, size: size))
                progress("Preparing PDF page \(index + 1) of \(document.pageCount)…")
                await Task.yield()
            }
            return result
        }
        let attributed: NSAttributedString
        switch ext {
        case "txt", "md":
            let text = try String(contentsOf: url)
            if ext == "md" { attributed = RichTextCodec.attributed(RichTextCodec.fromMarkdown(text)) }
            else { attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.black]) }
        case "rtf", "doc", "docx", "odt":
            let type: NSAttributedString.DocumentType
            switch ext {
            case "rtf": type = .rtf
            case "doc": type = .docFormat
            case "docx": type = .officeOpenXML
            default: type = .openDocument
            }
            attributed = try NSAttributedString(data: data, options: [.documentType: type], documentAttributes: nil)
        default: throw NotebookFailure.invalid("Use PDF, Word (.doc/.docx), ODT, RTF, TXT or Markdown. Export other document types to PDF first.")
        }
        guard attributed.length <= 2_000_000 else { throw NotebookFailure.invalid("This document is too long. Import a smaller part.") }
        let storage = NSTextStorage(attributedString: attributed)
        let manager = NSLayoutManager(); storage.addLayoutManager(manager)
        var sheets: [PrintoutSheet] = []
        var consumed = 0
        var total = 0
        repeat {
            try Task.checkCancellation()
            guard sheets.count < 200 else { throw NotebookFailure.invalid("This document exceeds 200 printout pages.") }
            let container = NSTextContainer(containerSize: NSSize(width: 523.28, height: 769.89))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container); manager.ensureLayout(for: container)
            let range = manager.glyphRange(for: container)
            if attributed.length > 0 && range.length == 0 {
                throw NotebookFailure.invalid("Part of this document cannot fit on a page. Export it to PDF in its original app.")
            }
            let view = TextPrintSheet(storage: storage, manager: manager, range: range)
            let bytes = view.dataWithPDF(inside: view.bounds)
            total += bytes.count
            guard total <= 200 * 1024 * 1024 else { throw NotebookFailure.invalid("This printout exceeds 200 MB.") }
            sheets.append(PrintoutSheet(data: bytes, size: view.bounds.size))
            consumed = NSMaxRange(range)
            progress("Preparing document page \(sheets.count)…")
            await Task.yield()
        } while consumed < manager.numberOfGlyphs
        return sheets
    }
}

@MainActor
private final class TextPrintSheet: NSView {
    let storage: NSTextStorage
    let manager: NSLayoutManager
    let range: NSRange
    init(storage: NSTextStorage, manager: NSLayoutManager, range: NSRange) {
        self.storage = storage; self.manager = manager; self.range = range
        super.init(frame: NSRect(x: 0, y: 0, width: 595.28, height: 841.89))
    }
    required init?(coder: NSCoder) { fatalError("Not used") }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill()
        manager.drawBackground(forGlyphRange: range, at: NSPoint(x: 36, y: 36))
        manager.drawGlyphs(forGlyphRange: range, at: NSPoint(x: 36, y: 36))
    }
}
