import XCTest
import Foundation
@testable import OpenNotebook

final class NotebookDocumentTests: XCTestCase {
    func testRoundTrip() throws {
        let original = NotebookDocument()
        let package = try original.package()
        let reopened = try NotebookDocument.read(package)
        // ISO8601 JSON stores whole seconds; compare serialized packages.
        XCTAssertEqual(try reopened.package().fileWrappers?["manifest.json"]?.regularFileContents,
                       package.fileWrappers?["manifest.json"]?.regularFileContents)
        XCTAssertEqual(reopened.notebook.sections, original.notebook.sections)
        XCTAssertEqual(reopened.notebook.pages.values.first?.elements, original.notebook.pages.values.first?.elements)
    }
    func testManifestDoesNotDuplicatePageContents() throws {
        let data = try XCTUnwrap(NotebookDocument().package().fileWrappers?["manifest.json"]?.regularFileContents)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["pages"])
        XCTAssertEqual(json["schemaVersion"] as? Int, 3)
    }
    func testMissingPageFails() throws {
        let package = try NotebookDocument().package()
        let pages = try XCTUnwrap(package.fileWrappers?["pages"])
        for wrapper in pages.fileWrappers?.values ?? Dictionary<String,FileWrapper>().values { pages.removeFileWrapper(wrapper) }
        XCTAssertThrowsError(try NotebookDocument.read(package))
    }
    func testCorruptPageFails() throws {
        let package = try NotebookDocument().package()
        let pages = try XCTUnwrap(package.fileWrappers?["pages"])
        let entry = try XCTUnwrap(pages.fileWrappers?.first)
        pages.removeFileWrapper(entry.value)
        pages.addRegularFile(withContents: Data("broken json".utf8), preferredFilename: entry.key)
        XCTAssertThrowsError(try NotebookDocument.read(package))
    }
    func testUnknownVersionFails() throws {
        let package = try NotebookDocument().package()
        let wrapper = try XCTUnwrap(package.fileWrappers?["manifest.json"])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(wrapper.regularFileContents)) as? [String: Any])
        json["schemaVersion"] = 999
        package.removeFileWrapper(wrapper)
        package.addRegularFile(withContents: try JSONSerialization.data(withJSONObject: json), preferredFilename: "manifest.json")
        XCTAssertThrowsError(try NotebookDocument.read(package))
    }
    func testMediaAndAncillaryPreserved() throws {
        var original = NotebookDocument()
        original.media["test.bin"] = .data(Data([1,2,3]))
        original.ancillary["notes.txt"] = .data(Data("retained".utf8))
        let reopened = try NotebookDocument.read(original.package())
        let saved = try reopened.package()
        XCTAssertEqual(saved.fileWrappers?["media"]?.fileWrappers?["test.bin"]?.regularFileContents, Data([1,2,3]))
        XCTAssertEqual(saved.fileWrappers?["notes.txt"]?.regularFileContents, Data("retained".utf8))
    }
    func testOrphanPageRejected() throws {
        var document = NotebookDocument()
        let orphan = Page()
        document.notebook.pages[orphan.id] = orphan
        XCTAssertThrowsError(try document.package())
    }
    func testPathTraversalImageRejected() throws {
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        document.notebook.pages[id]?.elements.append(PageElement(frame: .zero, content: .image(mediaName: "../secret")))
        XCTAssertThrowsError(try document.package())
    }
    func testMissingImageRejected() throws {
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        document.notebook.pages[id]?.elements.append(PageElement(frame: .zero, content: .image(mediaName: "missing.png")))
        XCTAssertThrowsError(try document.package())
    }
    func testUnknownManifestFieldsRejected() throws {
        let package = try NotebookDocument().package()
        let wrapper = try XCTUnwrap(package.fileWrappers?["manifest.json"])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(wrapper.regularFileContents)) as? [String: Any])
        json["futureField"] = "must not disappear"
        package.removeFileWrapper(wrapper)
        package.addRegularFile(withContents: try JSONSerialization.data(withJSONObject: json), preferredFilename: "manifest.json")
        XCTAssertThrowsError(try NotebookDocument.read(package))
    }
    func testExampleNotebookOpens() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let wrapper = try FileWrapper(url: root.appendingPathComponent("examples/Welcome.onbook"), options: .immediate)
        let document = try NotebookDocument.read(wrapper)
        XCTAssertEqual(document.notebook.name, "Welcome")
        XCTAssertEqual(document.notebook.pages.count, 1)
    }
    func testPortableElementEncoding() throws {
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ElementContent.text(markdown: "hello"))) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "text")
        XCTAssertEqual(json["markdown"] as? String, "hello")
    }
    func testV1PageDefaultsAreMigrated() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let document = try NotebookDocument.read(FileWrapper(url: root.appendingPathComponent("examples/Welcome.onbook"), options: .immediate))
        let page = try XCTUnwrap(document.notebook.pages.values.first)
        XCTAssertEqual(page.level, 0)
        XCTAssertEqual(page.background, .plain)
        let saved = try XCTUnwrap(document.package().fileWrappers?["manifest.json"]?.regularFileContents)
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        XCTAssertEqual(manifest["schemaVersion"] as? Int, 3)
    }
    func testV2TableAttachmentAndBackgroundRoundTrip() throws {
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        document.media["attachment.bin"] = .data(Data([9,8,7]))
        document.notebook.pages[id]?.level = 1
        document.notebook.pages[id]?.background = .grid
        document.notebook.pages[id]?.elements += [
            PageElement(frame: Frame(x: 20, y: 300, width: 400, height: 100), content: .table(rows: [["a", "b"], ["c", "😀"]])),
            PageElement(frame: Frame(x: 20, y: 500, width: 300, height: 50), content: .attachment(mediaName: "attachment.bin", fileName: "notes.pdf"))
        ]
        let reopened = try NotebookDocument.read(document.package())
        XCTAssertEqual(reopened.notebook.pages[id]?.elements, document.notebook.pages[id]?.elements)
        XCTAssertEqual(reopened.notebook.pages[id]?.background, .grid)
        XCTAssertEqual(reopened.notebook.pages[id]?.level, 1)
        XCTAssertTrue(reopened.notebook.pages[id]?.searchableText.contains("😀") == true)
    }
    func testRaggedTableRejected() throws {
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        document.notebook.pages[id]?.elements.append(PageElement(frame: .zero, content: .table(rows: [["a"], ["b", "c"]])))
        XCTAssertThrowsError(try document.package())
    }
    func testNestedAncillarySnapshotPreserved() throws {
        var document = NotebookDocument()
        document.ancillary["extra"] = .directory(["notes.txt": .data(Data("retained".utf8))])
        let reopened = try NotebookDocument.read(document.package())
        XCTAssertEqual(reopened.ancillary, document.ancillary)
    }

    func testRenamedPageKeepsOriginalCreationDateOnDisk() throws {
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        let originalDate = Date(timeIntervalSince1970: 1_260_000_004)
        document.notebook.pages[id]?.createdAt = originalDate
        document.notebook.pages[id]?.title = "A renamed page"
        document.notebook.pages[id]?.modifiedAt = Date(timeIntervalSince1970: 1_770_000_005)
        let reopened = try NotebookDocument.read(document.package())
        let page = try XCTUnwrap(reopened.notebook.pages[id])
        XCTAssertEqual(page.createdAt, originalDate)
        XCTAssertEqual(page.displayTitle, "A renamed page")
        XCTAssertTrue(page.searchableText.contains("A renamed page"))
        XCTAssertNotEqual(page.createdAt, page.modifiedAt)
    }

    func testBlankTitleHasVisibleUntitledLabel() {
        let page = Page(title: " \n\t")
        XCTAssertEqual(page.displayTitle, "Untitled page")
        XCTAssertEqual(page.title, " \n\t")
    }
}
