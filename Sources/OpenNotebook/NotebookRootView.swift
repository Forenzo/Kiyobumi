import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct NotebookRootView: View {
    @ObservedObject private var appearance = AppearancePreferences.shared
    @Environment(\.colorScheme) private var colorScheme
    @Binding var notebook: Notebook
    @Binding var media: [String: StoredFile]
    @Binding var ancillary: [String: StoredFile]
    var fileURL: URL? = nil
    @KiyobumiState private var importingOne = false
    @KiyobumiState private var importBusy = false
    @KiyobumiState private var importError: ImportProblem?
    @KiyobumiState private var importReport: OneNoteImportReport?
    @KiyobumiState private var showingReport = false
    @KiyobumiState private var selectedSectionID: UUID?
    @KiyobumiState private var selectedPageID: UUID?
    @KiyobumiState private var query = ""
    @KiyobumiState private var renamingSection: UUID?
    @KiyobumiState private var sectionName = ""
    @KiyobumiState private var showingRename = false
    @KiyobumiState private var headerError: String?
    @KiyobumiState private var pageColumnWidth: CGFloat = 180

    private var selectedSubtitle: String {
        guard let id = selectedPageID else { return "" }
        return (try? PageHeaderMetadata.read(ancillary[PageHeaderMetadata.fileName]).text(for: id)) ?? ""
    }

    var body: some View {
        NavigationSplitView {
            sectionSidebar
                .background(sidebarBackground(pages: false))
                .accentColor(sidebarAccent)
                .tint(sidebarAccent)
                .navigationSplitViewColumnWidth(min: 170, ideal: 205, max: 320)
        } content: {
            pageList
                .background(sidebarBackground(pages: true))
                .accentColor(sidebarAccent)
                .tint(sidebarAccent)
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: PageColumnWidthKey.self, value: geometry.size.width)
                })
                .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 360)
        } detail: { detail }
        .frame(minWidth: 820, minHeight: 520)
        .navigationTitle("")
        .withoutNotebookWindowTitle()
        .toolbarBackground(appearance.theme == .classic ? Color(nsColor: .windowBackgroundColor) :
            Color(hex: appearance.theme.sidebarHex(dark: colorScheme == .dark, pages: true)), for: .windowToolbar)
        .toolbarBackground(appearance.theme == .classic ? .automatic : .visible, for: .windowToolbar)
        .onPreferenceChange(PageColumnWidthKey.self) { width in
            if width > 0 { pageColumnWidth = width }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                PageWordCountView(page: selectedPageID.flatMap { notebook.pages[$0] },
                                  subtitle: selectedSubtitle)
                    .frame(width: max(100, pageColumnWidth - 20), alignment: .center)
            }
        }
        .fileImporter(isPresented: $importingOne, allowedContentTypes: [.data]) { result in
            switch result {
            case .failure(let error): importError = ImportProblem(error)
            case .success(let url):
                importBusy = true
                Task { @MainActor in
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() }; importBusy = false }
                    do { try merge(try await OneNoteImporter.load(url)) }
                    catch { importError = ImportProblem(error) }
                }
            }
        }
        .sheet(item: $importError) { problem in
            ImportErrorSheet(problem: problem) { importError = nil }
        }
        .background(InitialNotebookWindowSize().frame(width: 0, height: 0))
        .alert("Could not update subheader", isPresented: Binding(
            get: { headerError != nil }, set: { if !$0 { headerError = nil } }
        )) { Button("OK") { headerError = nil } } message: { Text(headerError ?? "") }
        .sheet(isPresented: $showingReport) {
            VStack(alignment: .leading, spacing: 14) {
                Text("OneNote import complete").font(.title2)
                if let report = importReport {
                    Text("\(report.pages) pages · \(report.sections) sections · \(report.attachments) attachments")
                    Text("Review these conversion notes before relying on the imported copy.").foregroundStyle(.secondary)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(report.warnings.enumerated()), id: \.offset) { entry in
                                Text("• " + entry.element).textSelection(.enabled)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("The report is saved inside your notebook. Keep your original OneNote files.").font(.caption)
                }
                HStack { Spacer(); Button("Done") { showingReport = false }.keyboardShortcut(.defaultAction) }
            }.padding(24).frame(width: 580, height: 410)
        }
        .sheet(isPresented: $showingRename) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rename section").font(.headline)
                TextField("Section name", text: $sectionName)
                HStack {
                    Button("Cancel") { showingRename = false }; Spacer()
                    Button("Rename") {
                        if let i = notebook.sections.firstIndex(where: { $0.id == renamingSection }) { notebook.sections[i].name = sectionName }
                        showingRename = false
                    }.disabled(sectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 360)
        }
        .onAppear(perform: selectInitial)
        .onChange(of: selectedSectionID) { _ in selectFirstPage() }
    }

    private var sidebarAccent: Color {
        appearance.theme == .classic ? .accentColor : Color(hex: colorScheme == .dark ? appearance.theme.highlightHex : appearance.theme.selectionHex)
    }
    private func sidebarBackground(pages: Bool) -> Color {
        appearance.theme == .classic ? .clear :
            Color(hex: appearance.theme.sidebarHex(dark: colorScheme == .dark, pages: pages))
    }

    private var sectionSidebar: some View {
        VStack(spacing: 8) {
            RetroThemeRibbon()
            NotebookNameField(name: $notebook.name).padding(.horizontal, 10)
            NotebookCollectionList(currentURL: fileURL)
            Divider()
            TextField("Search this notebook", text: $query).textFieldStyle(.roundedBorder).padding(.horizontal, 10)
            List(selection: $selectedSectionID) {
                ForEach(notebook.sections) { section in
                    HStack {
                        Circle().fill(Color(hex: section.colorHex)).frame(width: 9, height: 9)
                        Text(section.name).lineLimit(2)
                    }.listRowBackground(appearance.theme == .classic ? nil : Color.clear)
                    .tag(section.id).contextMenu {
                        Button("Rename…") { renameSection(section.id) }
                        Menu("Section color") {
                            ForEach(SectionTabColor.palette) { choice in
                                Button(choice.name) { setSectionColor(section.id, choice.hex) }
                            }
                        }
                        Button("Move Up") { moveSection(section.id, -1) }
                        Button("Move Down") { moveSection(section.id, 1) }
                        Button("Delete Section") { deleteSection(section.id) }
                    }
                }.onDelete(perform: deleteSections)
            }.listStyle(.sidebar)
                .scrollContentBackground(appearance.theme == .classic ? .automatic : .hidden)
            HStack {
                Button(action: addSection) { Label("Section", systemImage: "plus") }; Spacer()
                if importBusy { ProgressView().controlSize(.small) }
            }.padding(10)
        }.padding(.top, 8)
    }
    private var selectedSection: Section? { notebook.sections.first { $0.id == selectedSectionID } }
    private var searchResults: [SearchResult] {
        let headers = try? PageHeaderMetadata.read(ancillary[PageHeaderMetadata.fileName])
        return notebook.sections.flatMap { section in
            section.pageIDs.compactMap { id -> SearchResult? in
                guard let page = notebook.pages[id] else { return nil }
                let searchable = page.searchableText + "\n" + (headers?.text(for: id) ?? "")
                guard searchable.localizedCaseInsensitiveContains(query) else { return nil }
                return SearchResult(section: section, page: page)
            }
        }
    }
    private struct SearchResult: Identifiable { var section: Section; var page: Page; var id: UUID { page.id } }
    @ViewBuilder private var pageList: some View {
        if !query.isEmpty {
            List {
                ForEach(searchResults) { result in
                    Button {
                        selectedSectionID = result.section.id; selectedPageID = result.page.id
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.page.displayTitle).foregroundStyle(.primary).lineLimit(2)
                            Text(result.section.name).font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                        .listRowBackground(appearance.theme == .classic ? nil : Color.clear)
                }
            }.scrollContentBackground(appearance.theme == .classic ? .automatic : .hidden)
             .overlay { if searchResults.isEmpty { Text("No matching pages").foregroundStyle(.secondary) } }
        } else if let section = selectedSection {
            VStack(spacing: 0) {
                List(selection: $selectedPageID) {
                    ForEach(section.pageIDs, id: \.self) { pageID in
                        if let page = notebook.pages[pageID] {
                            Text(page.displayTitle).lineLimit(2).padding(.leading, CGFloat(page.level) * 14).tag(pageID)
                                .listRowBackground(appearance.theme == .classic ? nil : Color.clear)
                                .contextMenu {
                                    Button("Duplicate Page") { duplicatePage(pageID) }
                                    Button("Move Up") { movePage(pageID, by: -1) }
                                    Button("Move Down") { movePage(pageID, by: 1) }
                                    Button("Indent as Subpage") { notebook.pages[pageID]?.level = min(2, page.level + 1) }
                                    Button("Outdent") { notebook.pages[pageID]?.level = max(0, page.level - 1) }
                                    Button("Delete Page") { deletePage(pageID) }
                                }
                        }
                    }.onDelete(perform: deletePages)
                }
                .scrollContentBackground(appearance.theme == .classic ? .automatic : .hidden)
                HStack(spacing: 8) {
                    Button(action: addPage) { Label("New page", systemImage: "doc.badge.plus") }
                    Button(action: addSubpage) { Label("Subpage", systemImage: "arrow.turn.down.right") }
                        .disabled(!canAddSubpage)
                        .help("New subpage beneath the selected page (up to two indent levels)")
                        .accessibilityLabel("New subpage")
                }.font(.system(size: 12)).buttonStyle(.borderless).controlSize(.small)
                 .padding(.horizontal, 6).padding(.vertical, 10)
            }
        } else { Text("Select a section").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
    }
    @ViewBuilder private var detail: some View {
        if let pid = selectedPageID, notebook.pages[pid] != nil {
            PageEditorView(page: pageBinding(pageID: pid), media: $media,
                           subheader: subheaderBinding(pageID: pid),
                           sectionTabs: sectionTabs,
                           onImport: { importingOne = true }, importBusy: importBusy,
                           onTemplate: addTemplatePage,
                           sectionPages: {
                               let headers = try? PageHeaderMetadata.read(ancillary[PageHeaderMetadata.fileName])
                               let section = notebook.sections.first { $0.pageIDs.contains(pid) }
                               return (section?.pageIDs ?? [pid]).compactMap { id in
                                   notebook.pages[id].map { PrintPageSnapshot(page: $0, subheader: headers?.text(for: id) ?? "") }
                               }
                           }).id(pid)
        } else {
            VStack(spacing: 0) {
                sectionTabs
                VStack(spacing: 10) {
                    Image(systemName: "doc.richtext").font(.system(size: 40))
                    Text("No page selected").font(.title3)
                    Text("Choose a page or create a new one.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private var sectionTabs: SectionTabStrip {
        SectionTabStrip(sections: notebook.sections, selectedSectionID: selectedSectionID,
                        onSelect: selectSection, onAdd: addSection, onRename: renameSection,
                        onColor: setSectionColor, onMove: moveSection, onDelete: deleteSection)
    }
    private func selectSection(_ id: UUID) {
        guard notebook.sections.contains(where: { $0.id == id }) else { return }
        query = ""
        selectedSectionID = id
        selectFirstPage()
    }
    private func renameSection(_ id: UUID) {
        guard let section = notebook.sections.first(where: { $0.id == id }) else { return }
        renamingSection = id; sectionName = section.name; showingRename = true
    }
    private func setSectionColor(_ id: UUID, _ hex: String) {
        guard let i = notebook.sections.firstIndex(where: { $0.id == id }) else { return }
        notebook.sections[i].colorHex = hex
    }
    private func merge(_ result: OneNoteImportResult) throws {
        guard Set(result.document.notebook.pages.keys).isDisjoint(with: Set(notebook.pages.keys)),
              Set(result.document.media.keys).isDisjoint(with: Set(media.keys)) else {
            throw NotebookFailure.invalid("Import IDs conflict with existing contents; nothing was imported.")
        }
        notebook.sections.append(contentsOf: result.document.notebook.sections)
        notebook.pages.merge(result.document.notebook.pages) { old, _ in old }
        media.merge(result.document.media) { old, _ in old }
        ancillary["import-" + UUID().uuidString.lowercased() + ".json"] = .data(result.reportData)
        importReport = result.report; showingReport = true; query = ""
        if let section = result.document.notebook.sections.first { selectedSectionID = section.id; selectedPageID = section.pageIDs.first }
    }
    private func pageBinding(pageID: UUID) -> Binding<Page> {
        Binding(get: { notebook.pages[pageID] ?? Page() }, set: { value in
            var updated = value; updated.modifiedAt = Date(); notebook.pages[pageID] = updated
        })
    }
    private func subheaderBinding(pageID: UUID) -> Binding<String> {
        Binding(get: {
            (try? PageHeaderMetadata.read(ancillary[PageHeaderMetadata.fileName]))?.text(for: pageID) ?? ""
        }, set: { text in
            if updateSubheaders({ $0.set(text, for: pageID) }) {
                notebook.pages[pageID]?.modifiedAt = Date()
            }
        })
    }
    @discardableResult
    private func updateSubheaders(_ change: (inout PageHeaderMetadata) -> Void) -> Bool {
        do {
            var headers = try PageHeaderMetadata.read(ancillary[PageHeaderMetadata.fileName])
            change(&headers)
            if headers.subheaders.isEmpty { ancillary.removeValue(forKey: PageHeaderMetadata.fileName) }
            else { ancillary[PageHeaderMetadata.fileName] = try headers.storedFile() }
            return true
        } catch { headerError = error.localizedDescription; return false }
    }
    private func moveSection(_ id: UUID, _ delta: Int) {
        guard let i = notebook.sections.firstIndex(where: { $0.id == id }), notebook.sections.indices.contains(i + delta) else { return }
        notebook.sections.swapAt(i, i + delta)
    }
    private func movePage(_ id: UUID, by delta: Int) {
        guard let si = notebook.sections.firstIndex(where: { $0.pageIDs.contains(id) }),
              let i = notebook.sections[si].pageIDs.firstIndex(of: id), notebook.sections[si].pageIDs.indices.contains(i + delta) else { return }
        notebook.sections[si].pageIDs.swapAt(i, i + delta)
    }
    private func duplicatePage(_ id: UUID) {
        guard var copy = notebook.pages[id], let si = notebook.sections.firstIndex(where: { $0.pageIDs.contains(id) }),
              let index = notebook.sections[si].pageIDs.firstIndex(of: id) else { return }
        copy.id = UUID(); copy.title += " (copy)"; copy.createdAt = Date(); copy.modifiedAt = Date()
        copy.elements = copy.elements.map { var element = $0; element.id = UUID(); return element }
        notebook.pages[copy.id] = copy; notebook.sections[si].pageIDs.insert(copy.id, at: index + 1); selectedPageID = copy.id
        if let headers = try? PageHeaderMetadata.read(ancillary[PageHeaderMetadata.fileName]) {
            let text = headers.text(for: id)
            if !text.isEmpty { updateSubheaders { $0.set(text, for: copy.id) } }
        }
    }
    private func deletePage(_ id: UUID) {
        guard let section = selectedSection, let i = section.pageIDs.firstIndex(of: id) else { return }
        deletePages(at: IndexSet(integer: i))
    }
    private func deleteSection(_ id: UUID) {
        guard let i = notebook.sections.firstIndex(where: { $0.id == id }) else { return }; deleteSections(at: IndexSet(integer: i))
    }
    private func addSection() {
        let section = Section(name: "Section \(notebook.sections.count + 1)",
                              colorHex: SectionTabColor.nextColor(in: notebook.sections))
        notebook.sections.append(section); selectedSectionID = section.id
    }
    private func addTemplatePage(_ page: Page, _ files: [String: StoredFile], _ subtitle: String) {
        guard let sid = selectedSectionID, let index = notebook.sections.firstIndex(where: { $0.id == sid }) else { return }
        guard updateSubheaders({ $0.set(subtitle, for: page.id) }) else { return }
        media.merge(files) { _, new in new }
        notebook.pages[page.id] = page
        notebook.sections[index].pageIDs.append(page.id)
        selectedPageID = page.id
    }
    private func addPage() {
        guard let sid = selectedSectionID, let i = notebook.sections.firstIndex(where: { $0.id == sid }) else { return }
        let page = Page(); notebook.pages[page.id] = page; notebook.sections[i].pageIDs.append(page.id); selectedPageID = page.id
    }
    private var canAddSubpage: Bool {
        guard let section = selectedSection, let id = selectedPageID else { return false }
        return PageHierarchy.subpageInsertionIndex(after: id, in: section, pages: notebook.pages) != nil
    }
    private func addSubpage() {
        guard let sid = selectedSectionID, let parentID = selectedPageID,
              let parent = notebook.pages[parentID], let i = notebook.sections.firstIndex(where: { $0.id == sid }),
              let insertion = PageHierarchy.subpageInsertionIndex(after: parentID, in: notebook.sections[i], pages: notebook.pages) else { return }
        var page = Page(); page.level = parent.level + 1
        notebook.pages[page.id] = page
        notebook.sections[i].pageIDs.insert(page.id, at: insertion)
        selectedPageID = page.id
    }
    private func deleteSections(at offsets: IndexSet) {
        let removed = offsets.map { notebook.sections[$0] }; notebook.sections.remove(atOffsets: offsets)
        for section in removed { for id in section.pageIDs { notebook.pages.removeValue(forKey: id) } }
        updateSubheaders { $0.remove(removed.flatMap(\.pageIDs)) }
        if removed.contains(where: { $0.id == selectedSectionID }) { selectedSectionID = notebook.sections.first?.id }
    }
    private func deletePages(at offsets: IndexSet) {
        guard let sid = selectedSectionID, let i = notebook.sections.firstIndex(where: { $0.id == sid }) else { return }
        let removed = offsets.map { notebook.sections[i].pageIDs[$0] }; notebook.sections[i].pageIDs.remove(atOffsets: offsets)
        for id in removed { notebook.pages.removeValue(forKey: id) }
        updateSubheaders { $0.remove(removed) }
        if removed.contains(selectedPageID ?? UUID()) { selectedPageID = notebook.sections[i].pageIDs.first }
    }
    private func selectInitial() {
        if selectedSectionID == nil { selectedSectionID = notebook.sections.first?.id }; selectFirstPage()
    }
    private func selectFirstPage() {
        guard let section = selectedSection else { selectedPageID = nil; return }
        if let current = selectedPageID, section.pageIDs.contains(current) { return }; selectedPageID = section.pageIDs.first
    }
}

private struct PageColumnWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 180
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
