import SwiftUI
import AppKit

@MainActor
enum RichTextCodec {
    private static let requestedFont = NSAttributedString.Key("KiyobumiFontName")

    static func attributes(_ style: TextFormat) -> [NSAttributedString.Key: Any] {
        var font = NSFont(name: style.fontName, size: CGFloat(style.fontSize))
            ?? NSFontManager.shared.font(withFamily: style.fontName, traits: [], weight: 5, size: CGFloat(style.fontSize))
            ?? NSFont.systemFont(ofSize: CGFloat(style.fontSize))
        if style.bold { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
        if style.italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
        let color = NSColor(Color(hex: style.colorHex))
        var result: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, requestedFont: style.fontName,
            .underlineStyle: style.underline ? NSUnderlineStyle.single.rawValue : 0
        ]
        if let link = style.link, let url = URL(string: link), safeLink(url) { result[.link] = url }
        if let hex = style.highlightHex { result[.backgroundColor] = NSColor(Color(hex: hex)) }
        return result
    }

    static func safeLink(_ url: URL) -> Bool {
        ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "")
    }

    static func style(_ attributes: [NSAttributedString.Key: Any]) -> TextFormat {
        var result = TextFormat()
        if let font = attributes[.font] as? NSFont {
            result.fontName = attributes[requestedFont] as? String ?? font.familyName ?? font.fontName
            result.fontSize = min(288, max(6, Double(font.pointSize)))
            let traits = NSFontManager.shared.traits(of: font)
            result.bold = traits.contains(.boldFontMask)
            result.italic = traits.contains(.italicFontMask)
        }
        result.underline = (attributes[.underlineStyle] as? Int ?? 0) != 0
        if let color = (attributes[.foregroundColor] as? NSColor)?.usingColorSpace(.deviceRGB) {
            result.colorHex = String(format: "#%02X%02X%02X", Int((color.redComponent * 255).rounded()),
                                     Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
        }
        if let url = attributes[.link] as? URL, safeLink(url) { result.link = url.absoluteString }
        if let color = (attributes[.backgroundColor] as? NSColor)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0 {
            result.highlightHex = String(format: "#%02X%02X%02X", Int((color.redComponent * 255).rounded()),
                Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
        }
        return result
    }

    static func attributed(_ value: RichTextContent) -> NSAttributedString {
        let result = NSMutableAttributedString(string: value.text, attributes: attributes(value.defaultFormat))
        for run in value.runs where run.location >= 0 && run.length > 0 &&
            run.location <= result.length && run.length <= result.length - run.location {
            result.setAttributes(attributes(run.format), range: NSRange(location: run.location, length: run.length))
        }
        return result
    }

    static func value(_ attributed: NSAttributedString, defaultFormat: TextFormat) -> RichTextContent {
        var runs: [TextSpan] = []
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attributes, range, _ in
            let format = style(attributes)
            if let last = runs.last, last.format == format, last.location + last.length == range.location {
                runs[runs.count - 1].length += range.length
            } else { runs.append(TextSpan(location: range.location, length: range.length, format: format)) }
        }
        return RichTextContent(text: attributed.string, runs: runs, defaultFormat: defaultFormat)
    }

    static func fromMarkdown(_ source: String, defaultFormat: TextFormat = TextFormat()) -> RichTextContent {
        let normalized = source.components(separatedBy: "\n").map { line -> String in
            if line.hasPrefix("- [ ] ") { return "☐ " + String(line.dropFirst(6)) }
            if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") { return "☑ " + String(line.dropFirst(6)) }
            if line.hasPrefix("- ") { return "• " + String(line.dropFirst(2)) }
            return line
        }.joined(separator: "\n")
        guard let parsed = try? AttributedString(markdown: normalized,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else {
            return RichTextContent(text: source, defaultFormat: defaultFormat)
        }
        var runs: [TextSpan] = []
        for run in parsed.runs {
            var format = defaultFormat
            format.bold = defaultFormat.bold || (run.inlinePresentationIntent?.contains(.stronglyEmphasized) ?? false)
            format.italic = defaultFormat.italic || (run.inlinePresentationIntent?.contains(.emphasized) ?? false)
            if let url = run.link, safeLink(url) { format.link = url.absoluteString }
            let location = String(parsed.characters[..<run.range.lowerBound]).utf16.count
            let length = String(parsed.characters[run.range]).utf16.count
            if length > 0 { runs.append(TextSpan(location: location, length: length, format: format)) }
        }
        return RichTextContent(text: String(parsed.characters), runs: runs, defaultFormat: defaultFormat)
    }

    // Measure hard lines with ample horizontal space. Keep a little caret
    // room so the last typed character does not trigger a soft wrap.
    static func growingWidth(_ value: RichTextContent, current: Double) -> Double {
        let storage = NSTextStorage(attributedString: attributed(value))
        let manager = NSLayoutManager()
        let container = NSTextContainer(containerSize: NSSize(width: 99_976, height: 1_000_000))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        let required = Double(ceil(manager.usedRect(for: container).maxX)) + 24
        return min(100_000, max(current, max(80, required)))
    }

    // The same TextKit layout is used in editing, display and persisted bounds.
    // Include the extra line fragment so a trailing newline has visible space.
    static func height(_ value: RichTextContent, width: Double) -> Double {
        let storage = NSTextStorage(attributedString: attributed(value))
        let manager = NSLayoutManager()
        let container = NSTextContainer(containerSize: NSSize(width: max(1, width - 16), height: 1_000_000))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        let bottom = max(manager.usedRect(for: container).maxY, manager.extraLineFragmentRect.maxY)
        let minimum: Double = max(48.0, value.defaultFormat.fontSize * 1.3 + 24.0)
        return max(minimum, Double(ceil(bottom)) + 24.0)
    }
}

@MainActor
final class TextTools: ObservableObject {
    @Published private(set) var format = TextFormat()
    @Published private(set) var hasText = false
    private weak var activeView: CanvasTextView?
    var insertionAnchor: (UUID, Int)? {
        guard let view = activeView, view.editorMode, let id = view.elementID else { return nil }
        view.flushModel?()
        return (id, view.selectedRange().location)
    }
    weak var canvasView: NSView?
    private var monitor: Any?

    func select(_ view: CanvasTextView) {
        activeView = view
        if !hasText { hasText = true }
        let range = view.selectedRange()
        let attributes = !(view.editorMode && range.length == 0) && range.location < view.attributedString().length
            ? view.attributedString().attributes(at: range.location, effectiveRange: nil) : view.typingAttributes
        let next = RichTextCodec.style(attributes)
        if format != next { format = next }
    }

    func deselect(_ view: CanvasTextView) {
        guard activeView === view else { return }
        activeView = nil
        if hasText { hasText = false }
    }

    func apply(_ change: (inout TextFormat) -> Void) {
        guard let view = activeView, let storage = view.textStorage else {
            // No box yet: choose the style used by the next box instead.
            var next = format
            change(&next)
            if format != next { format = next }
            return
        }
        let wasEditing = view.editorMode
        let range = wasEditing ? view.selectedRange() : NSRange(location: 0, length: storage.length)
        // Formatting a selected box in display mode must not create a native
        // text selection or enter editing. Active range editing keeps its range.
        if wasEditing { view.requestEditing?() }
        if range.length == 0 {
            var next = RichTextCodec.style(view.typingAttributes)
            change(&next)
            view.typingAttributes = RichTextCodec.attributes(next)
        } else {
            var changes: [(NSRange, TextFormat)] = []
            storage.enumerateAttributes(in: range) { attributes, subrange, _ in
                var next = RichTextCodec.style(attributes); change(&next); changes.append((subrange, next))
            }
            storage.beginEditing()
            for (subrange, style) in changes { storage.setAttributes(RichTextCodec.attributes(style), range: subrange) }
            storage.endEditing()
            if !wasEditing {
                var next = RichTextCodec.style(view.typingAttributes)
                change(&next)
                view.typingAttributes = RichTextCodec.attributes(next)
            }
            view.didChangeText()
        }
        view.flushModel?()
        if !wasEditing { view.endEditingAppearance() }
        select(view)
    }

    func list(_ marker: String) {
        guard let view = activeView else { return }
        if !view.editorMode { view.setSelectedRange(NSRange(location: 0, length: (view.string as NSString).length)) }
        view.requestEditing?()
        view.editorMode = true; view.isEditable = true
        view.applyList(marker)
        select(view)
    }

    func startMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, let view = self.activeView, view.editorMode,
                  let canvas = self.canvasView, event.window === view.window,
                  canvas.bounds.contains(canvas.convert(event.locationInWindow, from: nil)),
                  !view.bounds.contains(view.convert(event.locationInWindow, from: nil)) else { return event }
            view.flushModel?()
            view.window?.makeFirstResponder(nil)
            view.finishEditing?()
            return event
        }
    }

    func stopMonitoring() {
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        canvasView = nil
    }

    func finish() {
        activeView?.flushModel?()
        if let view = activeView, view.window?.firstResponder === view {
            view.window?.makeFirstResponder(nil)
        }
        activeView?.endEditingAppearance()
    }

    func prepareInsertion() {
        // Keep the chosen style while disconnecting the previously selected box.
        activeView = nil
        if hasText { hasText = false }
    }
}

@MainActor
struct TextCanvasProbe: NSViewRepresentable {
    let tools: TextTools
    func makeNSView(context: Context) -> Probe {
        let view = Probe(); view.tools = tools; tools.canvasView = view; tools.startMonitoring(); return view
    }
    func updateNSView(_ view: Probe, context: Context) { tools.canvasView = view }
    static func dismantleNSView(_ view: Probe, coordinator: ()) { view.tools?.stopMonitoring() }
    final class Probe: NSView { weak var tools: TextTools? }
}

@MainActor
struct RichTextEditor: NSViewRepresentable {
    var elementID: UUID? = nil
    let value: RichTextContent
    let width: Double
    let editing: Bool
    let selected: Bool
    let tools: TextTools
    let onChange: (RichTextContent, Double) -> Void
    let onHeightChange: (RichTextContent, Double) -> Void
    let onRequestEditing: () -> Void
    let onDoneEditing: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> CanvasTextView {
        let container = NSTextContainer(containerSize: NSSize(width: max(1, width - 16), height: 1_000_000))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        let manager = NSLayoutManager(); manager.addTextContainer(container)
        let storage = NSTextStorage(); storage.addLayoutManager(manager)
        let view = CanvasTextView(frame: .zero, textContainer: container)
        view.delegate = context.coordinator
        // The paper remains in its document colors, independent of app chrome.
        view.appearance = NSAppearance(named: .aqua)
        view.insertionPointColor = .black
        view.drawsBackground = false
        view.isRichText = true
        view.importsGraphics = false
        view.allowsUndo = true
        view.isContinuousSpellCheckingEnabled = true
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = false
        view.textContainerInset = NSSize(width: 4, height: 4)
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.flushModel = { [weak view, weak coordinator = context.coordinator] in
            if let view = view { coordinator?.commit(view) }
        }
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: CanvasTextView, context: Context) {
        view.elementID = elementID
        context.coordinator.parent = self
        view.requestEditing = onRequestEditing
        view.finishEditing = onDoneEditing
        view.textContainer?.containerSize = NSSize(width: max(1, width - 16), height: 1_000_000)
        if context.coordinator.lastValue != value {
            view.resetTextUndo()
            let selection = view.selectedRange()
            view.textStorage?.setAttributedString(RichTextCodec.attributed(value))
            view.typingAttributes = RichTextCodec.attributes(value.defaultFormat)
            let start = min(selection.location, view.attributedString().length)
            view.setSelectedRange(NSRange(location: start, length: min(selection.length, view.attributedString().length - start)))
            context.coordinator.lastValue = value
        }
        let beganEditing = editing && !view.editorMode
        view.editorMode = editing
        view.isEditable = editing
        view.isSelectable = editing
        if !editing { view.endEditingAppearance() }
        if selected {
            DispatchQueue.main.async { tools.select(view) }
        } else {
            DispatchQueue.main.async { tools.deselect(view) }
        }
        if beganEditing {
            DispatchQueue.main.async { if view.editorMode { view.window?.makeFirstResponder(view) } }
        }
        let height = RichTextCodec.height(value, width: width)
        if abs(height - context.coordinator.lastHeight) > 0.5 {
            context.coordinator.lastHeight = height
            DispatchQueue.main.async {
                context.coordinator.publishHeight(view, value: value, width: width, height: height)
            }
        }
    }

    static func dismantleNSView(_ view: CanvasTextView, coordinator: Coordinator) {
        // Every edit is already published synchronously. Never publish an old
        // detached view over a newer page snapshot during teardown.
        view.detachTextUndo()
        view.flushModel = nil; view.requestEditing = nil; view.finishEditing = nil
        view.delegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var lastValue: RichTextContent?
        var lastHeight: Double = -1
        private var committing = false
        init(_ parent: RichTextEditor) { self.parent = parent }

        func commit(_ view: CanvasTextView) {
            guard !committing, !view.hasMarkedText() else { return }
            committing = true
            defer { committing = false }
            let value = RichTextCodec.value(view.attributedString(), defaultFormat: RichTextCodec.style(view.typingAttributes))
            // Clipboard HTML/RTF can carry paragraph spacing, line heights and
            // text-table attributes which our document format does not store.
            // Render the same supported attributes that we measure and save;
            // otherwise pasted text can extend below its calculated frame.
            let normalized = RichTextCodec.attributed(value)
            if !view.attributedString().isEqual(to: normalized), let storage = view.textStorage {
                let selection = view.selectedRanges
                let typing = RichTextCodec.attributes(RichTextCodec.style(view.typingAttributes))
                storage.beginEditing()
                normalized.enumerateAttributes(in: NSRange(location: 0, length: normalized.length)) { attributes, range, _ in
                    storage.setAttributes(attributes, range: range)
                }
                storage.endEditing()
                view.selectedRanges = selection
                view.typingAttributes = typing
            }
            let height = RichTextCodec.height(value, width: parent.width)
            if value != lastValue || abs(height - lastHeight) > 0.5 {
                lastValue = value; lastHeight = height
                parent.onChange(value, height)
            }
        }
        func publishHeight(_ view: CanvasTextView, value: RichTextContent, width: Double, height: Double) {
            // Drop obsolete results after typing, undo or a box-width change.
            guard lastValue == value, parent.width == width else { return }
            parent.onHeightChange(value, height)
        }
        func undoManager(for view: NSTextView) -> UndoManager? {
            (view as? UndoSafeTextView)?.textUndoManager
        }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? CanvasTextView else { return }
            commit(view)
            parent.tools.select(view)
        }
        func textViewDidChangeSelection(_ notification: Notification) {
            if let view = notification.object as? CanvasTextView, parent.selected, view.editorMode { parent.tools.select(view) }
        }
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL, RichTextCodec.safeLink(url) { NSWorkspace.shared.open(url) }
            return true
        }
    }
}

// No scroll view or opaque background inside a note box. Its entire content
// remains visible; the surrounding page scroll view handles long notes.
final class CanvasTextView: UndoSafeTextView {
    var elementID: UUID?
    var editorMode = false
    var flushModel: (() -> Void)?
    var requestEditing: (() -> Void)?
    var finishEditing: (() -> Void)?

    func endEditingAppearance() {
        editorMode = false; isEditable = false; isSelectable = false
        let range = selectedRange()
        let length = (string as NSString).length
        let start = min(range.location, length)
        let caret = start + min(range.length, length - start)
        if range.length > 0 { setSelectedRange(NSRange(location: caret, length: 0)) }
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        if hasMarkedText() { unmarkText() }
        flushModel?()
        return super.resignFirstResponder()
    }

    override func insertNewline(_ sender: Any?) {
        let range = selectedRange()
        let string = self.string as NSString
        let lineRange = string.lineRange(for: NSRange(location: range.location, length: 0))
        let line = string.substring(with: lineRange)
        guard let prefix = ListMarkers.prefix(line) else { super.insertNewline(sender); return }
        if line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            insertText("", replacementRange: NSRange(location: lineRange.location, length: prefix.utf16.count))
        } else {
            insertText("\n" + ListMarkers.next(prefix), replacementRange: range)
        }
    }

    func applyList(_ marker: String) {
        let selection = editorMode ? selectedRange() : NSRange(location: 0, length: (string as NSString).length)
        let source = string as NSString
        // A selection ending at the next paragraph's start excludes that paragraph.
        let last = selection.length > 0 ? selection.location + selection.length - 1 : selection.location
        let firstLine = source.lineRange(for: NSRange(location: selection.location, length: 0))
        let lastLine = source.lineRange(for: NSRange(location: last, length: 0))
        var starts: [Int] = []
        var location = firstLine.location
        repeat {
            starts.append(location)
            let line = source.lineRange(for: NSRange(location: location, length: 0))
            if line.length == 0 { break }
            location = line.location + line.length
        } while location <= lastLine.location
        for (index, start) in starts.enumerated().reversed() {
            let lineRange = source.lineRange(for: NSRange(location: start, length: 0))
            let oldPrefix = ListMarkers.prefix(source.substring(with: lineRange)) ?? ""
            let replacement = marker == "number" ? "\(index + 1). " : marker
            insertText(replacement, replacementRange: NSRange(location: start, length: oldPrefix.utf16.count))
        }
        flushModel?()
    }

    override func mouseDown(with event: NSEvent) {
        if !editorMode, let manager = layoutManager, let container = textContainer {
            let point = convert(event.locationInWindow, from: nil)
            let local = NSPoint(x: point.x - textContainerInset.width, y: point.y - textContainerInset.height)
            let glyph = manager.glyphIndex(for: local, in: container)
            if glyph < manager.numberOfGlyphs {
                let rect = manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
                let index = manager.characterIndexForGlyph(at: glyph)
                let text = string as NSString
                let line = text.lineRange(for: NSRange(location: index, length: 0))
                if rect.contains(local), index < text.length,
                   let url = textStorage?.attribute(.link, at: index, effectiveRange: nil) as? URL,
                   RichTextCodec.safeLink(url) { NSWorkspace.shared.open(url); return }
                if rect.insetBy(dx: -3, dy: -3).contains(local), index == line.location,
                   index < text.length, ["☐", "☑"].contains(text.substring(with: NSRange(location: index, length: 1))) {
                    let marker = text.substring(with: NSRange(location: index, length: 1)) == "☐" ? "☑" : "☐"
                    textStorage?.replaceCharacters(in: NSRange(location: index, length: 1), with: marker)
                    didChangeText(); flushModel?(); return
                }
            }
        }
        if !editorMode {
            requestEditing?()
            editorMode = true; isEditable = true; isSelectable = true
            window?.makeFirstResponder(self)
        }
        // Pass the original event to TextKit: the first click places the caret
        // at the pointer and a first-click drag selects text normally.
        super.mouseDown(with: event)
    }
}

enum ListMarkers {
    static func prefix(_ line: String) -> String? {
        guard let range = line.range(of: #"^[\t ]*(?:[•☐☑✓✕] |[0-9]+\. )"#, options: .regularExpression) else { return nil }
        return String(line[range])
    }
    static func next(_ prefix: String) -> String {
        if let range = prefix.range(of: #"[0-9]+"#, options: .regularExpression), let number = Int(prefix[range]), number < Int.max {
            return prefix.replacingCharacters(in: range, with: String(number + 1))
        }
        return prefix.replacingOccurrences(of: "☑", with: "☐")
    }
}
