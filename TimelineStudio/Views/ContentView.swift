import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \TimelineEvent.date) private var allEvents: [TimelineEvent]
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]
    @Query(sort: \TimelineDivider.date) private var dividers: [TimelineDivider]

    @State private var sidebarSelection: Set<String> = [SidebarID.all]
    @State private var searchText = ""
    @State private var isImporterPresented = false
    @State private var importAnalysis: ImportAnalysis?
    @State private var importError: String?
    @State private var isCategoryManagerPresented = false
    @State private var pendingSample: SampleSet?
    @State private var pendingPackage: ImportedTimelinePackage?
    @State private var packageMessage: String?
    @State private var showsAttachmentSheet = false
    @State private var showsAI = false

    @AppStorage(PrefKey.title) private var title = TimelineDefaults.title
    @AppStorage(PrefKey.subtitle) private var subtitle = ""
    @AppStorage(PrefKey.yAxisLabel) private var yAxisLabel = ""
    @AppStorage(PrefKey.showYAxis) private var showYAxis = false
    @AppStorage(PrefKey.background) private var background: CanvasBackground = .paper
    @AppStorage(PrefKey.layout) private var layout: TimelineLayout = .vertical
    @AppStorage(PrefKey.newestFirst) private var newestFirst = false
    @AppStorage(PrefKey.showTimes) private var showTimes = true

    private var lanes = LaneSettings()

    private var catalog: CategoryCatalog { CategoryCatalog(custom: customCategories) }

    /// nil means "all categories".
    private var activeCategoryIDs: Set<String>? {
        sidebarSelection.isEmpty || sidebarSelection.contains(SidebarID.all) ? nil : sidebarSelection
    }

    private var isFiltered: Bool {
        activeCategoryIDs != nil || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func filteredEvents(catalog: CategoryCatalog) -> [TimelineEvent] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let active = activeCategoryIDs
        var result = allEvents.filter { event in
            let category = catalog.category(for: event.categoryID)
            if let active, !active.contains(category.id) { return false }
            guard !query.isEmpty else { return true }
            return event.title.localizedCaseInsensitiveContains(query)
                || event.notes.localizedCaseInsensitiveContains(query)
                || event.location.localizedCaseInsensitiveContains(query)
                || category.name.localizedCaseInsensitiveContains(query)
        }
        if newestFirst { result.reverse() }
        return result
    }

    var body: some View {
        @Bindable var appState = appState
        let catalog = self.catalog
        let events = filteredEvents(catalog: catalog)

        Group {
            if appState.isPresenting {
                PresentationView(events: events, dividers: dividers, onExit: { appState.isPresenting = false })
                    .navigationTitle("Timeline Studio")
                    .transition(.opacity)
            } else {
                NavigationSplitView {
                    SidebarView(selection: $sidebarSelection, events: allEvents) {
                        isCategoryManagerPresented = true
                    }
                    .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
                } detail: {
                    detail(events: events)
                        .inspector(isPresented: $appState.isInspectorPresented) {
                            InspectorView(onManageCategories: { isCategoryManagerPresented = true },
                                          onExport: export,
                                          onExportPackage: exportPackage,
                                          onPresent: startPresentation)
                                .inspectorColumnWidth(min: 270, ideal: 300, max: 380)
                        }
                }
                .searchable(text: $searchText, placement: .toolbar, prompt: "Search Events")
                .toolbar { toolbar(catalog: catalog) }
                .navigationTitle("Timeline Studio")
                .navigationSubtitle(isFiltered ? "\(events.count) of \(allEvents.count) events" : "\(allEvents.count) events")
                .toolbarBackground(Color(nsColor: .windowBackgroundColor), for: .windowToolbar)
                .toolbarBackground(.visible, for: .windowToolbar)
            }
        }
        .sheet(item: $appState.editorTarget) { target in
            EventEditorView(target: target)
                .environment(\.categoryCatalog, catalog)
                .environment(\.modelContext, modelContext)
        }
        .sheet(item: $appState.dividerTarget) { target in
            DividerEditorView(target: target)
                .environment(\.modelContext, modelContext)
        }
        .sheet(item: $importAnalysis) { analysis in
            ImportPreviewView(analysis: analysis, existingEventCount: allEvents.count) { candidates, defaultCategoryID, defaultLane, plan in
                commitImport(candidates, defaultCategoryID: defaultCategoryID, defaultLane: defaultLane, plan: plan)
            }
            .environment(\.categoryCatalog, catalog)
        }
        .sheet(isPresented: $isCategoryManagerPresented) {
            CategoryManagerView()
                .environment(\.categoryCatalog, catalog)
                .environment(\.modelContext, modelContext)
        }
        .sheet(isPresented: $showsAI) {
            AIStudioView()
        }
        .fileImporter(isPresented: $isImporterPresented,
                      allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText]) { result in
            handleImport(result, catalog: catalog)
        }
        .alert("Couldn’t Import File", isPresented: Binding(
            get: { importError != nil }, set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .alert("Timeline with Files", isPresented: Binding(
            get: { packageMessage != nil }, set: { if !$0 { packageMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(packageMessage ?? "")
        }
        .sheet(isPresented: $showsAttachmentSheet) {
            if let event = allEvents.first(where: { $0.id == appState.attachmentEventID }) {
                AttachmentViewer(event: event) { appState.attachmentEventID = nil }
            }
        }
        .onChange(of: appState.attachmentEventID) { _, id in
            if !appState.isPresenting { showsAttachmentSheet = id != nil }
        }
        .onChange(of: showsAttachmentSheet) { _, shown in
            if !shown && !appState.isPresenting { appState.attachmentEventID = nil }
        }
        .onChange(of: appState.isPresenting) { _, presenting in
            if presenting { showsAttachmentSheet = false }
        }
        .confirmationDialog(pendingSample?.title ?? "", isPresented: Binding(
            get: { pendingSample != nil }, set: { if !$0 { pendingSample = nil } }
        ), titleVisibility: .visible, presenting: pendingSample) { sample in
            Button("Replace Current Events", role: .destructive) { loadSample(sample, replacing: true) }
            Button("Add to Current Events") { loadSample(sample, replacing: false) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Either way, your timelines are renamed to match the sample. Replacing also removes the \(allEvents.count) events you have now and changes the title.")
        }
        .confirmationDialog(pendingPackage?.package.title ?? "Open Timeline", isPresented: Binding(
            get: { pendingPackage != nil }, set: { if !$0 { pendingPackage = nil } }
        ), titleVisibility: .visible, presenting: pendingPackage) { imported in
            Button("Replace Current Events", role: .destructive) { applyPackage(imported, replacing: true) }
            Button("Add to Current Events") { applyPackage(imported, replacing: false) }
            Button("Cancel", role: .cancel) {}
        } message: { imported in
            Text("This timeline includes \(imported.events.count) events. Replacing removes the \(allEvents.count) events you have now. Linked files open from the copies inside the package.")
        }
        .onChange(of: appState.pendingAction) { _, action in
            guard let action else { return }
            appState.pendingAction = nil
            handle(action)
        }
        .onChange(of: sidebarSelection) { old, new in
            normalizeSelection(old: old, new: new)
        }
        .environment(\.categoryCatalog, catalog)
        .environment(\.eventActions, eventActions)
    }

    // MARK: - Detail

    @ViewBuilder
    private func detail(events: [TimelineEvent]) -> some View {
        VStack(spacing: 0) {
            if let notice = appState.aiNotice {
                aiConfirmation(notice)
            }
            timelineBody(events: events)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func aiConfirmation(_ notice: AIResultNotice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(notice.message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button {
                    appState.aiNotice = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Dismiss")
            }
            ForEach(notice.links) { link in
                Button(link.title) { openAIResult(link.id) }
                    .buttonStyle(.link)
                    .help("Open this event to review and edit")
            }
            if notice.didChange {
                Text("Undo is in the Edit menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !notice.detail.isEmpty {
                Text(notice.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func openAIResult(_ id: UUID) {
        if let event = allEvents.first(where: { $0.id == id }) ?? fetchedEvent(id) {
            appState.editorTarget = .edit(event)
        }
    }

    private func fetchedEvent(_ id: UUID) -> TimelineEvent? {
        let target = id
        var descriptor = FetchDescriptor<TimelineEvent>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    @ViewBuilder
    private func timelineBody(events: [TimelineEvent]) -> some View {
        if allEvents.isEmpty {
            EmptyTimelineView(
                onNew: { appState.editorTarget = .new(nil) },
                onImport: { isImporterPresented = true },
                onSample: loadSample)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background.fill, ignoresSafeAreaEdges: .all)
                .transition(.opacity)
        } else {
            TimelineCanvas(events: events, dividers: dividers, isFiltered: isFiltered, onClearFilters: clearFilters)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: events.map(\.id))
                .animation(.spring(response: 0.45, dampingFraction: 0.88), value: layout)
                .animation(.easeInOut(duration: 0.3), value: background)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbar(catalog: CategoryCatalog) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Picker("Layout", selection: $layout.animation(.spring(response: 0.45, dampingFraction: 0.88))) {
                ForEach(TimelineLayout.allCases) { layout in
                    Label(layout.title, systemImage: layout.symbol)
                        .labelStyle(.iconOnly)
                        .help("\(layout.title) Layout")
                        .tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .help("Timeline Layout")
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Show All Categories") { clearCategoryFilter() }
                Divider()
                ForEach(catalog.all) { category in
                    Toggle(isOn: filterBinding(for: category.id, catalog: catalog)) {
                        Label(category.name, systemImage: category.symbol)
                    }
                }
            } label: {
                Label("Filter", systemImage: activeCategoryIDs == nil
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
            .help("Filter by Type")
        }

        ToolbarItem(placement: .primaryAction) {
            Button { isImporterPresented = true } label: {
                Label("Import CSV", systemImage: "square.and.arrow.down")
            }
            .help("Import Events from CSV (⇧⌘I)")
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Export as PDF…") { export(.pdf) }
                Button("Export as PNG Image…") { export(.png) }
                Divider()
                Button("Export Timeline with Files…") { exportPackage() }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(allEvents.isEmpty)
            .help("Export Timeline")
        }

        ToolbarItem(placement: .primaryAction) {
            Button { showsAI = true } label: {
                Label("AI", systemImage: "sparkles")
            }
            .help("Describe a change. A link opens the event so you can review and edit it.")
        }

        ToolbarItem(placement: .primaryAction) {
            Button { startPresentation() } label: {
                Label("Present", systemImage: "play.fill")
            }
            .disabled(allEvents.isEmpty)
            .help("Present Timeline (⌥⌘P)")
        }

        ToolbarItem(placement: .primaryAction) {
            // Click for a new event; the arrow offers a chapter divider too.
            Menu {
                Button("New Event…") { appState.editorTarget = .new(nil) }
                Button("New Divider…") { appState.dividerTarget = .new(defaultDividerDate) }
            } label: {
                Label("New", systemImage: "plus")
            } primaryAction: {
                appState.editorTarget = .new(nil)
            }
            .help("New Event (⌘N). Click the arrow to add a divider (⇧⌘D).")
        }

        ToolbarItem(placement: .primaryAction) {
            Button { appState.isInspectorPresented.toggle() } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .help("Titles & Appearance (⌥⌘I)")
        }
    }

    private func filterBinding(for id: String, catalog: CategoryCatalog) -> Binding<Bool> {
        Binding(
            get: { activeCategoryIDs?.contains(id) ?? true },
            set: { isOn in
                var current = activeCategoryIDs ?? Set(catalog.all.map(\.id))
                if isOn { current.insert(id) } else { current.remove(id) }
                sidebarSelection = current.isEmpty || current.count == catalog.all.count ? [SidebarID.all] : current
            })
    }

    private func normalizeSelection(old: Set<String>, new: Set<String>) {
        if new.isEmpty {
            sidebarSelection = [SidebarID.all]
        } else if new.contains(SidebarID.all) && new.count > 1 {
            sidebarSelection = old.contains(SidebarID.all) ? new.subtracting([SidebarID.all]) : [SidebarID.all]
        }
    }

    private func clearCategoryFilter() {
        sidebarSelection = [SidebarID.all]
    }

    private func clearFilters() {
        clearCategoryFilter()
        searchText = ""
    }

    // MARK: - Actions

    private var eventActions: EventActions {
        let appState = appState
        let context = modelContext
        return EventActions(
            isExpanded: { appState.expandedEvents.contains($0) },
            toggle: { event in
                if appState.expandedEvents.contains(event.id) {
                    appState.expandedEvents.remove(event.id)
                } else {
                    appState.expandedEvents.insert(event.id)
                }
            },
            edit: { appState.editorTarget = .edit($0) },
            duplicate: { event in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    context.insert(event.duplicate())
                }
            },
            delete: { event in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                    context.delete(event)
                }
            },
            moveToLane: { event, lane in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { event.laneIndex = lane }
            },
            addDivider: { appState.dividerTarget = .new($0) },
            editDivider: { appState.dividerTarget = .edit($0) },
            deleteDivider: { divider in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { context.delete(divider) }
            },
            moveDivider: { divider, date in divider.date = date },
            openAttachment: { appState.attachmentEventID = $0.id })
    }

    /// New dividers from the toolbar or menu start just after the latest event; the editor lets you move them.
    private var defaultDividerDate: Date {
        (allEvents.last?.date ?? .now).addingTimeInterval(60)
    }

    private func handle(_ action: TimelineAction) {
        switch action {
        case .newEvent: appState.editorTarget = .new(nil)
        case .newDivider: appState.dividerTarget = .new(defaultDividerDate)
        case .importCSV: isImporterPresented = true
        case .exportPDF: export(.pdf)
        case .exportImage: export(.png)
        case .toggleInspector: appState.isInspectorPresented.toggle()
        case .loadSample: loadSample()
        case .expandAllNotes:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                appState.expandedEvents = Set(allEvents.map(\.id))
            }
        case .collapseAllNotes:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                appState.expandedEvents.removeAll()
            }
        case .manageCategories: isCategoryManagerPresented = true
        case .startPresentation: startPresentation()
        case .loadComparisonSample: requestSample(.comparison)
        case .loadThreeTimelineSample: requestSample(.threeTimelines)
        case .exportPackage: exportPackage()
        case .openPackage: openPackage()
        case .showAI: showsAI = true
        }
    }

    private func startPresentation() {
        guard !filteredEvents(catalog: catalog).isEmpty, !appState.isPresenting else {
            NSSound.beep()
            return
        }
        appState.isInspectorPresented = false
        withAnimation(.easeInOut(duration: 0.35)) { appState.isPresenting = true }
    }

    /// Multi-timeline samples are best seen on their own, so offer to replace what's there.
    private func requestSample(_ sample: SampleSet) {
        if allEvents.isEmpty {
            loadSample(sample, replacing: true)
        } else {
            pendingSample = sample
        }
    }

    private func loadSample(_ sample: SampleSet, replacing: Bool) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            if replacing {
                allEvents.forEach(modelContext.delete)
                dividers.forEach(modelContext.delete)
            }
            switch sample {
            case .comparison: SampleData.insertComparison(into: modelContext, replacingTitle: replacing)
            case .threeTimelines: SampleData.insertThreeTimelines(into: modelContext, replacingTitle: replacing)
            }
        }
        try? modelContext.save()
        clearFilters()
    }

    private func loadSample() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            SampleData.insert(into: modelContext)
        }
        if title.isEmpty || title == TimelineDefaults.title {
            title = SampleData.title
            subtitle = SampleData.subtitle
        }
    }

    private func handleImport(_ result: Result<URL, Error>, catalog: CategoryCatalog) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try CSVImporter.readText(at: url)
                let laneLabels = (0..<lanes.count).map(lanes.label)
                let analysis = try CSVImporter.analyze(text: text, fileName: url.lastPathComponent, catalog: catalog,
                                                       laneLabels: laneLabels)
                // Let the open panel finish dismissing before presenting the preview sheet.
                DispatchQueue.main.async { importAnalysis = analysis }
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func commitImport(_ candidates: [ImportCandidate], defaultCategoryID: String, defaultLane: Int, plan: ImportLanePlan) {
        clearFilters()
        if let names = plan.laneNames {
            applyImportedLanes(names)
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            if plan.replaceExisting {
                allEvents.forEach(modelContext.delete)
            }
            for candidate in candidates where candidate.include && candidate.status != .error {
                guard let date = candidate.date else { continue }
                modelContext.insert(TimelineEvent(
                    date: date, isAllDay: candidate.isAllDay,
                    categoryID: candidate.categoryID ?? defaultCategoryID,
                    title: candidate.title, notes: candidate.notes,
                    location: candidate.location, amount: candidate.amount,
                    laneIndex: candidate.laneIndex ?? defaultLane))
            }
        }
        try? modelContext.save()
    }

    /// Renames the open timelines to the names from the file, in that order.
    private func applyImportedLanes(_ names: [String]) {
        let labels = Array(names.prefix(Lanes.maxCount))
        guard !labels.isEmpty else { return }
        let defaults = UserDefaults.standard
        defaults.set(labels.count, forKey: PrefKey.laneCount)
        defaults.set(Lanes.encodedOrder(Array(labels.indices)), forKey: PrefKey.laneOrder)
        for (index, label) in labels.enumerated() {
            defaults.set(label, forKey: PrefKey.laneLabel(index))
        }
    }

    private func export(_ format: ExportFormat) {
        let events = filteredEvents(catalog: catalog)
        guard !events.isEmpty else {
            NSSound.beep()
            return
        }
        let view = TimelineExportView(
            title: title, subtitle: subtitle,
            yAxisLabel: showYAxis ? yAxisLabel : "",
            background: background, layout: layout,
            events: events, dividers: dividers, showTimes: showTimes)
            .environment(\.categoryCatalog, catalog)
        TimelineExporter.export(view, format: format, suggestedName: title.isEmpty ? "Timeline" : title)
    }

    private func exportPackage() {
        guard !allEvents.isEmpty else {
            NSSound.beep()
            return
        }
        var records: [PackageEvent] = []
        var files: [PackageFile] = []
        for event in allEvents {
            let packed = TimelinePackageIO.packed(event)
            records.append(packed.record)
            if let file = packed.file { files.append(file) }
        }
        let package = TimelinePackage(
            title: title, subtitle: subtitle, yAxisLabel: yAxisLabel, showYAxis: showYAxis,
            background: background.rawValue, layout: layout.rawValue, newestFirst: newestFirst,
            showTimes: showTimes, laneCount: lanes.count, laneLabelSide: lanes.side.rawValue,
            laneLabels: (0..<Lanes.maxCount).map(lanes.label), laneOrder: lanes.order,
            categories: customCategories.map {
                PackageCategory(id: $0.id, name: $0.name, symbol: $0.symbol, tint: $0.tintRaw)
            },
            events: records,
            dividers: dividers.map { PackageDivider(id: $0.id, date: $0.date, title: $0.title) }
        )
        let suggested = title.isEmpty ? "Timeline" : title
        let linked = files.count
        TimelinePackagePanels.save(suggestedName: suggested) { url in
            Task.detached {
                let outcome: Result<[PackageFailure], Error>
                do {
                    outcome = .success(try TimelinePackageIO.write(package, files: files, to: url))
                } catch {
                    outcome = .failure(error)
                }
                await MainActor.run {
                    switch outcome {
                    case .success(let failures):
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                        packageMessage = TimelinePackageIO.summary(copied: linked - failures.count, failures: failures)
                    case .failure(let error):
                        packageMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func openPackage() {
        TimelinePackagePanels.open { url in
            do {
                let root = url.lastPathComponent == TimelinePackage.manifestName ? url.deletingLastPathComponent() : url
            let imported = try TimelinePackageIO.read(at: root)
                if allEvents.isEmpty {
                    applyPackage(imported, replacing: true)
                } else {
                    pendingPackage = imported
                }
            } catch {
                packageMessage = error.localizedDescription
            }
        }
    }

    private func applyPackage(_ imported: ImportedTimelinePackage, replacing: Bool) {
        let package = imported.package
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            if replacing {
                allEvents.forEach(modelContext.delete)
                dividers.forEach(modelContext.delete)
                applyPackageSettings(package)
            }
            for category in package.categories where !EventCategory.builtIns.contains(where: { $0.id == category.id }) {
                guard !customCategories.contains(where: { $0.id == category.id }) else { continue }
                let created = CustomCategory(name: category.name, symbol: category.symbol,
                                             tint: CategoryTint(rawValue: category.tint) ?? .gray)
                created.id = category.id
                modelContext.insert(created)
            }
            for importedEvent in imported.events {
                modelContext.insert(TimelinePackageIO.makeEvent(importedEvent))
            }
            for divider in package.dividers {
                modelContext.insert(TimelineDivider(date: divider.date, title: divider.title))
            }
        }
        try? modelContext.save()
        clearFilters()
        if !imported.missingFiles.isEmpty {
            packageMessage = "Opened \(package.title). These files were missing from the package: \(imported.missingFiles.joined(separator: ", "))."
        }
    }

    private func applyPackageSettings(_ package: TimelinePackage) {
        title = package.title
        subtitle = package.subtitle
        yAxisLabel = package.yAxisLabel
        showYAxis = package.showYAxis
        if let background = CanvasBackground(rawValue: package.background) { self.background = background }
        if let layout = TimelineLayout(rawValue: package.layout) { self.layout = layout }
        newestFirst = package.newestFirst
        showTimes = package.showTimes
        let defaults = UserDefaults.standard
        defaults.set(min(max(package.laneCount, 1), Lanes.maxCount), forKey: PrefKey.laneCount)
        defaults.set(package.laneLabelSide, forKey: PrefKey.laneLabelSide)
        defaults.set(Lanes.encodedOrder(package.laneOrder), forKey: PrefKey.laneOrder)
        for (index, label) in package.laneLabels.enumerated() where index < Lanes.maxCount {
            defaults.set(label, forKey: PrefKey.laneLabel(index))
        }
    }
}
