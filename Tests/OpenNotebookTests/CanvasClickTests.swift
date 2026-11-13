import XCTest
import AppKit
@testable import OpenNotebook

final class CanvasClickTests: XCTestCase {
    @MainActor
    func testSecondaryClickCreatesOnceAtUnscaledCanvasPoint() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 600, height: 600),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let probe = CanvasMiddleClick.Probe(frame: CGRect(x: 30, y: 40, width: 400, height: 400))
        window.contentView!.addSubview(probe)
        // Simulate a scaled native canvas and its offset within the window.
        probe.bounds = CGRect(x: 0, y: 0, width: 800, height: 800)
        probe.enabled = true
        probe.canCreateAt = { _ in true }
        var created: [CGPoint] = []
        probe.onCreate = { created.append($0) }
        let expected = CGPoint(x: 140, y: 220)
        let location = probe.convert(expected, to: nil)
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: location,
            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseUp, location: location,
            modifierFlags: [], timestamp: 0.1, windowNumber: window.windowNumber,
            context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
        probe.rightMouseDown(with: down)
        probe.rightMouseUp(with: up)
        XCTAssertEqual(created.count, 1)
        XCTAssertEqual(try XCTUnwrap(created.first).x, expected.x, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(created.first).y, expected.y, accuracy: 0.01)
        probe.canCreateAt = { _ in false }
        probe.rightMouseDown(with: down)
        XCTAssertEqual(created.count, 1, "Existing content must not create another box")
    }

    @MainActor
    func testOrdinaryClickIsNotCreationButControlClickIs() throws {
        let plain = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let control = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
            modifierFlags: [.control], timestamp: 0, windowNumber: 0,
            context: nil, eventNumber: 2, clickCount: 1, pressure: 1))
        XCTAssertFalse(CanvasMiddleClick.Probe.isCreationClick(plain))
        XCTAssertTrue(CanvasMiddleClick.Probe.isCreationClick(control))
    }
}
