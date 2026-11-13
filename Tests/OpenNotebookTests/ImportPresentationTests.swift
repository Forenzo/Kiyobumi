import XCTest
import Foundation
@testable import OpenNotebook

final class ImportPresentationTests: XCTestCase {
    func testHugeParserErrorKeepsShortSummaryAndBoundedCopyableDetails() {
        let dump = "Import failed: Unexpected node: " + String(repeating: "ObjectInfoDependencyOverride { oid: 245 } ", count: 10000)
        let problem = ImportProblem(OneNoteImportFailure(details: dump))
        XCTAssertLessThan(problem.summary.count, 240)
        XCTAssertTrue(problem.summary.contains("record"))
        XCTAssertLessThan(problem.details.count, 33000)
        XCTAssertTrue(problem.details.contains("Remaining diagnostic text omitted"))
    }
    func testOtherLongErrorsAreAlsoBounded() {
        let problem = ImportProblem(NotebookFailure.invalid(String(repeating: "x", count: 100000)))
        XCTAssertLessThan(problem.summary.count, 300)
        XCTAssertLessThan(problem.details.count, 33000)
    }
    func testInitialWindowFitsSmallScreenWithVisibleEdges() {
        let screen = CGRect(x: 100, y: 50, width: 1280, height: 760)
        let frame = NotebookWindowSizePolicy.initialFrame(current: CGRect(x: 300,y: 200,width: 820,height: 520), visible: screen)
        XCTAssertTrue(screen.contains(frame))
        XCTAssertGreaterThan(frame.width, 820)
        XCTAssertGreaterThan(frame.height, 520)
    }
    func testInitialWindowUsesRoomOnLargeScreen() {
        let frame = NotebookWindowSizePolicy.initialFrame(current: CGRect(x: 0,y: 0,width: 820,height: 520), visible: CGRect(x: 0,y: 0,width: 1920,height: 1040))
        XCTAssertEqual(frame.width, 1400)
        XCTAssertEqual(frame.height, 900)
    }
}
