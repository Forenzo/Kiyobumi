import XCTest
import Foundation
@testable import OpenNotebook

final class StartupNotebookTests: XCTestCase {
    @MainActor
    func testLastUsedIsIndependentOfPinnedChoiceAndModePersists() throws {
        let suite = "Kiyobumi.StartupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let first = root.appendingPathComponent("First.onbook")
        let second = root.appendingPathComponent("Second.onbook")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let pinned = StartupNotebookPreferences(defaults: defaults)
        let recent = StartupNotebookPreferences(defaults: defaults, keyPrefix: "Kiyobumi.lastNotebook")
        XCTAssertTrue(pinned.reopenLastUsed)
        try pinned.choose(first)
        recent.rememberIfChanged(first)
        recent.rememberIfChanged(second)
        XCTAssertEqual(pinned.displayPath, first.path)
        let restored = StartupNotebookPreferences(defaults: defaults, keyPrefix: "Kiyobumi.lastNotebook")
        let access = try XCTUnwrap(restored.resolve())
        defer { access.release() }
        XCTAssertEqual(access.url.resolvingSymlinksInPath(), second.resolvingSymlinksInPath())
        pinned.reopenLastUsed = false
        XCTAssertFalse(StartupNotebookPreferences(defaults: defaults).reopenLastUsed)
        XCTAssertEqual(StartupNotebookPreferences(defaults: defaults).displayPath, first.path)
        recent.rememberIfChanged(root.appendingPathComponent("Missing.onbook"))
        XCTAssertEqual(recent.displayPath, second.path)
    }
    @MainActor
    func testSelectionPersistsAcrossPreferenceInstancesAndClearRemovesOnlyPreference() throws {
        let suite = "Kiyobumi.StartupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let notebook = root.appendingPathComponent("Startup.onbook")
        try FileManager.default.createDirectory(at: notebook, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try StartupNotebookPreferences(defaults: defaults).choose(notebook)
        let reopened = StartupNotebookPreferences(defaults: defaults)
        XCTAssertTrue(reopened.hasStartupNotebook)
        XCTAssertEqual(reopened.displayPath, notebook.path)
        let access = try XCTUnwrap(reopened.resolve())
        defer { access.release() }
        XCTAssertEqual(access.url.resolvingSymlinksInPath(), notebook.resolvingSymlinksInPath())
        reopened.clear()
        XCTAssertFalse(StartupNotebookPreferences(defaults: defaults).hasStartupNotebook)
        XCTAssertTrue(FileManager.default.fileExists(atPath: notebook.path))
    }

    @MainActor
    func testInvalidReplacementPreservesExistingSelection() throws {
        let suite = "Kiyobumi.StartupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let notebook = root.appendingPathComponent("Startup.onbook")
        try FileManager.default.createDirectory(at: notebook, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let preferences = StartupNotebookPreferences(defaults: defaults)
        try preferences.choose(notebook)
        let bookmark = preferences.bookmark
        let wrongType = root.appendingPathComponent("Section.one")
        try Data("OneNote source".utf8).write(to: wrongType)
        XCTAssertThrowsError(try preferences.choose(wrongType))
        XCTAssertEqual(preferences.bookmark, bookmark)
        XCTAssertEqual(preferences.displayPath, notebook.path)
        XCTAssertEqual(StartupNotebookPreferences(defaults: defaults).bookmark, bookmark)
    }

    @MainActor
    func testMissingNotebookFailsWithoutSilentlyClearingPreference() throws {
        let suite = "Kiyobumi.StartupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let notebook = root.appendingPathComponent("Startup.onbook")
        try FileManager.default.createDirectory(at: notebook, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let preferences = StartupNotebookPreferences(defaults: defaults)
        try preferences.choose(notebook)
        let bookmark = preferences.bookmark
        try FileManager.default.removeItem(at: notebook)
        XCTAssertThrowsError(try preferences.resolve())
        XCTAssertEqual(preferences.bookmark, bookmark)
        XCTAssertTrue(preferences.hasStartupNotebook)
    }
}
