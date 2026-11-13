import XCTest
@testable import OpenNotebook

final class NotebookCollectionTests: XCTestCase {
    @MainActor func testNotebookNameCannotEscapeFolder() {
        for name in ["../outside", "/absolute/path", "..", ".", "", "a\\b:c\nfile"] {
            let stem = NotebookCollection.fileStem(name)
            XCTAssertFalse(stem.contains("/"))
            XCTAssertFalse(stem.contains("\\"))
            XCTAssertFalse(stem.contains(":"))
            XCTAssertFalse(stem.isEmpty)
            XCTAssertNotEqual(stem, ".")
            XCTAssertNotEqual(stem, "..")
        }
        XCTAssertEqual(NotebookCollection.fileStem(" 清文 "), "清文")
    }

    func testPageWordsExcludeLinkTargetsAndAttachments() {
        var page = Page(title: "Page title")
        page.elements = [
            PageElement(frame: .zero, content: .text(markdown: "**Hello** [world](https://example.com/unwanted)")),
            PageElement(frame: .zero, content: .table(rows: [["one", "two"], ["three", "four"]])),
            PageElement(frame: .zero, content: .attachment(mediaName: "file", fileName: "Do not count this.pdf")),
            PageElement(frame: .zero, content: .image(mediaName: "image words"))
        ]
        let text = PageWordCount.text(page: page, subtitle: "Extra heading")
        XCTAssertEqual(PageWordCount.count(text), 10)
        XCTAssertFalse(text.contains("example.com"))
        XCTAssertFalse(text.contains("Do not count"))
        XCTAssertEqual(PageWordCount.count("☑ ✓ • ✗"), 0)
        XCTAssertEqual(PageWordCount.count(PageWordCount.text(page: nil, subtitle: "Unused")), 0)
    }
}
