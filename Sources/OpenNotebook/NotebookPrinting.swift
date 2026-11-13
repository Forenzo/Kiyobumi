import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

enum PrintPaper: String, CaseIterable {
    case a4, letter
    var size: CGSize { self == .a4 ? CGSize(width: 595.28, height: 841.89) : CGSize(width: 612, height: 792) }
}
struct PrintPageSnapshot {
    var page: Page
    var subheader: String
}

@MainActor
enum NotebookPrinting {
    static func output(_ pdf: PDFDocument, pages: [PrintPageSnapshot], paper: PrintPaper, printing: Bool) throws {
        guard !pages.isEmpty else { throw NotebookFailure.invalid("There are no pages in this section.") }
        if printing {
            let info = NSPrintInfo.shared.copy() as! NSPrintInfo
            info.paperSize = paper.size
            guard let operation = pdf.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: true) else {
                throw NotebookFailure.invalid("The system could not prepare this print job.")
            }
            operation.showsPrintPanel = true; operation.showsProgressPanel = true
            operation.run()
        } else {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = (pages.count == 1 ? pages[0].page.displayTitle : "Kiyobumi section")
                .replacingOccurrences(of: "/", with: "-") + ".pdf"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard let bytes = pdf.dataRepresentation() else { throw NotebookFailure.invalid("Could not create PDF data.") }
            try bytes.write(to: url, options: .atomic)
        }
    }
    static func makePDF(_ snapshots: [PrintPageSnapshot], media: [String: StoredFile], paper: PrintPaper, progress: (String) -> Void = { _ in }) async throws -> PDFDocument {
        let result = PDFDocument()
        var totalBytes = 0
        for original in snapshots {
            var snapshot = original
            try Task.checkCancellation()
            for element in snapshot.page.elements {
                let f = element.frame
                guard [f.x, f.y, f.width, f.height].allSatisfy({ $0.isFinite && abs($0) <= 1_000_000 }) else {
                    throw NotebookFailure.invalid("A page is too large to print. Resize or move its objects first.")
                }
            }
            for i in snapshot.page.elements.indices {
                snapshot.page.elements[i].frame.height = ElementLayout.height(snapshot.page.elements[i])
            }
            var width: Double = 816
            var bodyHeight: Double = 912
            for element in snapshot.page.elements {
                width = max(width, element.frame.x + element.frame.width + 48)
                bodyHeight = max(bodyHeight, element.frame.y + element.frame.height + 48)
            }
            let height = bodyHeight + PageHeaderLayout.height(title: snapshot.page.displayTitle, width: width)
            let scale: Double = Double(paper.size.width - 48) / width
            let sliceHeight: Double = Double(paper.size.height - 48) / scale
            let countValue = ceil(height / sliceHeight)
            guard width.isFinite, height.isFinite, countValue.isFinite, countValue >= 1,
                  countValue <= 500, result.pageCount + Int(countValue) <= 500 else {
                throw NotebookFailure.invalid("This export exceeds 500 printed sheets. Export fewer pages at a time.")
            }
            for slice in 0..<Int(countValue) {
                try Task.checkCancellation()
                let view = NotebookPrintSheet(snapshot: snapshot, media: media, paper: paper,
                    canvasWidth: width, scale: scale, sliceOffset: Double(slice) * sliceHeight)
                let bytes = view.dataWithPDF(inside: view.bounds)
                totalBytes += bytes.count
                guard totalBytes <= 200 * 1024 * 1024 else { throw NotebookFailure.invalid("This PDF exceeds 200 MB. Export fewer notebook pages at a time.") }
                guard let single = PDFDocument(data: bytes), let page = single.page(at: 0) else {
                    throw NotebookFailure.invalid("A page could not be rendered for printing.")
                }
                result.insert(page, at: result.pageCount)
                progress("Preparing printed sheet \(result.pageCount)…")
                await Task.yield()
            }
        }
        return result
    }
}

@MainActor
private final class NotebookPrintSheet: NSView {
    let snapshot: PrintPageSnapshot
    let media: [String: StoredFile]
    let canvasWidth: Double
    let scale: Double
    let sliceOffset: Double
    private var headerHeight: Double { PageHeaderLayout.height(title: snapshot.page.displayTitle, width: canvasWidth) }
    init(snapshot: PrintPageSnapshot, media: [String: StoredFile], paper: PrintPaper,
         canvasWidth: Double, scale: Double, sliceOffset: Double) {
        self.snapshot = snapshot; self.media = media; self.canvasWidth = canvasWidth
        self.scale = scale; self.sliceOffset = sliceOffset
        super.init(frame: CGRect(origin: .zero, size: paper.size))
    }
    required init?(coder: NSCoder) { fatalError("Not used") }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.clip(to: bounds.insetBy(dx: 24, dy: 24))
        context.translateBy(x: 24, y: 24); context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: -sliceOffset)
        let design = snapshot.page.paperDesign ?? PaperDesign()
        context.setFillColor(NSColor(Color(hex: design.paperColor)).cgColor)
        context.fill(CGRect(x: 0, y: sliceOffset, width: canvasWidth, height: bounds.height / scale))
        if sliceOffset < headerHeight { drawHeader() }
        context.translateBy(x: 0, y: headerHeight)
        drawPaper(context)
        // Ink overlays allow annotations on imported PDF printouts.
        let visible = CGRect(x: 0, y: sliceOffset - headerHeight, width: canvasWidth, height: bounds.height / scale)
        let elements = snapshot.page.elements.filter {
            CGRect(x: $0.frame.x, y: $0.frame.y, width: max(1, $0.frame.width), height: max(1, $0.frame.height))
                .insetBy(dx: -16, dy: -16).intersects(visible)
        }
        for element in elements { drawElement(element, context: context) }
        for element in elements { if case .ink(let strokes) = element.content { drawInk(strokes, element: element, context: context) } }
        context.restoreGState()
    }
    private func text(_ string: String, size: CGFloat, color: NSColor = .black) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: color])
    }
    private func drawHeader() {
        let title = text(snapshot.page.displayTitle, size: 28)
        let titleHeight = min(68, max(34, ceil(title.boundingRect(with: NSSize(width: canvasWidth - 96, height: 68), options: [.usesLineFragmentOrigin]).height)))
        title.draw(with: NSRect(x: 48, y: 16, width: canvasWidth - 96, height: titleHeight), options: [.usesLineFragmentOrigin])
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
        let dateY = 16 + titleHeight + 6
        text(formatter.string(from: snapshot.page.createdAt), size: 13, color: .gray).draw(at: NSPoint(x: 48, y: dateY))
        NSColor.lightGray.setStroke()
        let line = NSBezierPath(); line.move(to: NSPoint(x: 48, y: dateY + 22))
        line.line(to: NSPoint(x: canvasWidth - 48, y: dateY + 22)); line.lineWidth = 0.5; line.stroke()
        text(snapshot.subheader, size: 14, color: .gray).draw(in: NSRect(x: 48, y: dateY + 29, width: canvasWidth - 96, height: 22))
    }
    private func drawPaper(_ context: CGContext) {
        let design = snapshot.page.paperDesign ?? PaperDesign()
        let top = max(0, sliceOffset - headerHeight)
        let bottom = top + bounds.height / scale
        if snapshot.page.background != .plain {
            context.setStrokeColor(NSColor(Color(hex: design.ruleColor)).cgColor); context.setLineWidth(0.7)
            let start = max(design.spacing + 4, ceil((Double(top) - 4) / design.spacing) * design.spacing + 4)
            for y in stride(from: start, through: Double(bottom), by: design.spacing) {
                context.move(to: CGPoint(x: 0, y: y)); context.addLine(to: CGPoint(x: canvasWidth, y: y))
            }
            if snapshot.page.background == .grid {
                for x in stride(from: design.spacing, through: Double(canvasWidth), by: design.spacing) {
                    context.move(to: CGPoint(x: x, y: top)); context.addLine(to: CGPoint(x: x, y: bottom))
                }
            }
            context.strokePath()
        }
        if design.marginEnabled {
            context.setStrokeColor(NSColor(Color(hex: design.marginColor)).cgColor); context.setLineWidth(1)
            context.move(to: CGPoint(x: design.marginPosition, y: top)); context.addLine(to: CGPoint(x: design.marginPosition, y: bottom)); context.strokePath()
        }
    }
    private func drawElement(_ element: PageElement, context: CGContext) {
        if element.flowBlocks != nil {
            context.saveGState()
            context.translateBy(x: element.frame.x + 4, y: element.frame.y + 4)
            for block in FlowLayout.arranged(element) { drawElement(block, context: context) }
            context.restoreGState()
            return
        }
        let f = element.frame
        let rect = NSRect(x: f.x + 4, y: f.y + 4, width: max(1, f.width - 8), height: max(1, f.height - 8))
        switch element.content {
        case .text(let value): drawText(RichTextCodec.fromMarkdown(value), rect: rect)
        case .richText(let value): drawText(value, rect: rect)
        case .image(let name):
            guard let data = media[name]?.regularFileContents else { return }
            if name.lowercased().hasSuffix(".pdf"), let provider = CGDataProvider(data: data as CFData),
               let pdf = CGPDFDocument(provider), let page = pdf.page(at: 1) {
                context.saveGState()
                context.translateBy(x: rect.minX, y: rect.maxY); context.scaleBy(x: 1, y: -1)
                context.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(origin: .zero, size: rect.size), rotate: 0, preserveAspectRatio: true))
                context.drawPDFPage(page); context.restoreGState()
            } else if let image = NSImage(data: data) {
                let ratio = min(rect.width / max(1, image.size.width), rect.height / max(1, image.size.height))
                let size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
                image.draw(in: NSRect(origin: rect.origin, size: size), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            }
        case .table(let rows):
            let widths = ElementLayout.columns(rows, width: rect.width, saved: element.tableColumnWidths)
            let heights = ElementLayout.rows(rows, columns: widths, minimum: 0)
            var y = rect.minY
            for (r, row) in rows.enumerated() {
                var x = rect.minX
                for (c, cell) in row.enumerated() {
                    let cellRect = NSRect(x: x, y: y, width: widths[c], height: heights[r])
                    if let color = element.tableCellColors?["\(r):\(c)"] { NSColor(Color(hex: color)).setFill(); cellRect.fill() }
                    NSColor.gray.setStroke(); let border = NSBezierPath(rect: cellRect); border.lineWidth = 1; border.stroke()
                    ElementLayout.cell(cell).draw(with: cellRect.insetBy(dx: ElementLayout.cellHorizontalPadding, dy: ElementLayout.cellVerticalPadding), options: [.usesLineFragmentOrigin, .usesFontLeading])
                    x += widths[c]
                }
                y += heights[r]
            }
        case .attachment(_, let name): text("Attachment: " + name, size: 13).draw(in: rect)
        case .ink: break
        }
    }
    private func drawText(_ value: RichTextContent, rect: NSRect) {
        let storage = NSTextStorage(attributedString: RichTextCodec.attributed(value))
        let manager = NSLayoutManager(); let container = NSTextContainer(containerSize: NSSize(width: max(1, rect.width - 8), height: 1_000_000))
        container.lineFragmentPadding = 0; manager.addTextContainer(container); storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        let range = manager.glyphRange(for: container); let origin = NSPoint(x: rect.minX + 4, y: rect.minY + 4)
        manager.drawBackground(forGlyphRange: range, at: origin); manager.drawGlyphs(forGlyphRange: range, at: origin)
    }
    private func drawInk(_ strokes: [Stroke], element: PageElement, context: CGContext) {
        context.saveGState(); context.translateBy(x: element.frame.x, y: element.frame.y)
        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            let opacity = stroke.opacity ?? (stroke.kind == .highlighter ? 0.35 : 1)
            let color = NSColor(Color(hex: stroke.colorHex)).withAlphaComponent(opacity).cgColor
            context.setStrokeColor(color); context.setFillColor(color); context.setLineWidth(stroke.width)
            context.setLineCap(stroke.kind == .highlighter ? .butt : .round); context.setLineJoin(.round)
            if stroke.points.count == 1 {
                context.fillEllipse(in: CGRect(x: first.x - stroke.width / 2, y: first.y - stroke.width / 2, width: stroke.width, height: stroke.width)); continue
            }
            context.move(to: CGPoint(x: first.x, y: first.y))
            if stroke.points.count == 2, let last = stroke.points.last { context.addLine(to: CGPoint(x: last.x, y: last.y)) }
            else {
                for i in 1..<stroke.points.count {
                    let a = stroke.points[i - 1], b = stroke.points[i]
                    context.addQuadCurve(to: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), control: CGPoint(x: a.x, y: a.y))
                }
                if let last = stroke.points.last { context.addLine(to: CGPoint(x: last.x, y: last.y)) }
            }
            context.strokePath()
        }
        context.restoreGState()
    }
}
