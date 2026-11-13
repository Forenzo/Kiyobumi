import XCTest
import Foundation
@testable import OpenNotebook

final class PageInteractionTests: XCTestCase {
    func testOptionalSubheaderSurvivesNotebookSaveWithoutChangingSchemaOrTitle() throws {
        var document = NotebookDocument()
        let pageID = try XCTUnwrap(document.notebook.pages.keys.first)
        let title = document.notebook.pages[pageID]?.title
        var headers = PageHeaderMetadata()
        headers.set("清文 — Optional subtitle 😀", for: pageID)
        document.ancillary[PageHeaderMetadata.fileName] = try headers.storedFile()
        let package = try document.package()
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with:
            XCTUnwrap(package.fileWrappers?["manifest.json"]?.regularFileContents)) as? [String: Any])
        XCTAssertEqual(manifest["schemaVersion"] as? Int, 3)
        let reopened = try NotebookDocument.read(package)
        XCTAssertEqual(try PageHeaderMetadata.read(reopened.ancillary[PageHeaderMetadata.fileName]), headers)
        XCTAssertEqual(reopened.notebook.pages[pageID]?.title, title)
        XCTAssertEqual(reopened.ancillary[PageHeaderMetadata.fileName], document.ancillary[PageHeaderMetadata.fileName])
    }
    func testUnsupportedSubheaderMetadataIsRejectedButPreservedByNotebookCodec() throws {
        var document = NotebookDocument()
        let bytes = Data(#"{"format":"org.kiyobumi.page-headers","version":2,"subheaders":{},"future":"keep"}"#.utf8)
        document.ancillary[PageHeaderMetadata.fileName] = .data(bytes)
        XCTAssertThrowsError(try PageHeaderMetadata.read(document.ancillary[PageHeaderMetadata.fileName]))
        let reopened = try NotebookDocument.read(document.package())
        XCTAssertEqual(reopened.ancillary[PageHeaderMetadata.fileName]?.regularFileContents, bytes)
    }
    func testNewSubpageGoesAfterExistingDescendantsAndHonorsDepthLimit() {
        var root = Page(); root.level = 0
        var child = Page(); child.level = 1
        var grandchild = Page(); grandchild.level = 2
        var next = Page(); next.level = 0
        let section = Section(name: "Hierarchy", pageIDs: [root.id, child.id, grandchild.id, next.id])
        let pages = Dictionary(uniqueKeysWithValues: [root, child, grandchild, next].map { ($0.id, $0) })
        XCTAssertEqual(PageHierarchy.subpageInsertionIndex(after: root.id, in: section, pages: pages), 3)
        XCTAssertEqual(PageHierarchy.subpageInsertionIndex(after: child.id, in: section, pages: pages), 3)
        XCTAssertNil(PageHierarchy.subpageInsertionIndex(after: grandchild.id, in: section, pages: pages))
        XCTAssertNil(PageHierarchy.subpageInsertionIndex(after: UUID(), in: section, pages: pages))
    }
    func testMagnificationUsesGestureStartAndDoesNotJumpFromSmallFitScale() {
        XCTAssertEqual(PageZoom.magnified(from: 1, by: 1.1), 1.1, accuracy: 0.0001)
        XCTAssertEqual(PageZoom.magnified(from: 1, by: 1.2), 1.2, accuracy: 0.0001)
        XCTAssertEqual(PageZoom.magnified(from: 0.1, by: 1.1), 0.11, accuracy: 0.0001)
        XCTAssertEqual(PageZoom.magnified(from: 1, by: 10), 4)
        XCTAssertEqual(PageZoom.magnified(from: 1, by: 0.001), 0.1)
        XCTAssertEqual(PageZoom.magnified(from: 2, by: .nan), 2)
    }
}
