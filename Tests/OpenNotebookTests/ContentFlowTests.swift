import XCTest
@testable import OpenNotebook

final class ContentFlowTests: XCTestCase {
    private func box(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> PageElement {
        PageElement(frame: Frame(x: x, y: y, width: width, height: height), content: .text(markdown: "note"))
    }

    func testGrowthPushesChainRegardlessOfStorageOrderAndLeavesNeighbour() {
        let top = box(0, 0, 200, 40)
        let middle = box(0, 60, 200, 1000)
        let bottom = box(0, 1080, 200, 40)
        let beside = box(250, 60, 200, 40)
        var elements = [bottom, beside, top, middle]
        elements[2].frame.height = 100
        ContentFlow.pushBelow(in: &elements, changedID: top.id, previous: top.frame)
        XCTAssertEqual(elements[3].frame.y, 112)
        XCTAssertEqual(elements[0].frame.y, 1124)
        XCTAssertEqual(elements[1], beside)
        XCTAssertEqual(elements[3].content, middle.content)
    }

    func testShrinkAndManualMovementDoNotReflow() {
        let top = box(0, 0, 200, 100)
        var elements = [top, box(0, 120, 200, 40)]
        elements[0].frame.height = 40
        ContentFlow.pushBelow(in: &elements, changedID: top.id, previous: top.frame)
        XCTAssertEqual(elements[1].frame.y, 120)
        elements[0].frame.y = 80
        elements[0].frame.height = 150
        ContentFlow.pushBelow(in: &elements, changedID: top.id, previous: top.frame)
        XCTAssertEqual(elements[1].frame.y, 120)
    }

    func testWidthGrowthPushesNewlyOverlappingBoxButNotBoxAbove() {
        let source = box(0, 100, 100, 100)
        let above = box(150, 0, 100, 200)
        var elements = [source, box(150, 150, 100, 40), above]
        elements[0].frame.width = 200
        ContentFlow.pushBelow(in: &elements, changedID: source.id, previous: source.frame)
        XCTAssertEqual(elements[1].frame.y, 212)
        XCTAssertEqual(elements[2], above)
    }

    func testLargeGapAndInkStayUnchangedAndRepeatedMeasurementDoesNothing() {
        let source = box(0, 0, 200, 40)
        let distant = box(0, 1000, 200, 40)
        let ink = PageElement(frame: Frame(x: 0, y: 60, width: 200, height: 40), content: .ink(strokes: []))
        var elements = [source, distant, ink]
        elements[0].frame.height = 100
        ContentFlow.pushBelow(in: &elements, changedID: source.id, previous: source.frame)
        XCTAssertEqual(elements[1], distant)
        XCTAssertEqual(elements[2], ink)
        let settled = elements
        let settledFrame = elements[0].frame
        ContentFlow.pushBelow(in: &elements, changedID: source.id, previous: settledFrame)
        XCTAssertEqual(elements, settled)
    }
}
