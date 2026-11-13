import XCTest
import AppKit
import UniformTypeIdentifiers
@testable import OpenNotebook

// These tests cover the save policy without writing into a user's documents.
// The actual DocumentGroup close/quit flow is a separate Mac acceptance check.
final class NotebookAutosaveTests: XCTestCase {
    @MainActor
    func testUntitledNotebookRequiresFirstSaveLocation() {
        let document = SaveSpy()
        let autosave = NotebookAutosave()
        autosave.monitor(document)
        defer { autosave.stop() }
        autosave.saveIfNeeded()
        XCTAssertEqual(document.autosaveRequests, 0)
        XCTAssertEqual(document.saveRequests, 0)
        XCTAssertTrue(autosave.status.contains("Choose a location"))
    }

    @MainActor
    func testDirtySavedNotebookRequestsInPlaceAutosave() {
        let document = SaveSpy()
        document.fileURL = URL(fileURLWithPath: "/tmp/opennotebook-test.onbook")
        let autosave = NotebookAutosave()
        autosave.monitor(document)
        defer { autosave.stop() }
        autosave.saveIfNeeded()
        autosave.saveIfNeeded() // no overlapping requests while writing
        XCTAssertEqual(document.autosaveRequests, 1)
        XCTAssertEqual(document.saveRequests, 0)
        XCTAssertFalse(document.implicitCancellation)
        XCTAssertEqual(autosave.status, "Saving…")
    }

    @MainActor
    func testCleanNotebookDoesNotRewrite() {
        let document = SaveSpy()
        document.fileURL = URL(fileURLWithPath: "/tmp/opennotebook-test.onbook")
        document.dirty = false
        let autosave = NotebookAutosave()
        autosave.monitor(document)
        defer { autosave.stop() }
        autosave.saveIfNeeded()
        XCTAssertEqual(document.autosaveRequests, 0)
        XCTAssertEqual(autosave.status, "Saved · Autosave on")
    }

    @MainActor
    func testNonAutosavingHostUsesCoordinatedSave() {
        let document = SaveWithoutAutosaveSpy()
        document.fileURL = URL(fileURLWithPath: "/tmp/opennotebook-test.onbook")
        let autosave = NotebookAutosave()
        autosave.monitor(document)
        defer { autosave.stop() }
        autosave.saveIfNeeded()
        XCTAssertEqual(document.autosaveRequests, 0)
        XCTAssertEqual(document.saveRequests, 1)
        XCTAssertEqual(document.requestedURL, document.fileURL)
        XCTAssertEqual(document.requestedOperation, .saveOperation)
    }

    @MainActor
    func testFailedSaveStaysVisibleAndIsNotImmediatelyRetried() async {
        let document = SaveSpy()
        document.fileURL = URL(fileURLWithPath: "/tmp/opennotebook-test.onbook")
        let autosave = NotebookAutosave()
        autosave.monitor(document)
        defer { autosave.stop() }
        autosave.saveIfNeeded()
        document.finish?(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError))
        // The production callback publishes on the main queue. Queue this check
        // behind it, rather than using a timing-dependent sleep.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                XCTAssertNotNil(autosave.errorMessage)
                XCTAssertTrue(autosave.status.hasPrefix("Save failed"))
                autosave.saveIfNeeded()
                XCTAssertEqual(document.autosaveRequests, 1)
                continuation.resume()
            }
        }
    }
}

private class SaveSpy: NSDocument {
    override class var autosavesInPlace: Bool { true }
    var dirty = true
    override var hasUnautosavedChanges: Bool { dirty }
    var autosaveRequests = 0
    var saveRequests = 0
    var implicitCancellation = true
    var requestedURL: URL?
    var requestedOperation: NSDocument.SaveOperationType?
    var finish: ((Error?) -> Void)?

    override func autosave(withImplicitCancellability value: Bool,
                           completionHandler: @escaping (Error?) -> Void) {
        autosaveRequests += 1
        implicitCancellation = value
        finish = completionHandler
    }
    override func save(to url: URL, ofType typeName: String,
                       for operation: NSDocument.SaveOperationType,
                       completionHandler: @escaping (Error?) -> Void) {
        saveRequests += 1
        requestedURL = url
        requestedOperation = operation
        finish = completionHandler
    }
}

private final class SaveWithoutAutosaveSpy: SaveSpy {
    override class var autosavesInPlace: Bool { false }
}
