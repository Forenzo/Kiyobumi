import XCTest
import AppKit
@testable import OpenNotebook

final class TextUndoTests: XCTestCase {
    @MainActor
    func testNativeTypingUndoRedoAndIsolation() {
        _ = NSApplication.shared
        for view in [CanvasTextView(frame: .zero), ShadedCellTextView(frame: .zero)] as [UndoSafeTextView] {
            view.isEditable = true
            view.allowsUndo = true
            let manager = view.textUndoManager
            manager.groupsByEvent = false
            manager.beginUndoGrouping()
            view.insertText("Hello", replacementRange: NSRange(location: 0, length: 0))
            view.breakUndoCoalescing()
            manager.endUndoGrouping()
            XCTAssertEqual(view.string, "Hello")
            XCTAssertTrue(manager.canUndo)
            manager.undo()
            XCTAssertEqual(view.string, "")
            manager.redo()
            XCTAssertEqual(view.string, "Hello")
            view.resetTextUndo()
            XCTAssertFalse(manager.canUndo)
            XCTAssertFalse(manager.canRedo)
        }
    }

    @MainActor
    func testDetachedEditorCannotLeaveUndoTargetsInWindow() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let survivor = CanvasTextView(frame: .zero)
        var removed: ShadedCellTextView? = ShadedCellTextView(frame: .zero)
        weak var weakRemoved = removed
        let manager = removed!.textUndoManager
        XCTAssertFalse(manager === survivor.textUndoManager)
        window.contentView!.addSubview(removed!)
        XCTAssertFalse(removed!.undoManager === window.undoManager)
        removed!.allowsUndo = true
        manager.groupsByEvent = false
        manager.beginUndoGrouping()
        removed!.insertText("Cell", replacementRange: NSRange(location: 0, length: 0))
        removed!.breakUndoCoalescing()
        manager.endUndoGrouping()
        removed!.detachTextUndo()
        removed!.removeFromSuperview()
        removed = nil
        XCTAssertNil(weakRemoved)
        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        manager.undo() // Must be harmless even if the old manager is retained.
    }
}
