import XCTest
import Foundation
@testable import OpenNotebook

final class PageDesignTests: XCTestCase {
    func testSpreadsheetQuotedCellsAndPadding() throws {
        let rows = try TableText.parse("Name\tNotes\r\n\"A\tB\"\t\"Line 1\nLine 2 and \"\"quote\"\"\"\r\nShort\r\n")
        XCTAssertEqual(rows, [["Name", "Notes"], ["A\tB", "Line 1\nLine 2 and \"quote\""], ["Short", ""]])
        XCTAssertThrowsError(try TableText.parse("\"unfinished"))
        XCTAssertThrowsError(try TableText.parse(Array(repeating: "cell", count: 101).joined(separator: "\t")))
    }
    func testPaperAndNestedCellShadingRoundTrip() throws {
        var table = PageElement(frame: Frame(x: 0, y: 0, width: 300, height: 60), content: .table(rows: [["A", "B"]]))
        table.tableCellColors = ["0:1": "#FFF3B0"]
        var container = PageElement(frame: Frame(x: 48, y: 40, width: 400, height: 80), content: .richText(RichTextContent()))
        container.flowBlocks = [table]
        var page = Page(title: "Design test"); page.elements = [container]; page.background = .grid
        var design = PaperDesign(); design.spacing = 19; design.marginEnabled = true; design.paperColor = "#FFFEF5"
        page.paperDesign = design
        let document = NotebookDocument(notebook: Notebook(name: "Test", sections: [Section(name: "Section", pageIDs: [page.id])], pages: [page.id: page]))
        let package = try document.package()
        let manifest = try XCTUnwrap(package.fileWrappers?["manifest.json"]?.regularFileContents)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: manifest) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 6)
        let restored = try NotebookDocument.read(package)
        XCTAssertEqual(restored.notebook.pages[page.id]?.paperDesign, design)
        XCTAssertEqual(restored.notebook.pages[page.id]?.elements[0].flowBlocks?[0].tableCellColors, table.tableCellColors)
        var invalid = document; invalid.notebook.pages[page.id]?.paperDesign?.spacing = 0
        XCTAssertThrowsError(try invalid.package())
    }
    func testRemovedCellsLoseShading() {
        var table = PageElement(frame: .zero, content: .table(rows: [["A"]]))
        table.tableCellColors = ["0:0": "#FFFFFF", "0:1": "#FFFFFF", "1:0": "#FFFFFF"]
        table.trimCellColors()
        XCTAssertEqual(table.tableCellColors, ["0:0": "#FFFFFF"])
    }
    func testTemplateCopiesNestedMediaAndIDs() {
        let picture = PageElement(frame: .zero, content: .image(mediaName: "photo.png"))
        let attachment = PageElement(frame: .zero, content: .attachment(mediaName: "photo.png", fileName: "photo.png"))
        var container = PageElement(frame: .zero, content: .richText(RichTextContent()))
        container.flowBlocks = [picture, attachment]
        var original = Page(title: "Template"); original.elements = [container]
        let bytes = StoredFile.data(Data([1, 2, 3]))
        let template = PageTemplate(id: "test", name: "Test", page: original, media: ["photo.png": bytes, "unused": .data(Data())])
        let (copy, files) = template.freshPage()
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertNotEqual(copy.elements[0].id, container.id)
        XCTAssertNotEqual(copy.elements[0].flowBlocks?[0].id, picture.id)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.values.first, bytes)
        XCTAssertNil(files["photo.png"])
        if let content = copy.elements[0].flowBlocks?[0].content, case .image(let name) = content {
            XCTAssertEqual(files[name], bytes)
        } else { XCTFail("The template image was lost") }
    }
}
