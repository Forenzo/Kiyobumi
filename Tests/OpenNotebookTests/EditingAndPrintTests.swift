import XCTest
import AppKit
import PDFKit
@testable import OpenNotebook

final class EditingAndPrintTests: XCTestCase {
    func testNewFormattingAndTableGeometryRoundTripAsSchemaFour() throws {
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        var style = TextFormat(); style.highlightHex = "#FFF176"
        let note = PageElement(frame: Frame(x: 40, y: 40, width: 420, height: 160),
            content: .richText(RichTextContent(text: "Highlighted 清文", defaultFormat: style)), minimumHeight: 160)
        let table = PageElement(frame: Frame(x: 40, y: 240, width: 620, height: 180),
            content: .table(rows: [["Wide", "Narrow"], ["One", "Two"]]), minimumHeight: 180, tableColumnWidths: [3, 1])
        document.notebook.pages[id]?.elements = [note, table]
        let wrapper = try document.package()
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(wrapper.fileWrappers?["manifest.json"]?.regularFileContents)) as? [String: Any])
        XCTAssertEqual(manifest["schemaVersion"] as? Int, 4)
        XCTAssertEqual(try NotebookDocument.read(wrapper).notebook.pages[id]?.elements, [note, table])
    }
    func testInvalidHighlightAndColumnGeometryCannotBeSaved() throws {
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        var style = TextFormat(); style.highlightHex = "invalid"
        document.notebook.pages[id]?.elements = [PageElement(frame: .zero,
            content: .richText(RichTextContent(text: "test", defaultFormat: style)))]
        XCTAssertThrowsError(try document.package())
        document.notebook.pages[id]?.elements = [PageElement(frame: .zero,
            content: .table(rows: [["A", "B"]]), tableColumnWidths: [1])]
        XCTAssertThrowsError(try document.package())
    }
    @MainActor
    func testRemovingHighlightDoesNotInheritDefaultBackground() {
        var highlighted = TextFormat(); highlighted.highlightHex = "#FFF176"
        let normal = TextFormat()
        let value = RichTextContent(text: "AB", runs: [TextSpan(location: 1, length: 1, format: normal)], defaultFormat: highlighted)
        let attributed = RichTextCodec.attributed(value)
        XCTAssertNotNil(attributed.attribute(.backgroundColor, at: 0, effectiveRange: nil))
        XCTAssertNil(attributed.attribute(.backgroundColor, at: 1, effectiveRange: nil))
        let decoded = RichTextCodec.value(attributed, defaultFormat: highlighted)
        XCTAssertEqual(decoded.runs.first?.format.highlightHex, "#FFF176")
        XCTAssertNil(decoded.runs.last?.format.highlightHex)
    }
    @MainActor
    func testTableColumnResizeAndTextReflowPreserveMinimums() {
        let rows = [[String(repeating: "Wrapped words ", count: 30), "B"]]
        let wide = ElementLayout.columns(rows, width: 600, saved: [3, 1])
        let narrow = ElementLayout.columns(rows, width: 200, saved: [3, 1])
        XCTAssertEqual(wide.reduce(0, +), 600, accuracy: 0.001)
        XCTAssertTrue(wide[0] > wide[1])
        XCTAssertTrue(narrow.allSatisfy { $0 >= 48 })
        let a = ElementLayout.rows(rows, columns: wide, minimum: 0).reduce(0, +)
        let b = ElementLayout.rows(rows, columns: narrow, minimum: 0).reduce(0, +)
        XCTAssertGreaterThan(b, a)
        let tall = PageElement(frame: Frame(x: 0, y: 0, width: 200, height: 400),
            content: .richText(RichTextContent(text: "short")), minimumHeight: 400)
        XCTAssertEqual(ElementLayout.height(tall), 400)
    }
    @MainActor
    func testIndependentColumnsKeepNeighboursAndRoundTrip() throws {
        let rows = [["A", "B", "C"]]
        let start = [160.0, 200.0, 240.0]
        let grown = ElementLayout.resizedColumn(start, index: 1, translation: 90)
        XCTAssertEqual(grown, [160, 290, 240])
        let last = ElementLayout.resizedColumn(grown, index: 2, translation: -10_000)
        XCTAssertEqual(last[0], 160)
        XCTAssertEqual(last[1], 290)
        XCTAssertEqual(last[2], 48.001, accuracy: 0.0001)
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        let table = PageElement(frame: Frame(x: 48, y: 48, width: last.reduce(0, +) + 8, height: 100),
            content: .table(rows: rows), tableColumnWidths: last.map { $0 - 48 })
        document.notebook.pages[id]?.elements = [table]
        let restored = try NotebookDocument.read(document.package())
        let element = try XCTUnwrap(restored.notebook.pages[id]?.elements.first)
        let widths = ElementLayout.columns(rows, width: element.frame.width - 8, saved: element.tableColumnWidths)
        for index in last.indices { XCTAssertEqual(widths[index], last[index], accuracy: 0.0001) }
        XCTAssertEqual(ElementLayout.resizedColumn([160], index: 0, translation: 50), [210])
    }
    @MainActor
    func testCompactRowsGrowOnlyWhereContentNeedsIt() {
        let widths = [200.0, 200.0]
        let blank = ElementLayout.rows([["", ""]], columns: widths, minimum: 0)[0]
        XCTAssertLessThan(blank, 30)
        XCTAssertGreaterThan(blank, 14)
        let single = ElementLayout.rows([["Unit", "kg"]], columns: widths, minimum: 0)[0]
        XCTAssertEqual(single, blank, accuracy: 1)
        let multiline = ElementLayout.rows([["a\nb\nc", "kg"], ["", ""]], columns: widths, minimum: 0)
        XCTAssertGreaterThan(multiline[0], 2 * blank)
        XCTAssertEqual(multiline[1], blank)
        let newline = ElementLayout.rows([["a\n", ""]], columns: widths, minimum: 0)[0]
        XCTAssertGreaterThan(newline, single)
        let wrapped = ElementLayout.rows([[String(repeating: "words ", count: 20), ""]], columns: [80, 200], minimum: 0)[0]
        XCTAssertGreaterThan(wrapped, single)
    }
    @MainActor
    func testTableHeightIgnoresOldManualMinimumAndEditingControls() {
        let table = PageElement(frame: Frame(x: 48, y: 48, width: 400, height: 800),
            content: .table(rows: [["one", "kg"], ["two", "m"]]), minimumHeight: 800)
        let height = ElementLayout.height(table)
        XCTAssertLessThan(height, 80)
        XCTAssertEqual(ElementLayout.height(table, editing: true), height)
        var multiline = table
        multiline.content = .table(rows: [["one\ntwo\nthree", "kg"], ["two", "m"]])
        XCTAssertGreaterThan(ElementLayout.height(multiline), height)
    }
    @MainActor
    func testTableArrowEdgesUseVisualLinesIncludingTrailingBlank() {
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 300))
        view.font = .systemFont(ofSize: 14)
        view.string = "first\nmiddle\nlast\n"
        view.setSelectedRange(NSRange(location: 1, length: 0))
        XCTAssertTrue(TableCellNavigation.atVerticalEdge(view, top: true))
        XCTAssertFalse(TableCellNavigation.atVerticalEdge(view, top: false))
        view.setSelectedRange(NSRange(location: 7, length: 0))
        XCTAssertFalse(TableCellNavigation.atVerticalEdge(view, top: true))
        XCTAssertFalse(TableCellNavigation.atVerticalEdge(view, top: false))
        view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
        XCTAssertTrue(TableCellNavigation.atVerticalEdge(view, top: false))
        XCTAssertFalse(TableCellNavigation.atVerticalEdge(view, top: true))
        view.string = String(repeating: "wrapped words ", count: 20)
        view.setSelectedRange(NSRange(location: 0, length: 0))
        XCTAssertTrue(TableCellNavigation.atVerticalEdge(view, top: true))
        XCTAssertFalse(TableCellNavigation.atVerticalEdge(view, top: false))
        view.string = ""
        view.setSelectedRange(NSRange(location: 0, length: 0))
        XCTAssertTrue(TableCellNavigation.atVerticalEdge(view, top: true))
        XCTAssertTrue(TableCellNavigation.atVerticalEdge(view, top: false))
    }
    @MainActor
    func testTextBoxesWidenForLongLinesAndKeepExplicitBreaks() {
        let text = String(repeating: "Growing text ", count: 25)
        let value = RichTextContent(text: text)
        let width = RichTextCodec.growingWidth(value, current: 200)
        XCTAssertGreaterThan(width, 200)
        XCTAssertLessThan(RichTextCodec.height(value, width: width), RichTextCodec.height(value, width: 200))
        let twoLines = RichTextContent(text: text + "\n" + text)
        XCTAssertEqual(RichTextCodec.growingWidth(twoLines, current: 200), width, accuracy: 1)
        XCTAssertGreaterThan(RichTextCodec.height(twoLines, width: width), RichTextCodec.height(value, width: width))
        XCTAssertEqual(RichTextCodec.growingWidth(RichTextContent(text: "short"), current: width), width)
        var large = TextFormat(); large.fontSize = 40
        XCTAssertGreaterThan(RichTextCodec.growingWidth(RichTextContent(text: text, defaultFormat: large), current: 200), width)
    }
    @MainActor
    func testPDFPaginationIncludesFinalContentAndPreservesSectionOrder() async throws {
        var first = Page(title: "FIRST PAGE")
        first.elements = [PageElement(frame: Frame(x: 48, y: 1900, width: 400, height: 50),
            content: .richText(RichTextContent(text: "FINAL CONTENT MARKER")))]
        let second = Page(title: "SECOND PAGE")
        let pdf = try await NotebookPrinting.makePDF([
            PrintPageSnapshot(page: first, subheader: "SUBHEADER MARKER"),
            PrintPageSnapshot(page: second, subheader: "")], media: [:], paper: .a4)
        XCTAssertGreaterThanOrEqual(pdf.pageCount, 3)
        XCTAssertTrue(pdf.page(at: 0)?.string?.contains("FIRST PAGE") == true)
        XCTAssertTrue(pdf.string?.contains("FINAL CONTENT MARKER") == true)
        XCTAssertTrue(pdf.page(at: pdf.pageCount - 1)?.string?.contains("SECOND PAGE") == true)
        XCTAssertTrue(pdf.string?.contains("SUBHEADER MARKER") == true)
    }
    @MainActor
    func testPDFPrintoutKeepsAllPagesAndDoesNotModifySource() async throws {
        let source = try await NotebookPrinting.makePDF([
            PrintPageSnapshot(page: Page(title: "SOURCE ONE"), subheader: ""),
            PrintPageSnapshot(page: Page(title: "SOURCE TWO"), subheader: "")], media: [:], paper: .letter)
        let bytes = try XCTUnwrap(source.dataRepresentation())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try bytes.write(to: url); defer { try? FileManager.default.removeItem(at: url) }
        let sheets = try await PrintoutImporter.load(url) { _ in }
        XCTAssertEqual(sheets.count, 2)
        XCTAssertTrue(PDFDocument(data: sheets[0].data)?.string?.contains("SOURCE ONE") == true)
        XCTAssertTrue(PDFDocument(data: sheets[1].data)?.string?.contains("SOURCE TWO") == true)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    @MainActor
    func testLongTextPrintoutKeepsItsLastLine() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        try (String(repeating: "Printable line\n", count: 150) + "END OF DOCUMENT").write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let sheets = try await PrintoutImporter.load(url) { _ in }
        XCTAssertGreaterThan(sheets.count, 1)
        let last = try XCTUnwrap(sheets.last)
        XCTAssertTrue(PDFDocument(data: last.data)?.string?.contains("END OF DOCUMENT") == true)
    }
}
