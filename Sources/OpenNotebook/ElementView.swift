import SwiftUI
import AppKit

@MainActor
struct ElementView: View {
    @Binding var element: PageElement
    let imageData: Data?
    let isSelected: Bool
    let isEditing: Bool
    let onDoneEditing: () -> Void
    let onSaveAttachment: () -> Void
    let textTools: TextTools
    let onMove: (CGSize) -> Void
    let onMoveEnd: () -> Void
    @KiyobumiState private var hovering = false
    let onRequestEditing: () -> Void
    var embedded = false
    var mediaLookup: (PageElement) -> Data? = { _ in nil }
    var saveEmbeddedAttachment: (PageElement) -> Void = { _ in }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if element.flowBlocks != nil {
                FlowBoxView(element: $element, editing: isEditing, tools: textTools,
                    onRequestEditing: onRequestEditing, onDoneEditing: onDoneEditing,
                    mediaLookup: mediaLookup, saveAttachment: saveEmbeddedAttachment)
            } else {
            switch element.content {
            case .text(let markdown):
                richEditor(RichTextCodec.fromMarkdown(markdown), legacy: true)
            case .richText(let value):
                richEditor(value, legacy: false)
            case .table(let rows):
                TableBlock(rows: rows, width: element.frame.width - 8, minimumHeight: 0,
                           savedWidths: element.tableColumnWidths, colors: element.tableCellColors ?? [:], onColor: { row, column, color in
                               var copy = element; var colors = copy.tableCellColors ?? [:]
                               colors["\(row):\(column)"] = color; copy.tableCellColors = colors; element = copy
                           }, editing: isEditing, embedded: embedded, onRequestEditing: onRequestEditing,
                           onChange: { updated in
                               var copy = element
                               if updated.first?.count != rows.first?.count {
                                   var widths = ElementLayout.columns(rows, width: copy.frame.width - 8, saved: copy.tableColumnWidths)
                                   let count = updated.first?.count ?? 1
                                   widths = Array(widths.prefix(count))
                                   while widths.count < count { widths.append(160) }
                                   copy.tableColumnWidths = widths.map { max(0.001, $0 - 48) }
                                   copy.frame.width = widths.reduce(0, +) + 8
                               }
                               copy.content = .table(rows: updated)
                               copy.trimCellColors()
                               copy.frame.height = ElementLayout.height(copy, editing: isEditing)
                               element = copy
                           },
                           onWidths: { widths in
                               var copy = element
                               copy.tableColumnWidths = widths.map { max(0.001, $0 - 48) }
                               copy.frame.width = widths.reduce(0, +) + 8
                               copy.frame.height = ElementLayout.height(copy, editing: isEditing)
                               element = copy
                           })
            case .image:
                if let data = imageData, let image = NSImage(data: data) {
                    Image(nsImage: image).resizable().scaledToFit()
                } else { Text("Image preview unavailable").foregroundStyle(.secondary) }
            case .attachment(_, let name):
                HStack {
                    Image(systemName: "paperclip")
                    VStack(alignment: .leading) {
                        Text(name).font(.callout).lineLimit(1)
                        Button("Save attachment…", action: onSaveAttachment).font(.caption)
                    }
                }.padding(6)
            case .ink: EmptyView()
            }
            }
        }
        .frame(width: max(0, element.frame.width - 8), height: max(0, element.frame.height - 8), alignment: .topLeading)
        .padding(4)
        .background(Color.clear)
        .overlay {
            if isSelected || hovering {
                Rectangle().strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) {
            if !embedded && (element.isText || isTable) {
                BoxMoveOutline(width: element.frame.width, height: element.frame.height,
                               onMove: onMove, onEnd: onMoveEnd)
            }
        }
        .onHover { hovering = $0 }
        .environment(\.openURL, OpenURLAction { url in
            ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") ? .systemAction : .discarded
        })
        .onExitCommand(perform: onDoneEditing)
        .onAppear { fitTable() }
        .onChange(of: isEditing) { _ in fitTable() }
        .onChange(of: element.frame.width) { _ in fitTable() }
    }
    private var isTable: Bool {
        if case .table = element.content { return true }; return false
    }
    private func fitTable() {
        guard isTable || element.flowBlocks != nil else { return }
        let height = ElementLayout.height(element, editing: isEditing)
        if abs(element.frame.height - height) > 0.5 { element.frame.height = height }
    }
    private func richEditor(_ value: RichTextContent, legacy: Bool) -> some View {
        RichTextEditor(elementID: element.id, value: value, width: element.frame.width, editing: isEditing,
                       selected: isSelected, tools: textTools, onChange: { updated, height in
            var copy = element
            // Measuring a legacy box must not rewrite its Markdown. Conversion
            // occurs when the user edits, formats or toggles a task marker.
            if !legacy || isEditing || updated != value { copy.content = .richText(updated) }
            if updated != value {
                copy.frame.width = RichTextCodec.growingWidth(updated, current: copy.frame.width)
            }
            let fittedHeight = copy.frame.width == element.frame.width ? height
                : RichTextCodec.height(updated, width: copy.frame.width)
            copy.frame.height = max(element.minimumHeight ?? 0, fittedHeight)
            if copy != element { element = copy }
        }, onHeightChange: { measured, height in
            let current: RichTextContent
            switch element.content {
            case .richText(let value): current = value
            case .text(let source): current = RichTextCodec.fromMarkdown(source)
            default: return
            }
            guard current == measured else { return }
            // A deferred measurement may only adjust bounds, never replace text.
            let fitted = max(element.minimumHeight ?? 0, height)
            if abs(element.frame.height - fitted) > 0.5 { element.frame.height = fitted }
        }, onRequestEditing: onRequestEditing, onDoneEditing: onDoneEditing)
    }
}

private func renderMarkdown(_ markdown: String) -> AttributedString {
    (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(markdown)
}

@MainActor
private struct TableBlock: View {
    let rows: [[String]]
    let width: Double
    let minimumHeight: Double
    let savedWidths: [Double]?
    let colors: [String: String]
    let onColor: (Int, Int, String?) -> Void
    let editing: Bool
    let embedded: Bool
    let onRequestEditing: () -> Void
    let onChange: ([[String]]) -> Void
    let onWidths: ([Double]) -> Void
    @KiyobumiState private var dragWidths: [Double]?
    @KiyobumiState private var requestedCell: String?
    @StateObject private var navigation = TableCellNavigation()
    private var widths: [Double] { ElementLayout.columns(rows, width: width, saved: savedWidths) }
    private var heights: [Double] { ElementLayout.rows(rows, columns: widths, minimum: minimumHeight) }
    private var columns: Int { rows.first?.count ?? 1 }
    var body: some View {
        let widths = self.widths
        let heights = self.heights
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { r in
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(rows[r].indices, id: \.self) { c in
                                cell(r, c)
                                    .padding(.horizontal, ElementLayout.cellHorizontalPadding)
                                    .padding(.vertical, ElementLayout.cellVerticalPadding)
                                    .frame(width: widths[c], height: heights[r], alignment: .topLeading)
                                    .background(Color(hex: colors["\(r):\(c)"] ?? "#FFFFFF").opacity(colors["\(r):\(c)"] == nil ? 0 : 1))
                                    .contextMenu { cellColourMenu(r, c) }
                                    .overlay(Rectangle().strokeBorder(Color.gray.opacity(0.8), lineWidth: 1).allowsHitTesting(false))
                                    .contentShape(Rectangle())
                                    .simultaneousGesture(TapGesture().onEnded {
                                        if !editing {
                                            requestedCell = "\(r):\(c)"
                                            DispatchQueue.main.async { onRequestEditing() }
                                        }
                                    })
                            }
                        }
                    }
                }
                if editing {
                    ForEach(0..<columns, id: \.self) { column in
                        ColumnResizeHandle(onChange: { translation in
                            if dragWidths == nil { dragWidths = widths }
                            guard let start = dragWidths else { return }
                            onWidths(ElementLayout.resizedColumn(start, index: column, translation: translation))
                        }, onEnd: { dragWidths = nil })
                            .frame(width: 8, height: heights.reduce(0, +))
                            .offset(x: widths.prefix(column + 1).reduce(0, +) - 4)
                            .help("Drag to resize this column independently")
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if editing && !embedded {
                HStack(spacing: 8) {
                    Button("+ Row") { var copy = rows; copy.append(Array(repeating: "", count: columns)); onChange(copy) }
                        .disabled(rows.count >= 1000 || (rows.count + 1) * columns > 20_000)
                    Button("+ Column") { onChange(rows.map { $0 + [""] }) }.disabled(columns >= 100 || rows.count * (columns + 1) > 20_000)
                    Button("− Row") { onChange(Array(rows.dropLast())) }.disabled(rows.count <= 1)
                    Button("− Column") { onChange(rows.map { Array($0.dropLast()) }) }.disabled(columns <= 1)
                }.font(.caption).padding(.horizontal, 8).frame(height: 32)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .cornerRadius(6).shadow(color: .black.opacity(0.15), radius: 2)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(y: -40)
            }
        }
        .onChange(of: editing) { active in if !active { requestedCell = nil } }
    }
    @ViewBuilder private func cellColourMenu(_ r: Int, _ c: Int) -> some View {
        Menu("Cell shading") {
            Button("None") { onColor(r, c, nil) }
            ForEach(CellShading.palette, id: \.0) { item in
                Button(item.0) { onColor(r, c, item.1) }
            }
        }
    }
    @ViewBuilder private func cell(_ r: Int, _ c: Int) -> some View {
        if editing {
            TableCellEditor(text: Binding(get: { rows[r][c] }, set: {
                var updated = rows; updated[r][c] = $0; onChange(updated)
            }), onColor: { onColor(r, c, $0) }, focusInitially: requestedCell == "\(r):\(c)", row: r, column: c, navigation: navigation)
        } else {
            Text(renderMarkdown(rows[r][c].isEmpty ? " " : rows[r][c]))
                .font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// A real text view gives Return its normal multiline editing semantics.
@MainActor
private struct TableCellEditor: NSViewRepresentable {
    @Binding var text: String
    let onColor: (String?) -> Void
    let focusInitially: Bool
    let row: Int
    let column: Int
    let navigation: TableCellNavigation
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextView {
        let view = ShadedCellTextView(frame: .zero)
        view.onColor = onColor
        view.isRichText = false
        view.drawsBackground = false
        view.font = .systemFont(ofSize: 14)
        view.textColor = .black
        view.appearance = NSAppearance(named: .aqua)
        view.insertionPointColor = .black
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.heightTracksTextView = false
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = false
        view.autoresizingMask = [.width, .height]
        view.allowsUndo = true
        view.isContinuousSpellCheckingEnabled = true
        view.string = text
        view.delegate = context.coordinator
        navigation.register(view, row: row, column: column)
        if focusInitially {
            DispatchQueue.main.async { [weak view] in
                guard let view, let window = view.window else { return }
                window.makeFirstResponder(view)
                view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
            }
        }
        return view
    }
    func updateNSView(_ view: NSTextView, context: Context) {
        (view as? ShadedCellTextView)?.onColor = onColor
        context.coordinator.parent = self
        if view.string != text && !view.hasMarkedText() {
            (view as? UndoSafeTextView)?.resetTextUndo()
            let selection = view.selectedRange()
            view.string = text
            let location = min(selection.location, (text as NSString).length)
            view.setSelectedRange(NSRange(location: location, length: 0))
        }
    }
    static func dismantleNSView(_ view: NSTextView, coordinator: Coordinator) {
        (view as? UndoSafeTextView)?.detachTextUndo()
        (view as? ShadedCellTextView)?.onColor = nil
        coordinator.parent.navigation.remove(view, row: coordinator.parent.row, column: coordinator.parent.column)
        view.delegate = nil
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TableCellEditor
        init(_ parent: TableCellEditor) { self.parent = parent }
        func undoManager(for view: NSTextView) -> UndoManager? {
            (view as? UndoSafeTextView)?.textUndoManager
        }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                textView.insertText("\n", replacementRange: textView.selectedRange())
                return true
            }
            guard !textView.hasMarkedText(), textView.selectedRange().length == 0 else { return false }
            let modifiers = NSApp.currentEvent?.modifierFlags.intersection([.shift, .command, .option, .control]) ?? []
            guard modifiers.isEmpty else { return false }
            let position = textView.selectedRange().location
            let length = (textView.string as NSString).length
            var rowDelta = 0
            var columnDelta = 0
            if commandSelector == #selector(NSResponder.moveLeft(_:)), position == 0 { columnDelta = -1 }
            else if commandSelector == #selector(NSResponder.moveRight(_:)), position == length { columnDelta = 1 }
            else if commandSelector == #selector(NSResponder.moveUp(_:)), TableCellNavigation.atVerticalEdge(textView, top: true) { rowDelta = -1 }
            else if commandSelector == #selector(NSResponder.moveDown(_:)), TableCellNavigation.atVerticalEdge(textView, top: false) { rowDelta = 1 }
            else { return false }
            return parent.navigation.move(from: textView, row: parent.row + rowDelta,
                column: parent.column + columnDelta, enterAtEnd: rowDelta < 0 || columnDelta < 0)
        }
    }
}

@MainActor
final class TableCellNavigation: ObservableObject {
    private final class WeakCell {
        weak var view: NSTextView?
        init(_ view: NSTextView) { self.view = view }
    }
    private var cells: [String: WeakCell] = [:]
    func register(_ view: NSTextView, row: Int, column: Int) {
        cells["\(row):\(column)"] = WeakCell(view)
    }
    func remove(_ view: NSTextView, row: Int, column: Int) {
        let key = "\(row):\(column)"
        if cells[key]?.view === view { cells.removeValue(forKey: key) }
    }
    func move(from source: NSTextView, row: Int, column: Int, enterAtEnd: Bool) -> Bool {
        guard let target = cells["\(row):\(column)"]?.view,
              let window = source.window, target.window === window,
              window.makeFirstResponder(target) else { return false }
        let position = enterAtEnd ? (target.string as NSString).length : 0
        target.setSelectedRange(NSRange(location: position, length: 0))
        target.scrollRangeToVisible(target.selectedRange())
        return true
    }
    // Use displayed line fragments so wrapped text keeps ordinary Up/Down
    // movement until the caret reaches the first or last visual line.
    static func atVerticalEdge(_ view: NSTextView, top: Bool) -> Bool {
        let length = (view.string as NSString).length
        guard length > 0 else { return true }
        guard let layout = view.layoutManager, let container = view.textContainer else { return false }
        layout.ensureLayout(for: container)
        guard layout.numberOfGlyphs > 0 else { return true }
        let position = min(view.selectedRange().location, length)
        let trailingLine = view.string.hasSuffix("\n") || view.string.hasSuffix("\r")
        let firstY = layout.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil).minY
        let lastY = trailingLine ? layout.extraLineFragmentRect.minY
            : layout.lineFragmentRect(forGlyphAt: layout.numberOfGlyphs - 1, effectiveRange: nil).minY
        let currentY: CGFloat
        if position == length && trailingLine { currentY = lastY }
        else {
            let glyph = layout.glyphIndexForCharacter(at: min(position, length - 1))
            currentY = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
        }
        return abs(currentY - (top ? firstY : lastY)) < 0.5
    }
}

// The same native view owns cursor tracking and dragging, so a SwiftUI text
// field or gesture layer cannot replace its cursor while over the divider.
@MainActor
private struct ColumnResizeHandle: NSViewRepresentable {
    let onChange: (Double) -> Void
    let onEnd: () -> Void
    func makeNSView(context: Context) -> HandleView { HandleView() }
    func updateNSView(_ view: HandleView, context: Context) {
        view.onChange = onChange; view.onEnd = onEnd
        view.window?.invalidateCursorRects(for: view)
    }
    final class HandleView: NSView {
        var onChange: ((Double) -> Void)?
        var onEnd: (() -> Void)?
        private var area: NSTrackingArea?
        private var startX: CGFloat?
        private var dragScale: CGFloat = 1
        override var acceptsFirstResponder: Bool { false }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            bounds.fill()
        }
        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let area { removeTrackingArea(area) }
            let next = NSTrackingArea(rect: .zero,
                options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate],
                owner: self, userInfo: nil)
            addTrackingArea(next); area = next
        }
        override func cursorUpdate(with event: NSEvent) { NSCursor.resizeLeftRight.set() }
        override func mouseEntered(with event: NSEvent) { NSCursor.resizeLeftRight.set() }
        override func mouseMoved(with event: NSEvent) { NSCursor.resizeLeftRight.set() }
        override func mouseExited(with event: NSEvent) {
            if startX == nil { NSCursor.arrow.set() }
        }
        override func mouseDown(with event: NSEvent) {
            startX = event.locationInWindow.x
            dragScale = max(0.01, abs(convert(bounds, to: nil).width) / max(1, bounds.width))
            NSCursor.resizeLeftRight.set()
            onChange?(0)
        }
        override func mouseDragged(with event: NSEvent) {
            guard let startX else { return }
            NSCursor.resizeLeftRight.set()
            onChange?(Double((event.locationInWindow.x - startX) / dragScale))
        }
        override func mouseUp(with event: NSEvent) {
            if let startX { onChange?(Double((event.locationInWindow.x - startX) / dragScale)) }
            startX = nil; onEnd?()
            if bounds.contains(convert(event.locationInWindow, from: nil)) { NSCursor.resizeLeftRight.set() }
            else { NSCursor.arrow.set() }
        }
    }
}

private struct BoxMoveOutline: View {
    let width: Double
    let height: Double
    let onMove: (CGSize) -> Void
    let onEnd: () -> Void
    var body: some View {
        ZStack(alignment: .topLeading) {
            edge(width: width, height: 4)
            edge(width: width, height: 4).offset(y: max(0, height - 4))
            edge(width: 4, height: max(0, height - 8)).offset(y: 4)
            edge(width: 4, height: max(0, height - 8)).offset(x: max(0, width - 4), y: 4)
        }.frame(width: width, height: height, alignment: .topLeading)
    }
    private func edge(width: Double, height: Double) -> some View {
        Color.clear.frame(width: width, height: height).contentShape(Rectangle())
            .help("Drag border to move box")
            .onHover { inside in if inside { NSCursor.openHand.set() } else { NSCursor.arrow.set() } }
            .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("page"))
                .onChanged { NSCursor.closedHand.set(); onMove($0.translation) }
                .onEnded { _ in NSCursor.openHand.set(); onEnd() })
    }
}
