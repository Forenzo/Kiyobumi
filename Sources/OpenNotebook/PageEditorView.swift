import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
struct PageEditorView: View {
    @Binding var page: Page
    @Binding var media: [String: StoredFile]
    var subheader: Binding<String> = .constant("")
    var sectionTabs: SectionTabStrip? = nil
    var onImport: () -> Void = {}
    var importBusy = false
    var onTemplate: (Page, [String: StoredFile], String) -> Void = { _, _, _ in }
    @KiyobumiState private var showingPaperDesign = false
    @KiyobumiState private var showingTemplates = false
    var sectionPages: () -> [PrintPageSnapshot] = { [] }
    @KiyobumiState private var resizeStart: Frame?
    @KiyobumiState private var borderMoveStart: Frame?
    @AppStorage("textHighlightColor") private var highlightColor = "#FFF176"
    @AppStorage("automaticallyPushContentDown") private var automaticallyPushContentDown = true
    @KiyobumiState private var insertionPanel: NSOpenPanel?
    @KiyobumiState private var printoutBusy = false
    @KiyobumiState private var printoutTask: Task<Void, Never>?
    @KiyobumiState private var printoutProgress = ""
    @KiyobumiState private var printoutCount: Int?
    @KiyobumiState private var printoutRevealID: UUID?
    @KiyobumiState private var paperSize = PrintPaper.a4
    @KiyobumiState private var printingBusy = false
    @KiyobumiState private var printingTask: Task<Void, Never>?
    @KiyobumiState private var printingProgress = ""
    @EnvironmentObject private var autosave: NotebookAutosave
    @StateObject private var textTools = TextTools()
    @KiyobumiState private var exportingAttachment = false
    @KiyobumiState private var exportDocument = AttachmentDocument()
    @KiyobumiState private var exportName = "attachment.bin"
    @KiyobumiState private var fitWidth = false
    @KiyobumiState private var imageError: String?
    @KiyobumiState private var actionStart: Page?
    @KiyobumiState private var undoPages: [Page] = []
    @KiyobumiState private var redoPages: [Page] = []
    @FocusState private var editingTitle: Bool
    @FocusState private var editingSubheader: Bool
    @KiyobumiState private var showingSubheaderEditor = false
    @KiyobumiState private var pinchStartZoom: CGFloat?
    @GestureState private var magnifying = false

    @KiyobumiState private var tool: Tool = .select
    @KiyobumiState private var strokeColorHex: String = "#111111"
    @KiyobumiState private var strokeWidth: Double = 3
    @KiyobumiState private var zoom: CGFloat = 1
    @KiyobumiState private var selectedElementID: UUID?
    @KiyobumiState private var editingTextID: UUID?
    @KiyobumiState private var liveStroke: Stroke?
    @KiyobumiState private var moveInfo: MoveInfo?
    @KiyobumiState private var lastTap: (time: Date, point: CGPoint)?

    private var headerHeight: CGFloat {
        CGFloat(PageHeaderLayout.height(title: page.displayTitle, width: Double(bodySize.width)))
    }

    // Stored element coordinates belong to the body, below the header. Keep
    // that origin unchanged for old notebooks, imported outlines and ink.
    private var bodySize: CGSize {
        var width: Double = 816
        var height: Double = 912
        for element in page.elements {
            let right: Double = element.frame.x + element.frame.width + 48.0
            let bottom: Double = element.frame.y + element.frame.height + 48.0
            width = max(width, right)
            height = max(height, bottom)
        }
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    private var pageSize: CGSize {
        CGSize(width: bodySize.width, height: bodySize.height + headerHeight)
    }

    private var titleBinding: Binding<String> {
        Binding(get: { page.title }, set: { beginAction(); page.title = $0; touch() })
    }

    struct MoveInfo {
        let id: UUID
        let startFrame: Frame
        let startLocation: CGPoint
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if let tabs = sectionTabs { tabs }
            canvasArea
                .background(RetroThemeBackground())
                .background(TextCanvasProbe(tools: textTools))
                .sheet(isPresented: $showingPaperDesign) {
                    PaperDesignSheet(design: page.paperDesign ?? PaperDesign(), background: page.background) { design, ruling in
                        beginAction(); page.paperDesign = design; page.background = ruling; touch(); endAction()
                    }
                }
                .sheet(isPresented: $showingTemplates) {
                    PageTemplateSheet(page: page, media: media, subtitle: subheader.wrappedValue, create: onTemplate)
                }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .focusedSceneValue(\.notebookPrintActions, NotebookPrintActions(
            printPage: { outputPDF(section: false, printing: true) },
            printSection: { outputPDF(section: true, printing: true) },
            exportPage: { outputPDF(section: false, printing: false) },
            exportSection: { outputPDF(section: true, printing: false) }))
    }

    private var printoutContent: some View {
        editorContent
        .onDisappear {
            insertionPanel?.cancel(nil)
            insertionPanel = nil
            printoutTask?.cancel(); printingTask?.cancel()
        }
        .overlay {
            if printingBusy || printoutBusy {
                ZStack {
                    Color.black.opacity(0.1).contentShape(Rectangle()).onTapGesture {}
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(printoutBusy ? printoutProgress : printingProgress)
                        Button("Cancel") {
                            if printoutBusy { printoutTask?.cancel() } else { printingTask?.cancel() }
                        }
                    }.padding(24).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(10)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let count = printoutCount, !printoutBusy && !printingBusy {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(count == 1 ? "Inserted 1 printout page" : "Inserted \(count) printout pages")
                    Button { printoutCount = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss printout notice")
                }
                .padding(12).background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(8).shadow(radius: 2).padding(16)
            }
        }
    }

    var body: some View {
        printoutContent
        .fileExporter(isPresented: $exportingAttachment, document: exportDocument, contentType: .data, defaultFilename: exportName) { result in
            if case .failure(let error) = result { imageError = error.localizedDescription }
        }
        .alert("Attachment or editor error", isPresented: Binding(
            get: { imageError != nil }, set: { if !$0 { imageError = nil } }
        ), actions: { Button("OK") { imageError = nil } },
        message: { Text(imageError ?? "") })
        .onChange(of: tool) { newTool in
            if newTool != .select { finishEditing() }
            if newTool == .text { selectedElementID = nil; textTools.prepareInsertion() }
        }
        .onChange(of: editingTitle) { focused in
            if focused { endSubheaderEditing(); finishEditing(); beginAction() } else { endAction() }
        }
        .onChange(of: editingSubheader) { focused in
            if focused { finishEditing() } else { showingSubheaderEditor = false }
        }
        .onChange(of: page.id) { _ in
            endSubheaderEditing()
            insertionPanel?.cancel(nil); printoutTask?.cancel()
            insertionPanel = nil
            printoutCount = nil; printoutRevealID = nil
        }
        .onChange(of: magnifying) { active in
            if !active { pinchStartZoom = nil }
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 0) {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ToolbarBox { toolPicker }
                ToolbarBox {
                    if tool == .pen || tool == .highlighter { inkControls } else { fontControls }
                }
                ToolbarBox {
                    HStack(spacing: 10) {
                        insertMenu.frame(width: 30, height: 34)
                        Divider().frame(height: 26)
                        paperMenu.frame(width: 30, height: 34)
                    }
                }
                ToolbarBox { historyControls }
                ToolbarBox { printMenu }
                ToolbarBox { zoomControls }
                ToolbarBox {
                    Button(action: onImport) { Image(systemName: "square.and.arrow.down").frame(width: 30, height: 34) }
                        .disabled(importBusy).help(importBusy ? "Importing OneNote…" : "Import OneNote…")
                        .accessibilityLabel("Import OneNote")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.regular)
            .font(.system(size: 16))
            .frame(height: 44)
            .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 8)
          }
          ToolbarBox { saveControls }
              .buttonStyle(.borderless).controlSize(.regular).font(.system(size: 16))
              .padding(.trailing, 10)
        }
        .frame(height: 60)
        .background(RetroThemeBackground())
        .simultaneousGesture(TapGesture().onEnded { endSubheaderEditing() })
    }

    private func chooseHighlight(_ color: String) {
        highlightColor = color
        textTools.apply { $0.highlightHex = color }
    }

    private var toolPicker: some View {
        HStack(spacing: 0) {
            toolButton(.select, symbol: "cursorarrow", name: "Select")
            toolButton(.text, symbol: "textformat.size", name: "Text")
            toolButton(.pen, symbol: "pencil.tip", name: "Pen")
            toolButton(.highlighter, symbol: "highlighter", name: "Highlighter")
            toolButton(.eraser, symbol: "eraser.fill", name: "Eraser")
        }
    }

    private func toolButton(_ choice: Tool, symbol: String, name: String) -> some View {
        Button { tool = choice } label: {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 4)
                    .fill(tool == choice ? Color.accentColor.opacity(0.18) : Color.clear))
                .foregroundStyle(tool == choice ? Color.accentColor : Color.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(name).accessibilityLabel(name)
        .accessibilityValue(tool == choice ? "Selected" : "Not selected")
    }

    private var fontControls: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(NSFontManager.shared.availableFontFamilies.sorted(), id: \.self) { name in
                    Button(name) { textTools.apply { $0.fontName = name } }
                }
            } label: { Text(textTools.format.fontName).lineLimit(1).frame(width: 132, alignment: .leading) }
            .help("Font family for new boxes or selected text")
            Picker("Font size", selection: Binding(get: { textTools.format.fontSize }, set: { size in
                textTools.apply { $0.fontSize = size }
            })) {
                ForEach(fontSizes, id: \.self) { size in Text(String(format: "%g", size)).tag(size) }
            }.labelsHidden().frame(width: 72)
            Button(action: { let value = !textTools.format.bold; textTools.apply { $0.bold = value } }) {
                Image(systemName: "bold").frame(width: 28, height: 34)
            }.tint(textTools.format.bold ? .accentColor : .primary).help("Bold")
            Button(action: { let value = !textTools.format.italic; textTools.apply { $0.italic = value } }) {
                Image(systemName: "italic").frame(width: 28, height: 34)
            }.tint(textTools.format.italic ? .accentColor : .primary).help("Italic")
            Button(action: { let value = !textTools.format.underline; textTools.apply { $0.underline = value } }) {
                Image(systemName: "underline").frame(width: 28, height: 34)
            }.tint(textTools.format.underline ? .accentColor : .primary).help("Underline")
            ColorPicker("Text color", selection: Binding(get: { Color(hex: textTools.format.colorHex) }, set: { color in
                textTools.apply { $0.colorHex = color.hex }
            }), supportsOpacity: false).labelsHidden().frame(width: 32)
            HStack(spacing: 0) {
                Button {
                    let color: String? = textTools.format.highlightHex == nil ? highlightColor : nil
                    textTools.apply { $0.highlightHex = color }
                } label: {
                    Image(systemName: "highlighter").frame(width: 28, height: 34)
                        .background(Color(hex: textTools.format.highlightHex ?? highlightColor)
                            .opacity(textTools.format.highlightHex == nil ? 0.25 : 1))
                }.help("Apply or remove text highlight").accessibilityLabel("Toggle text highlight")
                Menu {
                    Button("Yellow") { chooseHighlight("#FFF176") }
                    Button("Green") { chooseHighlight("#B9F6CA") }
                    Button("Pink") { chooseHighlight("#FFB3D9") }
                    Button("Blue") { chooseHighlight("#B3E5FC") }
                    Divider()
                    Button("Remove highlight") { textTools.apply { $0.highlightHex = nil } }
                } label: { Image(systemName: "chevron.down").font(.system(size: 10)).frame(width: 16, height: 34) }
                .menuIndicator(.hidden).help("Highlight colour").accessibilityLabel("Highlight colour")
            }
            Menu {
                Button("• Bullets") { textTools.list("• ") }
                Button("1. Numbered list") { textTools.list("number") }
                Button("☐ Checkboxes") { textTools.list("☐ ") }
                Button("☑ Checked boxes") { textTools.list("☑ ") }
                Button("✓ Checkmarks") { textTools.list("✓ ") }
                Button("✕ Crosses") { textTools.list("✕ ") }
                Divider()
                Button("Remove list markers") { textTools.list("") }
            } label: { Image(systemName: "list.bullet").frame(width: 28, height: 34) }
            .disabled(!textTools.hasText).help("List markers; Return continues a list")
        }
    }

    private var fontSizes: [Double] {
        Array(Set([8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64, 72, 96, 144, 288,
                   textTools.format.fontSize])).sorted()
    }

    private var inkControls: some View {
        HStack(spacing: 10) {
            ColorPicker("Ink", selection: Binding(get: { Color(hex: strokeColorHex) }, set: { strokeColorHex = $0.hex }), supportsOpacity: false)
                .labelsHidden().frame(width: 32)
            Slider(value: $strokeWidth, in: 1...12, step: 0.5).frame(width: 110)
            Text(String(format: "%.1f pt", strokeWidth)).font(.system(size: 14)).monospacedDigit()
        }
    }

    private var insertMenu: some View {
        Menu {
            Button("Text box") { addTextBox(at: insertionPoint) }
            Button("To-do checklist") { insertText("- [ ] First task\n- [ ] Second task") }
            Button("Table (3 × 3)") { insertTable() }
            Button("Table from clipboard…") {
                do { insertTable(rows: try TableText.parse(NSPasteboard.general.string(forType: .string) ?? "")) }
                catch { imageError = error.localizedDescription }
            }
            Button("Image…") {
                let target = flowInsertionTarget()
                chooseInsertionFile(title: "Insert image", types: [.image]) { url in
                    try insertImage(url, target: target)
                    tool = .select
                    printoutRevealID = selectedElementID
                }
            }.disabled(insertionPanel != nil || printoutBusy || printingBusy)
            Button("Document printout…", action: choosePrintout)
                .disabled(insertionPanel != nil || printoutBusy || printingBusy)
            Button("Attachment…") {
                let target = flowInsertionTarget()
                chooseInsertionFile(title: "Insert attachment", types: [.data]) { url in
                    try insertAttachment(url, target: target)
                }
            }.disabled(insertionPanel != nil || printoutBusy || printingBusy)
        } label: { Image(systemName: "plus.square") }.help("Insert")
    }

    private var paperMenu: some View {
        Menu {
            Picker("Paper", selection: Binding(get: { page.background }, set: {
                finishEditing(); beginAction(); page.background = $0; touch(); endAction()
            })) {
                Text("Plain").tag(PageBackground.plain)
                Text("Ruled").tag(PageBackground.ruled)
                Text("Grid").tag(PageBackground.grid)
            }
            Divider()
            Button("Page design…") { finishEditing(); showingPaperDesign = true }
            Button("Page templates…") { finishEditing(); showingTemplates = true }
            Divider()
            Button("Make box wider") { resizeSelection(dx: 40, dy: 0) }
            Button("Make box narrower") { resizeSelection(dx: -40, dy: 0) }
            Button("Make box taller") { resizeSelection(dx: 0, dy: 40) }
            Button("Make box shorter") { resizeSelection(dx: 0, dy: -40) }
        } label: { Image(systemName: "slider.horizontal.3") }.help("Paper and box size")
    }

    private var historyControls: some View {
        HStack(spacing: 10) {
            Button { finishEditing(); undo() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 28, height: 34) }
                .disabled(undoPages.isEmpty && actionStart == nil).help("Undo page action")
            Button { finishEditing(); redo() } label: { Image(systemName: "arrow.uturn.forward").frame(width: 28, height: 34) }
                .disabled(redoPages.isEmpty).help("Redo page action")
            Button(action: deleteSelection) { Image(systemName: "trash").frame(width: 28, height: 34) }.disabled(selectedElementID == nil).help("Delete selected element")
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 10) {
            Button { fitWidth.toggle() } label: { Image(systemName: "arrow.left.and.right").frame(width: 28, height: 34) }
                .help("Fit page width").tint(fitWidth ? .accentColor : .primary)
            Button { fitWidth = false; zoom = PageZoom.clamped(zoom - 0.1) } label: { Image(systemName: "minus.magnifyingglass").frame(width: 28, height: 34) }
            Button(fitWidth ? "Fit" : "\(Int((zoom * 100).rounded()))%") { fitWidth = false; zoom = 1 }
                .font(.system(size: 14)).monospacedDigit().frame(minWidth: 42, minHeight: 34).help("Actual size")
            Button { fitWidth = false; zoom = PageZoom.clamped(zoom + 0.1) } label: { Image(systemName: "plus.magnifyingglass").frame(width: 28, height: 34) }
        }
    }

    private var saveControls: some View {
        HStack(spacing: 4) {
            Button { textTools.finish(); autosave.saveNow() } label: {
                FloppyDiskIcon()
                    .frame(width: 34, height: 34)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: autosave.errorMessage != nil ? "exclamationmark.circle.fill" :
                              (autosave.status.hasPrefix("Saved") ? "checkmark.circle.fill" : "clock.fill"))
                            .font(.system(size: 11))
                            .foregroundStyle(autosave.errorMessage != nil ? Color.red :
                                (autosave.status.hasPrefix("Saved") ? Color.green : Color.secondary))
                            .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                            .accessibilityHidden(true)
                    }
            }
            .help("Save now · " + (autosave.errorMessage ?? autosave.status))
            .accessibilityLabel("Save now").accessibilityValue(autosave.errorMessage ?? autosave.status)
            Menu {
                Text(autosave.status)
                Button("Save now") { textTools.finish(); autosave.saveNow() }
                Button("Show in Finder") { autosave.showInFinder() }
            } label: { Image(systemName: "chevron.down").font(.system(size: 11)).frame(width: 18, height: 34) }
            .menuIndicator(.hidden)
            .help(autosave.errorMessage ?? autosave.status).accessibilityLabel("Save status and options")
        }
    }

    // The unscaled canvas retains its intrinsic size even when the ScrollView
    // proposes a smaller width. Only its outer layout footprint is scaled.
    private var canvasArea: some View {
        GeometryReader { geometry in
            let scale = fitWidth ? min(4, max(0.1, (geometry.size.width - 40) / pageSize.width)) : zoom
            ScrollViewReader { proxy in
              ScrollView([.horizontal, .vertical]) {
                pageCanvas
                    .frame(width: pageSize.width, height: pageSize.height, alignment: .topLeading)
                    .fixedSize()
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: pageSize.width * scale, height: pageSize.height * scale, alignment: .topLeading)
                    .padding(20)
                    .id("kiyobumi-page-origin")
              }
              .onAppear {
                  DispatchQueue.main.async {
                      proxy.scrollTo("kiyobumi-page-origin", anchor: .topLeading)
                  }
              }
              .onChange(of: printoutRevealID) { id in
                  guard let id else { return }
                  // Wait until the inserted elements have their new canvas layout.
                  DispatchQueue.main.async {
                      withAnimation { proxy.scrollTo(id, anchor: .topLeading) }
                  }
              }
              .simultaneousGesture(MagnificationGesture()
                .updating($magnifying) { _, active, _ in active = true }
                .onChanged { factor in
                    if pinchStartZoom == nil {
                        pinchStartZoom = scale
                        fitWidth = false
                    }
                    zoom = PageZoom.magnified(from: pinchStartZoom ?? scale, by: factor)
                }
                .onEnded { _ in pinchStartZoom = nil })
            }
        }
    }
    private var pageCanvas: some View {
        VStack(spacing: 0) {
            pageHeader
            pageBody
        }
        .frame(width: pageSize.width, height: pageSize.height, alignment: .topLeading)
        .background(Color(hex: (page.paperDesign ?? PaperDesign()).paperColor))
        .environment(\.colorScheme, .light)
        .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 2)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Untitled page", text: titleBinding, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .regular))
                .lineLimit(1...2)
                .accessibilityLabel("Page title")
                .focused($editingTitle)
                .onSubmit { endAction() }
            HStack(spacing: 18) {
                Text(page.createdAt, style: .date)
                Text(page.createdAt, style: .time)
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Page creation date and time")
            .onTapGesture { endSubheaderEditing() }
            Divider()
            subheaderRow
        }
        .padding(.horizontal, 48)
        .padding(.top, 16)
        .frame(width: bodySize.width, height: headerHeight, alignment: .topLeading)
        .background(Color(hex: (page.paperDesign ?? PaperDesign()).paperColor))
    }

    @ViewBuilder
    private var subheaderRow: some View {
        if showingSubheaderEditor {
            TextField("", text: subheader)
                .textFieldStyle(.plain).font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(minHeight: 22)
                .focused($editingSubheader)
                .accessibilityLabel("Optional page subheader")
                .onAppear {
                    DispatchQueue.main.async {
                        if showingSubheaderEditor { editingSubheader = true }
                    }
                }
                .onSubmit { endSubheaderEditing() }
                .onExitCommand { endSubheaderEditing() }
        } else {
            Button {
                finishEditing()
                showingSubheaderEditor = true
            } label: {
                Text(subheader.wrappedValue.isEmpty ? " " : subheader.wrappedValue)
                    .font(.system(size: 14)).lineLimit(1)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Optional page subheader")
            .accessibilityValue(subheader.wrappedValue.isEmpty ? "Empty" : subheader.wrappedValue)
            .help("Click to edit the subheader")
        }
    }

    private func endSubheaderEditing() {
        editingSubheader = false
        showingSubheaderEditor = false
    }

    private var pageBody: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: (page.paperDesign ?? PaperDesign()).paperColor)
            Canvas { context, size in
                let design = page.paperDesign ?? PaperDesign()
                if page.background != .plain {
                    var lines = Path()
                    for y in stride(from: design.spacing + 4, through: Double(size.height), by: design.spacing) {
                        lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    if page.background == .grid {
                        for x in stride(from: design.spacing, through: Double(size.width), by: design.spacing) {
                            lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height))
                        }
                    }
                    context.stroke(lines, with: .color(Color(hex: design.ruleColor)), lineWidth: 0.7)
                }
                if design.marginEnabled {
                    var margin = Path()
                    margin.move(to: CGPoint(x: design.marginPosition, y: 0))
                    margin.addLine(to: CGPoint(x: design.marginPosition, y: size.height))
                    context.stroke(margin, with: .color(Color(hex: design.marginColor)), lineWidth: 1)
                }
            }.allowsHitTesting(false)
            ForEach(textElements) { element in
                ElementView(element: elementBinding(element.id), imageData: imageData(for: element),
                            isSelected: selectedElementID == element.id, isEditing: editingTextID == element.id,
                            onDoneEditing: { finishEditing() }, onSaveAttachment: { exportAttachment(element) },
                            textTools: textTools,
                            onMove: { moveBox(element.id, translation: $0) },
                            onMoveEnd: { borderMoveStart = nil; touch(); endAction() },
                            onRequestEditing: {
                                tool = .select
                                selectedElementID = element.id; editingTextID = element.id
                            }, mediaLookup: { imageData(for: $0) }, saveEmbeddedAttachment: exportAttachment)
                    .allowsHitTesting(tool == .select || (tool == .text && element.isText))
                    .offset(x: element.frame.x, y: element.frame.y)
                    .id(element.id)
            }
            InkLayerView(inkElements: inkElements, liveStroke: liveStroke).allowsHitTesting(false)
        }
        .frame(width: bodySize.width, height: bodySize.height, alignment: .topLeading)
        .coordinateSpace(name: "page")
        .environment(\.colorScheme, .light)
        .overlay(alignment: .topLeading) {
            CanvasMiddleClick(canvasSize: bodySize,
                              enabled: !printingBusy && !printoutBusy && !importBusy && !showingPaperDesign && !showingTemplates,
                              canCreateAt: canCreateTextBoxAt,
                              onCreate: addTextBox)
                .frame(width: bodySize.width, height: bodySize.height)
        }
        .background(CanvasKeyboard(canDelete: selectedElementID != nil && editingTextID == nil && !editingTitle && !editingSubheader && !printingBusy && !printoutBusy,
                                   onDelete: deleteSelection))
        .overlay(alignment: .topLeading) {
            if tool == .select, let id = selectedElementID,
               let element = page.elements.first(where: { $0.id == id }), !isInk(element) {
                ElementResizeHandles(width: element.frame.width, height: element.frame.height, allowsHeightResize: !isTable(element),
                    onChange: { drag, corner in resizeElement(id, drag: drag, corner: corner) },
                    onEnd: { resizeStart = nil; touch(); endAction() })
                    .offset(x: element.frame.x, y: element.frame.y)
            }
        }
        .gesture(canvasGesture, including: editingTextID == nil ? .all : .subviews)
        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .named("page")).onEnded { value in
            endSubheaderEditing()
            guard let id = editingTextID else { return }
            let frame = frameOf(id)
            let rect = CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
            if let element = page.elements.first(where: { $0.id == id }), isTable(element) {
                // The floating table controls belong to the editor, outside its bounds.
                let controls = CGRect(x: frame.x, y: frame.y - 40, width: max(frame.width, 400), height: 40)
                if controls.contains(value.location) { return }
            }
            if !rect.contains(value.location) { finishEditing() }
        })
    }

    private var canvasGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("page"))
            .onChanged { handleDragChanged($0) }
            .onEnded { handleDragEnded($0) }
    }

    // MARK: Gesture handling

    private func handleDragChanged(_ v: DragGesture.Value) {
        guard resizeStart == nil, borderMoveStart == nil else { return }
        if tool == .select, let id = hitTest(v.startLocation),
           let element = page.elements.first(where: { $0.id == id }), element.isText || isTable(element) { return }
        endSubheaderEditing()
        beginAction()
        let p = v.location
        switch tool {
        case .pen, .highlighter:
            if liveStroke == nil {
                liveStroke = Stroke(
                    kind: tool == .pen ? .pen : .highlighter,
                    colorHex: strokeColorHex,
                    width: tool == .pen ? strokeWidth : strokeWidth * 4
                )
            }
            liveStroke?.points.append(StrokePoint(x: Double(p.x), y: Double(p.y)))

        case .eraser:
            eraseAt(p)

        case .text:
            break

        case .select:
            if let m = moveInfo {
                if let i = page.elements.firstIndex(where: { $0.id == m.id }) {
                    page.elements[i].frame.x = max(0, m.startFrame.x + Double(v.location.x - m.startLocation.x))
                    page.elements[i].frame.y = max(0, m.startFrame.y + Double(v.location.y - m.startLocation.y))
                }
            } else if !isTap(v), let hit = hitTest(v.startLocation) {
                selectedElementID = hit
                editingTextID = nil
                moveInfo = MoveInfo(id: hit,
                                    startFrame: frameOf(hit),
                                    startLocation: v.startLocation)
            }
        }
    }

    private func handleDragEnded(_ v: DragGesture.Value) {
        guard resizeStart == nil, borderMoveStart == nil else { return }
        defer { moveInfo = nil; if editingTextID == nil && resizeStart == nil { endAction() } }

        if let stroke = liveStroke {
            liveStroke = nil
            commit(stroke)
            return
        }

        if tool == .text && isTap(v) {
            if let hit = hitTest(v.startLocation), isTextElement(hit) { return }
            addTextBox(at: v.location)
            return
        }

        if tool == .select && isTap(v) {
            let now = Date()
            let isDoubleTap = lastTap.map {
                now.timeIntervalSince($0.time) < 0.35 &&
                hypot(v.location.x - $0.point.x, v.location.y - $0.point.y) < 8
            } ?? false
            lastTap = (now, v.location)

            let hit = hitTest(v.startLocation)
            if isDoubleTap, let id = hit, isTextElement(id) {
                selectedElementID = id
                editingTextID = id
            } else if let id = hit {
                selectedElementID = id
                if let element = page.elements.first(where: { $0.id == id }), element.isText {
                    let frame = element.frame
                    let inside = CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
                        .insetBy(dx: 4, dy: 4).contains(v.startLocation)
                    if !inside { editingTextID = nil }
                    else if !isTable(element) { editingTextID = id }
                } else if editingTextID != id { editingTextID = nil }
            } else {
                selectedElementID = nil
                editingTextID = nil
            }
        }
    }

    // MARK: Model helpers

    private var inkElements: [PageElement] {
        page.elements.filter { if case .ink = $0.content { return true }; return false }
    }

    private var textElements: [PageElement] {
        page.elements.filter { if case .ink = $0.content { return false }; return true }
    }

    private func elementBinding(_ id: UUID) -> Binding<PageElement> {
        Binding(
            get: {
                page.elements.first { $0.id == id }
                    ?? PageElement(frame: .zero, content: .text(markdown: ""))
            },
            set: { newValue in
                if let i = page.elements.firstIndex(where: { $0.id == id }) {
                    beginAction()
                    let previousFrame = page.elements[i].frame
                    page.elements[i] = newValue
                    if case .table = newValue.content {
                        page.elements[i].frame.width = max(newValue.frame.width, ElementLayout.minimumWidth(newValue))
                        page.elements[i].frame.height = ElementLayout.height(page.elements[i], editing: editingTextID == newValue.id)
                    }
                    if automaticallyPushContentDown, editingTextID == id,
                       resizeStart == nil, borderMoveStart == nil {
                        ContentFlow.pushBelow(in: &page.elements, changedID: id, previous: previousFrame)
                    }
                    touch()
                    if editingTextID == nil && resizeStart == nil { endAction() }
                }
            }
        )
    }

    private func canCreateTextBoxAt(_ point: CGPoint) -> Bool {
        // Ink containers often span most of an imported page, including blank
        // paper between strokes. They have no text/table context menu to protect.
        for element in textElements {
            let f = element.frame
            if CGRect(x: f.x, y: f.y, width: f.width, height: f.height).contains(point) {
                return false
            }
        }
        // Floating editing controls and selection handles are not blank paper.
        if let id = editingTextID,
           let element = page.elements.first(where: { $0.id == id }), isTable(element) {
            let f = element.frame
            if CGRect(x: f.x, y: f.y - 40, width: max(f.width, 400), height: 40).contains(point) {
                return false
            }
        }
        if let id = selectedElementID, tool == .select,
           let element = page.elements.first(where: { $0.id == id }), !isInk(element) {
            let f = element.frame
            if CGRect(x: f.x, y: f.y, width: f.width, height: f.height)
                .insetBy(dx: -8, dy: -14).contains(point) { return false }
        }
        return true
    }

    private func hitTest(_ p: CGPoint) -> UUID? {
        for element in page.elements.reversed() {
            let f = element.frame
            if p.x >= f.x, p.x <= f.x + f.width, p.y >= f.y, p.y <= f.y + f.height {
                return element.id
            }
        }
        return nil
    }

    private func frameOf(_ id: UUID) -> Frame {
        page.elements.first { $0.id == id }?.frame ?? .zero
    }

    private func isTextElement(_ id: UUID) -> Bool {
        page.elements.first { $0.id == id }?.isText ?? false
    }

    private func isTap(_ v: DragGesture.Value) -> Bool {
        abs(v.translation.width) < 3 && abs(v.translation.height) < 3
    }

    private func commit(_ stroke: Stroke) {
        guard stroke.points.count > 1 else { return }
        let xs = stroke.points.map(\.x)
        let ys = stroke.points.map(\.y)
        guard let minX = xs.min(), let minY = ys.min(),
              let maxX = xs.max(), let maxY = ys.max() else { return }

        // Store points relative to the element frame so moving the element is free
        var normalized = stroke
        normalized.points = stroke.points.map {
            StrokePoint(x: $0.x - minX, y: $0.y - minY, pressure: $0.pressure)
        }
        let frame = Frame(x: minX, y: minY,
                          width: maxX - minX, height: maxY - minY)
        page.elements.append(PageElement(frame: frame, content: .ink(strokes: [normalized])))
        touch()
    }

    private func eraseAt(_ p: CGPoint) {
        let r = 10.0
        var changed = false
        for i in page.elements.indices {
            guard case .ink(var strokes) = page.elements[i].content else { continue }
            let ox = page.elements[i].frame.x
            let oy = page.elements[i].frame.y
            let before = strokes.count
            strokes.removeAll { stroke in
                let points = stroke.points
                if points.count == 1, let q = points.first {
                    return hypot(q.x + ox - p.x, q.y + oy - p.y) <= r + stroke.width / 2
                }
                return zip(points, points.dropFirst()).contains { a, b in
                    let dx = b.x - a.x, dy = b.y - a.y
                    let squaredLength = dx * dx + dy * dy
                    let t = squaredLength == 0 ? 0 : max(0, min(1,
                        ((Double(p.x) - ox - a.x) * dx + (Double(p.y) - oy - a.y) * dy) / squaredLength))
                    return hypot(a.x + ox + t * dx - Double(p.x), a.y + oy + t * dy - Double(p.y)) <= r + stroke.width / 2
                }
            }
            if strokes.count != before {
                changed = true
                page.elements[i].content = .ink(strokes: strokes)
            }
        }
        page.elements.removeAll { element in
            if case .ink(let s) = element.content { return s.isEmpty }
            return false
        }
        if changed { touch() }
    }

    private func addTextBox(at p: CGPoint) {
        let chosenFormat = textTools.format
        finishEditing(); textTools.prepareInsertion(); beginAction()
        let element = PageElement(
            frame: Frame(x: Double(p.x), y: Double(p.y), width: 160, height: 100),
            content: .richText(RichTextContent(defaultFormat: chosenFormat))
        )
        page.elements.append(element)
        selectedElementID = element.id
        editingTextID = element.id
        tool = .select
        touch()
    }

    private var insertionPoint: CGPoint {
        CGPoint(x: 48, y: max(48, page.elements.map { $0.frame.y + $0.frame.height + 20 }.max() ?? 48))
    }
    private func insertText(_ markdown: String) {
        let chosenFormat = textTools.format
        addTextBox(at: insertionPoint)
        if let i = page.elements.firstIndex(where: { $0.id == editingTextID }) {
            page.elements[i].content = .richText(RichTextCodec.fromMarkdown(markdown, defaultFormat: chosenFormat))
        }
    }
    private func insertTable(rows: [[String]] = Array(repeating: Array(repeating: "", count: 3), count: 3)) {
        let target = flowInsertionTarget()
        finishEditing(); beginAction()
        let p = insertionPoint
        var element = PageElement(frame: Frame(x: p.x, y: p.y, width: max(540, Double(rows.first?.count ?? 1) * 64 + 8), height: 150), content: .table(rows: rows))
        element.frame.height = ElementLayout.height(element, editing: true)
        if insertIntoFlow([element], target: target) { return }
        page.elements.append(element); selectedElementID = element.id; editingTextID = element.id; tool = .select
        touch()
    }
    private func flowInsertionTarget() -> FlowInsertion? {
        guard let containerID = editingTextID, let (blockID, offset) = textTools.insertionAnchor else { return nil }
        return FlowInsertion(pageID: page.id, containerID: containerID, blockID: blockID, offset: offset)
    }

    @discardableResult
    private func insertIntoFlow(_ blocks: [PageElement], target: FlowInsertion?) -> Bool {
        guard let target, target.pageID == page.id,
              let index = page.elements.firstIndex(where: { $0.id == target.containerID }) else { return false }
        var copy = page.elements[index]
        let previous = copy.frame
        guard FlowLayout.insert(blocks, into: &copy, blockID: target.blockID, offset: target.offset) else { return false }
        beginAction()
        page.elements[index] = copy
        if automaticallyPushContentDown {
            ContentFlow.pushBelow(in: &page.elements, changedID: copy.id, previous: previous)
        }
        selectedElementID = copy.id; editingTextID = copy.id; tool = .select
        touch(); endAction()
        return true
    }
    private func resizeSelection(dx: Double, dy: Double) {
        finishEditing()
        guard let id = selectedElementID else { return }
        resizeElement(id, drag: CGSize(width: dx, height: dy), corner: dy != 0)
        resizeStart = nil; touch(); endAction()
    }
    private func moveBox(_ id: UUID, translation: CGSize) {
        guard let index = page.elements.firstIndex(where: { $0.id == id }) else { return }
        if borderMoveStart == nil {
            finishEditing(); beginAction(); tool = .select; selectedElementID = id
            borderMoveStart = page.elements[index].frame
        }
        guard let start = borderMoveStart else { return }
        page.elements[index].frame.x = max(0, start.x + Double(translation.width))
        page.elements[index].frame.y = max(0, start.y + Double(translation.height))
        touch()
    }
    private func resizeElement(_ id: UUID, drag: CGSize, corner: Bool) {
        guard let i = page.elements.firstIndex(where: { $0.id == id }) else { return }
        if resizeStart == nil { finishEditing(); beginAction(); resizeStart = page.elements[i].frame }
        guard let start = resizeStart else { return }
        page.elements[i].frame.width = min(100_000, max(ElementLayout.minimumWidth(page.elements[i]), start.width + Double(drag.width)))
        if isTable(page.elements[i]) {
            page.elements[i].minimumHeight = nil
        } else if corner {
            let minimum = max(40, min(100_000, start.height + Double(drag.height)))
            page.elements[i].minimumHeight = minimum
            page.elements[i].frame.height = minimum
        }
        page.elements[i].frame.height = ElementLayout.height(page.elements[i])
        touch()
    }
    private func isTable(_ element: PageElement) -> Bool {
        if case .table = element.content { return true }; return false
    }
    private func isInk(_ element: PageElement) -> Bool {
        if case .ink = element.content { return true }; return false
    }
    private func deleteSelection() {
        guard let id = selectedElementID else { return }
        finishEditing(); beginAction()
        page.elements.removeAll { $0.id == id }
        selectedElementID = nil; textTools.prepareInsertion(); touch(); endAction()
    }
    private var printMenu: some View {
        Menu {
            Picker("Paper size", selection: $paperSize) {
                Text("A4").tag(PrintPaper.a4)
                Text("US Letter").tag(PrintPaper.letter)
            }
            Divider()
            Button("Export page as PDF…") { outputPDF(section: false, printing: false) }
            Button("Export section as PDF…") { outputPDF(section: true, printing: false) }
            Divider()
            Button("Print page…  ⌘P") { outputPDF(section: false, printing: true) }
            Button("Print section…") { outputPDF(section: true, printing: true) }
        } label: { Image(systemName: "printer").frame(width: 30, height: 34) }
        .help("Export or print this page or its section")
    }
    private func outputPDF(section: Bool, printing: Bool) {
        guard !printingBusy && !printoutBusy else { return }
        finishEditing(); endSubheaderEditing()
        NSApp.keyWindow?.makeFirstResponder(nil)
        let snapshots = section ? sectionPages() : [PrintPageSnapshot(page: page, subheader: subheader.wrappedValue)]
        let mediaSnapshot = media
        let paper = paperSize
        printingBusy = true; printingProgress = "Preparing PDF…"
        printingTask = Task { @MainActor in
            defer { printingBusy = false; printingTask = nil }
            do {
                let pdf = try await NotebookPrinting.makePDF(snapshots, media: mediaSnapshot, paper: paper) { printingProgress = $0 }
                try Task.checkCancellation()
                printingBusy = false
                try NotebookPrinting.output(pdf, pages: snapshots, paper: paper, printing: printing)
            } catch is CancellationError {} catch { imageError = String(error.localizedDescription.prefix(800)) }
        }
    }
    private func choosePrintout() {
        let target = flowInsertionTarget()
        chooseInsertionFile(title: "Insert document printout", types: PrintoutImporter.contentTypes) { url in
            importPrintout(url, target: target)
        }
    }
    private func chooseInsertionFile(title: String, types: [UTType], insert: @escaping (URL) throws -> Void) {
        guard insertionPanel == nil, !printoutBusy, !printingBusy else { return }
        finishEditing(); endSubheaderEditing()
        let targetPageID = page.id
        let window = textTools.canvasView?.window ?? NSApp.keyWindow
        window?.makeFirstResponder(nil)
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Insert"
        panel.allowedContentTypes = types
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        insertionPanel = panel
        // A dedicated AppKit panel avoids competing fileImporter modifiers on
        // this editor. Begin after the Insert menu has finished dismissing.
        DispatchQueue.main.async {
            guard insertionPanel === panel, page.id == targetPageID else {
                return
            }
            let completion: (NSApplication.ModalResponse) -> Void = { response in
                DispatchQueue.main.async {
                    guard insertionPanel === panel else { return }
                    insertionPanel = nil
                    guard response == .OK, page.id == targetPageID, let url = panel.url else { return }
                    do { try insert(url) }
                    catch { imageError = String(error.localizedDescription.prefix(800)) }
                }
            }
            if let window, window.isVisible {
                panel.beginSheetModal(for: window, completionHandler: completion)
            } else {
                panel.begin(completionHandler: completion)
            }
        }
    }
    private func importPrintout(_ url: URL, target: FlowInsertion? = nil) {
        finishEditing(); endSubheaderEditing()
        let targetPageID = page.id
        printoutCount = nil
        printoutBusy = true; printoutProgress = "Preparing printout…"
        printoutTask = Task { @MainActor in
            defer { printoutBusy = false; printoutTask = nil }
            do {
                let sheets = try await PrintoutImporter.load(url) { printoutProgress = $0 }
                try Task.checkCancellation()
                guard page.id == targetPageID else { return }
                guard !sheets.isEmpty else { throw NotebookFailure.invalid("This document has no printable pages.") }
                beginAction()
                var point = insertionPoint
                var firstElementID: UUID?
                var inserted: [PageElement] = []
                for sheet in sheets {
                    let name = UUID().uuidString.lowercased() + ".pdf"
                    media[name] = .data(sheet.data)
                    let width = min(720, sheet.size.width * 96 / 72)
                    let height = width * sheet.size.height / sheet.size.width
                    let element = PageElement(frame: Frame(x: point.x, y: point.y, width: width, height: height),
                        content: .image(mediaName: name))
                    inserted.append(element)
                    if firstElementID == nil { firstElementID = element.id }
                    point.y += height + 24
                }
                if insertIntoFlow(inserted, target: target) {
                    printoutRevealID = selectedElementID
                    printoutCount = sheets.count
                    return
                }
                page.elements.append(contentsOf: inserted)
                selectedElementID = firstElementID
                tool = .select; touch(); endAction()
                printoutRevealID = firstElementID
                printoutCount = sheets.count
            } catch is CancellationError {} catch { imageError = String(error.localizedDescription.prefix(800)) }
        }
    }
    private func insertAttachment(_ url: URL, target: FlowInsertion? = nil) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= 50 * 1024 * 1024 else {
            throw NotebookFailure.invalid("Choose a regular attachment no larger than 50 MB.")
        }
        let data = try Data(contentsOf: url)
        let name = UUID().uuidString.lowercased() + ".bin"
        finishEditing(); beginAction(); media[name] = .data(data)
        let p = insertionPoint
        let element = PageElement(frame: Frame(x: p.x, y: p.y, width: 340, height: 58), content: .attachment(mediaName: name, fileName: url.lastPathComponent))
        if insertIntoFlow([element], target: target) { return }
        page.elements.append(element); selectedElementID = element.id; touch(); endAction()
    }
    private func exportAttachment(_ element: PageElement) {
        guard case .attachment(let name, let fileName) = element.content, let data = media[name]?.regularFileContents else { return }
        exportDocument = AttachmentDocument(data: data)
        exportName = fileName.components(separatedBy: CharacterSet(charactersIn: "/\\")).last ?? "attachment.bin"
        exportingAttachment = true
    }
    private func imageData(for element: PageElement) -> Data? {
        if case .image(let name) = element.content { return media[name]?.regularFileContents }
        return nil
    }
    private func insertImage(_ url: URL, target: FlowInsertion? = nil) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard try handle.seekToEnd() <= 50 * 1024 * 1024 else {
            throw NotebookFailure.invalid("Images must be 50 MB or smaller in this prototype.")
        }
        try handle.seek(toOffset: 0)
        let data = try handle.readToEnd() ?? Data()
        guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw NotebookFailure.invalid("This image could not be decoded.")
        }
        finishEditing(); beginAction()
        let ext = url.pathExtension.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        let name = UUID().uuidString.lowercased() + (ext.isEmpty ? ".bin" : "." + ext)
        media[name] = .data(data)
        let width = min(500, image.size.width)
        let height = width * image.size.height / image.size.width
        let element = PageElement(frame: Frame(x: 60, y: 60, width: width, height: height), content: .image(mediaName: name))
        if insertIntoFlow([element], target: target) { return }
        page.elements.append(element); selectedElementID = element.id
        touch(); endAction()
    }
    private func beginAction() {
        if actionStart == nil { actionStart = page }
    }
    private func endAction() {
        if let start = actionStart, start != page {
            undoPages.append(start)
            if undoPages.count > 100 { undoPages.removeFirst() }
            redoPages.removeAll()
        }
        actionStart = nil
    }
    private func finishEditing() { textTools.finish(); editingTextID = nil; endAction() }
    private func undo() {
        guard let previous = undoPages.popLast() else { return }
        redoPages.append(page); page = previous; selectedElementID = nil
    }
    private func redo() {
        guard let next = redoPages.popLast() else { return }
        undoPages.append(page); page = next; selectedElementID = nil
    }

    private func touch() { page.modifiedAt = Date() }
}
