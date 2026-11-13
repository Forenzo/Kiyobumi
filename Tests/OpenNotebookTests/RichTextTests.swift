import XCTest
import AppKit
@testable import OpenNotebook

final class RichTextTests: XCTestCase {
    @MainActor
    func testLongRichPasteUsesMeasuredFormattingAndRetainsFinalLine() throws {
        let text = String(repeating: "Pasted paragraph with formatting.\n", count: 100) + "FINAL LINE ✓\n"
        let style = TextFormat(fontSize: 18, bold: true)
        let value = RichTextContent(text: text, defaultFormat: style)
        let pasted = NSMutableAttributedString(attributedString: RichTextCodec.attributed(value))
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 40
        paragraph.minimumLineHeight = 60
        pasted.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: pasted.length))
        var result: RichTextContent?
        var height: Double = 0
        let editor = RichTextEditor(value: RichTextContent(text: ""), width: 320, editing: true, selected: true,
            tools: TextTools(), onChange: { result = $0; height = $1 },
            onHeightChange: { _, _ in }, onRequestEditing: {}, onDoneEditing: {})
        let coordinator = editor.makeCoordinator()
        let view = CanvasTextView(frame: .zero)
        view.textStorage?.setAttributedString(pasted)
        view.typingAttributes = RichTextCodec.attributes(style)
        view.setSelectedRange(NSRange(location: pasted.length, length: 0))
        coordinator.commit(view)
        let saved = try XCTUnwrap(result)
        XCTAssertEqual(saved.text, text)
        XCTAssertTrue(view.attributedString().isEqual(to: RichTextCodec.attributed(saved)))
        XCTAssertEqual(view.selectedRange().location, pasted.length)
        XCTAssertEqual(saved.runs.first?.format.fontSize, 18)
        XCTAssertEqual(saved.runs.first?.format.bold, true)
        XCTAssertGreaterThan(height, 2000)
        XCTAssertEqual(height, RichTextCodec.height(saved, width: 320), accuracy: 0.5)
    }

    @MainActor
    func testWholeBoxFormattingStaysInDisplayModeAndClearsNativeHighlight() {
        let tools = TextTools()
        let view = CanvasTextView(frame: .zero)
        let value = RichTextContent(text: "Existing writing")
        view.textStorage?.setAttributedString(RichTextCodec.attributed(value))
        view.typingAttributes = RichTextCodec.attributes(value.defaultFormat)
        view.setSelectedRange(NSRange(location: 0, length: view.attributedString().length))
        var editingRequests = 0
        view.requestEditing = { editingRequests += 1 }
        tools.select(view)
        tools.apply { $0.fontSize = 30 }
        XCTAssertEqual(editingRequests, 0)
        XCTAssertFalse(view.editorMode)
        XCTAssertEqual(view.selectedRange().length, 0)
        XCTAssertEqual((view.attributedString().attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 30)
        XCTAssertEqual(RichTextCodec.style(view.typingAttributes).fontSize, 30)
    }
    @MainActor
    func testFinishEditingClearsHighlightWithoutChangingTextOrFont() {
        let tools = TextTools()
        let value = RichTextContent(text: "Keep this text 😀", defaultFormat: TextFormat(fontSize: 24))
        let view = CanvasTextView(frame: .zero)
        view.textStorage?.setAttributedString(RichTextCodec.attributed(value))
        view.typingAttributes = RichTextCodec.attributes(value.defaultFormat)
        view.editorMode = true; view.isEditable = true; view.isSelectable = true
        view.setSelectedRange(NSRange(location: 0, length: view.attributedString().length))
        tools.select(view); tools.finish()
        XCTAssertEqual(view.selectedRange().length, 0)
        XCTAssertFalse(view.isEditable)
        XCTAssertFalse(view.isSelectable)
        XCTAssertEqual(view.string, value.text)
        XCTAssertEqual((view.attributedString().attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 24)
    }

    @MainActor
    func testPreselectedStyleSurvivesEmptyBoxSaveAndChecklistInsertion() throws {
        let tools = TextTools()
        tools.apply { $0.fontName = "Times New Roman"; $0.fontSize = 32; $0.bold = true; $0.colorHex = "#8B5CF6" }
        XCTAssertFalse(tools.hasText)
        let chosen = tools.format
        var document = NotebookDocument()
        let pageID = try XCTUnwrap(document.notebook.pages.keys.first)
        document.notebook.pages[pageID]?.elements = [PageElement(
            frame: Frame(x: 48, y: 48, width: 320, height: 100),
            content: .richText(RichTextContent(defaultFormat: chosen)))]
        let reopened = try NotebookDocument.read(document.package())
        guard case .richText(let empty)? = reopened.notebook.pages[pageID]?.elements.first?.content else {
            return XCTFail("Missing empty text box")
        }
        XCTAssertEqual(empty.defaultFormat, chosen)
        let checklist = RichTextCodec.fromMarkdown("- [ ] First\n- [ ] Second", defaultFormat: chosen)
        XCTAssertEqual(checklist.defaultFormat, chosen)
        XCTAssertEqual(checklist.text, "☐ First\n☐ Second")
        XCTAssertTrue(checklist.runs.allSatisfy { $0.format == chosen })
    }

    @MainActor
    func testPreparingNewBoxDoesNotFormatPreviouslySelectedText() {
        let tools = TextTools()
        let original = RichTextContent(text: "Existing writing")
        let view = CanvasTextView(frame: .zero)
        view.textStorage?.setAttributedString(RichTextCodec.attributed(original))
        view.typingAttributes = RichTextCodec.attributes(original.defaultFormat)
        tools.select(view)
        tools.prepareInsertion()
        tools.apply { $0.fontSize = 36; $0.italic = true }
        XCTAssertFalse(tools.hasText)
        XCTAssertEqual(tools.format.fontSize, 36)
        XCTAssertEqual(view.attributedString().string, original.text)
        XCTAssertEqual((view.attributedString().attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 14)
    }

    func testLongUnicodeTextAndFormattingSurvivePackageRoundTrip() throws {
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        let text = String(repeating: "清文 😀 café — a long wrapped paragraph\n", count: 120) + "LAST LINE — END\n\n"
        let style = TextFormat(fontName: "Helvetica", fontSize: 28, bold: true,
                               italic: false, underline: true, colorHex: "#145A8D", link: nil)
        let value = RichTextContent(text: text,
            runs: [TextSpan(location: 0, length: text.utf16.count, format: style)])
        document.notebook.pages[id]?.elements = [PageElement(
            frame: Frame(x: 24, y: 24, width: 240, height: 80), content: .richText(value))]
        let reopened = try NotebookDocument.read(document.package())
        XCTAssertEqual(reopened.notebook.pages[id]?.elements, document.notebook.pages[id]?.elements)
        XCTAssertTrue(reopened.notebook.pages[id]?.searchableText.hasSuffix("LAST LINE — END\n\n") == true)
    }

    func testInvalidRangeOrFontOrLinkCannotBeSilentlySaved() throws {
        for value in [
            RichTextContent(text: "abc", runs: [TextSpan(location: 2, length: 3, format: TextFormat())]),
            RichTextContent(text: "abc", defaultFormat: TextFormat(fontSize: 0)),
            RichTextContent(text: "abc", defaultFormat: TextFormat(link: "file:///private/notes"))
        ] {
            var document = NotebookDocument()
            let id = try XCTUnwrap(document.notebook.pages.keys.first)
            document.notebook.pages[id]?.elements = [PageElement(frame: .zero, content: .richText(value))]
            XCTAssertThrowsError(try document.package())
        }
    }

    @MainActor
    func testNativeChangePublishesEntireTailImmediatelyAndDropsOldMeasurement() {
        let old = RichTextContent(text: "before")
        var changes: [RichTextContent] = []
        var measurements = 0
        let editor = RichTextEditor(value: old, width: 200, editing: true, selected: true,
            tools: TextTools(), onChange: { changes.append($0); _ = $1 },
            onHeightChange: { _, _ in measurements += 1 },
            onRequestEditing: {}, onDoneEditing: {})
        let coordinator = editor.makeCoordinator()
        coordinator.lastValue = old
        let view = CanvasTextView(frame: .zero)
        let newest = RichTextContent(text: String(repeating: "new line 😀\n", count: 50) + "FINAL CHARACTER ✓")
        view.textStorage?.setAttributedString(RichTextCodec.attributed(newest))
        view.typingAttributes = RichTextCodec.attributes(newest.defaultFormat)
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: view))
        XCTAssertEqual(changes.last?.text, newest.text) // no run loop, focus change or Escape
        coordinator.publishHeight(view, value: old, width: 200, height: 60)
        XCTAssertEqual(measurements, 0)
        XCTAssertEqual(changes.count, 1)
        coordinator.publishHeight(view, value: try! XCTUnwrap(coordinator.lastValue), width: 100, height: 240)
        XCTAssertEqual(measurements, 0) // an older box width cannot clip the new layout
        coordinator.publishHeight(view, value: try! XCTUnwrap(coordinator.lastValue), width: 200, height: 120)
        XCTAssertEqual(measurements, 1)
        XCTAssertEqual(changes.count, 1) // layout never publishes an older text value
    }

    @MainActor
    func testNativeLayoutIncludesWrappedTextLargeFontsAndTrailingNewlines() {
        let text = String(repeating: "清文 and a long line 😀 ", count: 30)
        let small = RichTextContent(text: text)
        let large = RichTextContent(text: text, defaultFormat: TextFormat(fontSize: 36))
        XCTAssertGreaterThan(RichTextCodec.height(small, width: 160), RichTextCodec.height(small, width: 640))
        XCTAssertGreaterThan(RichTextCodec.height(large, width: 160), RichTextCodec.height(small, width: 160))
        XCTAssertGreaterThan(RichTextCodec.height(RichTextContent(text: "first\n\n\n"), width: 200),
                             RichTextCodec.height(RichTextContent(text: "first"), width: 200))
    }

    @MainActor
    func testUnknownFontNameAndStylesSurviveNativeFallback() {
        let format = TextFormat(fontName: "Kiyobumi Test Missing Font", fontSize: 24, bold: true,
                                italic: false, underline: true, colorHex: "#146A8D", link: "https://example.org")
        let text = "清文 😀"
        let value = RichTextContent(text: text,
            runs: [TextSpan(location: 0, length: text.utf16.count, format: format)], defaultFormat: format)
        let captured = RichTextCodec.value(RichTextCodec.attributed(value), defaultFormat: format)
        XCTAssertEqual(captured.text, text)
        XCTAssertEqual(captured.runs.first?.format.fontName, format.fontName)
        XCTAssertEqual(captured.runs.first?.format.fontSize, 24)
        XCTAssertEqual(captured.runs.first?.format.underline, true)
        XCTAssertEqual(captured.runs.first?.format.link, format.link)
    }

    func testListContinuation() {
        XCTAssertEqual(ListMarkers.prefix("☐ a task 😀\n"), "☐ ")
        XCTAssertEqual(ListMarkers.next("☑ "), "☐ ")
        XCTAssertEqual(ListMarkers.next("  9. "), "  10. ")
        XCTAssertEqual(ListMarkers.next("✓ "), "✓ ")
        XCTAssertNil(ListMarkers.prefix("normal text"))
    }

    @MainActor
    func testApplyingListsPreservesUnicodeAndNumbersParagraphs() {
        let view = CanvasTextView(frame: .zero)
        view.isEditable = true; view.editorMode = true
        view.textStorage?.setAttributedString(RichTextCodec.attributed(RichTextContent(text: "清文 😀\nsecond\nlast")))
        view.setSelectedRange(NSRange(location: 0, length: (view.string as NSString).length))
        view.applyList("number")
        XCTAssertEqual(view.string, "1. 清文 😀\n2. second\n3. last")
        view.setSelectedRange(NSRange(location: 0, length: (view.string as NSString).length))
        view.applyList("☐ ")
        XCTAssertEqual(view.string, "☐ 清文 😀\n☐ second\n☐ last")
    }

    func testImportedInkOpacityAndSinglePointSurviveSave() throws {
        var document = NotebookDocument()
        let id = try XCTUnwrap(document.notebook.pages.keys.first)
        let stroke = Stroke(kind: .highlighter, colorHex: "#F2DC3C", width: 8,
                            points: [StrokePoint(x: 0, y: 0)], opacity: 0.4)
        document.notebook.pages[id]?.elements = [PageElement(frame: .zero, content: .ink(strokes: [stroke]))]
        let reopened = try NotebookDocument.read(document.package())
        XCTAssertEqual(reopened.notebook.pages[id]?.elements, document.notebook.pages[id]?.elements)
    }
}
