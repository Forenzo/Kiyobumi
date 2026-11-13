import XCTest
import AppKit
import PDFKit
@testable import OpenNotebook

final class FlowLayoutTests: XCTestCase {
    @MainActor
    func testRemovingSelectedTablePreservesParagraphsAndRoot() throws {
        let first = PageElement(frame: .zero, content: .richText(RichTextContent(text: "Before")))
        let table = PageElement(frame: Frame(x: 0, y: 0, width: 320, height: 100), content: .table(rows: [["A", "B"]]))
        let last = PageElement(frame: .zero, content: .richText(RichTextContent(text: "After")))
        var root = PageElement(frame: Frame(x: 40, y: 50, width: 500, height: 100),
            content: .richText(RichTextContent()), flowBlocks: [first, table, last])
        FlowLayout.fit(&root)
        let original = root
        FlowLayout.remove(table.id, from: &root)
        XCTAssertEqual(root.id, original.id)
        XCTAssertEqual(root.frame.x, 40); XCTAssertEqual(root.frame.y, 50)
        XCTAssertEqual(root.flowBlocks, [first, last])
        XCTAssertLessThan(root.frame.height, original.frame.height)
        let removed = root
        FlowLayout.remove(table.id, from: &root)
        XCTAssertEqual(root, removed)
        root = original // page-level undo restores the complete snapshot
        XCTAssertEqual(root.flowBlocks, [first, table, last])
    }

    @MainActor
    func testRemovingOnlyBlockLeavesEditableParagraph() throws {
        let table = PageElement(frame: Frame(x: 0, y: 0, width: 320, height: 100), content: .table(rows: [["A"]]))
        var root = PageElement(frame: Frame(x: 0, y: 0, width: 400, height: 100),
            content: .richText(RichTextContent()), flowBlocks: [table])
        FlowLayout.remove(table.id, from: &root)
        let blocks = try XCTUnwrap(root.flowBlocks)
        XCTAssertEqual(blocks.count, 1)
        guard case .richText(let value) = blocks[0].content else { return XCTFail("Missing editable paragraph") }
        XCTAssertEqual(value.text, "")
    }
    @MainActor
    func testEmbeddedTableKeepsOwnWidthAndCanShrinkInsideWideParagraph() throws {
        var table = PageElement(frame: Frame(x: 0, y: 0, width: 320, height: 80),
            content: .table(rows: [["A", "B"]]), tableColumnWidths: [108, 108])
        var root = PageElement(frame: Frame(x: 0, y: 0, width: 2000, height: 100),
            content: .richText(RichTextContent()), flowBlocks: [table])
        XCTAssertEqual(try XCTUnwrap(FlowLayout.arranged(root).first).frame.width, 320)
        let widths = ElementLayout.columns([["A", "B"]], width: 312, saved: table.tableColumnWidths)
        let shrunk = ElementLayout.resizedColumn(widths, index: 0, translation: -70)
        table.frame.width = shrunk.reduce(0, +) + 8
        table.tableColumnWidths = shrunk.map { max(0.001, $0 - 48) }
        root.flowBlocks = [table]
        FlowLayout.fit(&root)
        let displayed = try XCTUnwrap(FlowLayout.arranged(root).first)
        XCTAssertEqual(displayed.frame.width, 250, accuracy: 0.001)
        let actual = ElementLayout.columns([["A", "B"]], width: displayed.frame.width - 8, saved: displayed.tableColumnWidths)
        XCTAssertEqual(actual[0], shrunk[0], accuracy: 0.001)
        XCTAssertEqual(actual[1], widths[1], accuracy: 0.001)
        root.frame.width = 3000
        XCTAssertEqual(try XCTUnwrap(FlowLayout.arranged(root).first).frame.width, 250, accuracy: 0.001)
    }
    @MainActor
    func testInsertionSplitsFormattedTextAndReflowsAfterGrowth() throws {
        let bold = TextFormat(fontSize: 20, bold: true)
        let value = RichTextContent(text: "BeforeAfter", runs: [TextSpan(location: 0, length: 11, format: bold)])
        var root = PageElement(frame: Frame(x: 40, y: 50, width: 320, height: 80), content: .richText(value))
        let id = root.id
        let table = PageElement(frame: Frame(x: 0, y: 0, width: 320, height: 80), content: .table(rows: [["A", "B"]]), tableColumnWidths: [2, 1])
        XCTAssertTrue(FlowLayout.insert([table], into: &root, blockID: id, offset: 6))
        let blocks = try XCTUnwrap(root.flowBlocks)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(root.id, id)
        XCTAssertFalse(blocks.contains { $0.id == id })
        guard case .richText(let before) = blocks[0].content, case .richText(let after) = blocks[2].content else {
            return XCTFail("Text must remain editable around the table")
        }
        XCTAssertEqual(before.text, "Before"); XCTAssertEqual(after.text, "After")
        XCTAssertEqual(before.runs.first?.format, bold)
        XCTAssertEqual(after.runs.first?.location, 0)
        XCTAssertEqual(after.runs.first?.length, 5)
        let old = FlowLayout.arranged(root)
        root.flowBlocks?[0].content = .richText(RichTextContent(text: String(repeating: "line\n", count: 80)))
        FlowLayout.fit(&root)
        let grown = FlowLayout.arranged(root)
        XCTAssertGreaterThan(grown[1].frame.y, old[1].frame.y)
        XCTAssertGreaterThan(grown[2].frame.y, grown[1].frame.y + grown[1].frame.height)
        XCTAssertGreaterThan(root.frame.height, grown[2].frame.y + grown[2].frame.height)
        XCTAssertEqual(grown[1].tableColumnWidths, [2, 1])
        let trailingID = try XCTUnwrap(root.flowBlocks?.last?.id)
        let attachment = PageElement(frame: Frame(x: 0, y: 0, width: 200, height: 58),
            content: .attachment(mediaName: "source.bin", fileName: "source.csv"))
        XCTAssertTrue(FlowLayout.insert([attachment], into: &root, blockID: trailingID, offset: 2))
        XCTAssertEqual(root.flowBlocks?.count, 5)
        XCTAssertTrue(root.flowBlocks?.allSatisfy { $0.flowBlocks == nil } ?? false)
    }

    @MainActor
    func testUnicodeSplitNeverBreaksEmoji() {
        let value = RichTextContent(text: "A😀B")
        let parts = FlowLayout.split(value, at: 2)
        XCTAssertEqual(parts.0.text + parts.1.text, value.text)
        XCTAssertEqual(parts.0.text, "A")
        XCTAssertEqual(parts.1.text, "😀B")
    }

    @MainActor
    func testMixedMediaRoundTripsWithSchemaFiveAndRemainsSearchable() throws {
        var document = NotebookDocument()
        let pageID = try XCTUnwrap(document.notebook.pages.keys.first)
        var root = PageElement(frame: Frame(x: 10, y: 10, width: 400, height: 100),
            content: .richText(RichTextContent(text: "Before After")))
        let rootID = root.id
        let image = PageElement(frame: Frame(x: 0, y: 0, width: 300, height: 150), content: .image(mediaName: "plot.png"))
        let attachment = PageElement(frame: .zero, content: .attachment(mediaName: "data.bin", fileName: "Measurements.csv"))
        let table = PageElement(frame: Frame(x: 0, y: 0, width: 300, height: 80), content: .table(rows: [["Voltage", "Current"]]))
        XCTAssertTrue(FlowLayout.insert([table, image, attachment], into: &root, blockID: rootID, offset: 7))
        document.notebook.pages[pageID]?.elements = [root]
        document.media["plot.png"] = .data(Data([1, 2, 3]))
        document.media["data.bin"] = .data(Data("source bytes".utf8))
        let package = try document.package()
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(package.fileWrappers?["manifest.json"]?.regularFileContents)) as? [String: Any])
        XCTAssertEqual(manifest["schemaVersion"] as? Int, 5)
        let restored = try NotebookDocument.read(package)
        XCTAssertEqual(restored.notebook.pages[pageID]?.elements, [root])
        XCTAssertEqual(restored.media["data.bin"]?.regularFileContents, Data("source bytes".utf8))
        let page = try XCTUnwrap(restored.notebook.pages[pageID])
        XCTAssertTrue(page.searchableText.contains("Measurements.csv"))
        let words = PageWordCount.text(page: page, subtitle: "")
        XCTAssertTrue(words.contains("Voltage")); XCTAssertTrue(words.contains("After"))
        XCTAssertFalse(words.contains("Measurements.csv"))
        document.media.removeValue(forKey: "plot.png")
        XCTAssertThrowsError(try document.package())
    }

    func testNestedBlocksAndDuplicateIDsAreRejected() throws {
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        let leaf = PageElement(frame: .zero, content: .richText(RichTextContent()))
        var root = PageElement(frame: .zero, content: .richText(RichTextContent()), flowBlocks: [leaf, leaf])
        document.notebook.pages[id]?.elements = [root]
        XCTAssertThrowsError(try document.package())
        root.flowBlocks = [PageElement(frame: .zero, content: .richText(RichTextContent()), flowBlocks: [leaf])]
        document.notebook.pages[id]?.elements = [root]
        XCTAssertThrowsError(try document.package())
    }

    @MainActor
    func testMixedBoxExportsTextAndTableToPDF() async throws {
        var root = PageElement(frame: Frame(x: 20, y: 20, width: 500, height: 100), content: .richText(RichTextContent(text: "OpeningClosing")))
        let id = root.id
        let table = PageElement(frame: Frame(x: 0, y: 0, width: 400, height: 60), content: .table(rows: [["Voltage", "Current"]]))
        XCTAssertTrue(FlowLayout.insert([table], into: &root, blockID: id, offset: 7))
        let page = Page(title: "Mixed test", elements: [root])
        let pdf = try await NotebookPrinting.makePDF([PrintPageSnapshot(page: page, subheader: "")], media: [:], paper: .a4)
        let text = pdf.string ?? ""
        XCTAssertTrue(text.contains("Opening"))
        XCTAssertTrue(text.contains("Voltage"))
        XCTAssertTrue(text.contains("Closing"))
    }
}
