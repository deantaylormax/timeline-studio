#if DEBUG
import SwiftUI
import SwiftData

/// Debug-only: launch with `-snapshot` to render key screens offscreen into PNGs and quit.
/// Useful for visual checks in CI or when screen capture isn't available.
@MainActor
enum SnapshotHarness {
    /// In-memory stores must outlive the views using their events.
    private static var retained: [ModelContainer] = []

    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-snapshot") }

    static func run() {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("snapshots")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let keys = [PrefKey.title, PrefKey.subtitle, PrefKey.layout, PrefKey.background, PrefKey.showYAxis,
                    PrefKey.yAxisLabel, PrefKey.laneCount, PrefKey.laneLabelSide, PrefKey.laneOrder,
                    PrefKey.laneLabel(0), PrefKey.laneLabel(1), PrefKey.laneLabel(2),
                    PrefKey.newestFirst, PrefKey.presentationExit]
        let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { UserDefaults.standard.set(value, forKey: key) } }

        let empty = try! ModelContainer(for: TimelineEvent.self, CustomCategory.self, TimelineDivider.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let filled = try! ModelContainer(for: TimelineEvent.self, CustomCategory.self, TimelineDivider.self,
                                         configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        retained += [empty, filled]
        SampleData.insert(into: filled.mainContext)
        // The samples carry no dividers; add one here so the renders show them.
        filled.mainContext.insert(TimelineDivider(
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 1)) ?? .now,
            title: "Chapter 2 · Design & build"))
        let events = (try? filled.mainContext.fetch(FetchDescriptor<TimelineEvent>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let filledDividers = (try? filled.mainContext.fetch(FetchDescriptor<TimelineDivider>())) ?? []

        let defaults = UserDefaults.standard
        // The early renders are single-timeline checks, whatever the app is currently set to.
        defaults.set(1, forKey: PrefKey.laneCount)
        defaults.set(Lanes.encodedOrder([0, 1, 2]), forKey: PrefKey.laneOrder)
        defaults.set(SampleData.title, forKey: PrefKey.title)
        defaults.set(SampleData.subtitle, forKey: PrefKey.subtitle)
        let windowSize = CGSize(width: 1280, height: 840)

        func app(_ container: ModelContainer, inspector: Bool = false) -> some View {
            let state = AppState()
            state.isInspectorPresented = inspector
            state.expandedEvents = Set(events.prefix(2).map(\.id))
            return ContentView().environment(state).modelContainer(container)
        }

        defaults.set(TimelineLayout.vertical.rawValue, forKey: PrefKey.layout)
        defaults.set(CanvasBackground.paper.rawValue, forKey: PrefKey.background)
        snap("01-empty", size: windowSize, dark: false, app(empty), in: directory)
        snap("02-vertical-light", size: windowSize, dark: false, app(filled), in: directory)
        snap("03-vertical-dark", size: windowSize, dark: true, app(filled), in: directory)

        defaults.set(TimelineLayout.alternating.rawValue, forKey: PrefKey.layout)
        defaults.set(CanvasBackground.blueGray.rawValue, forKey: PrefKey.background)
        defaults.set(true, forKey: PrefKey.showYAxis)
        defaults.set("Momentum", forKey: PrefKey.yAxisLabel)
        snap("04-alternating-inspector", size: windowSize, dark: false, app(filled, inspector: true), in: directory)

        defaults.set(TimelineLayout.horizontal.rawValue, forKey: PrefKey.layout)
        defaults.set(CanvasBackground.gradient.rawValue, forKey: PrefKey.background)
        defaults.set(false, forKey: PrefKey.showYAxis)
        snap("05-horizontal", size: windowSize, dark: false, app(filled), in: directory)
        snap("06-horizontal-dark", size: windowSize, dark: true, app(filled), in: directory)

        func present(_ step: Int) -> some View {
            PresentationView(events: events, dividers: filledDividers, onExit: {}, initialStep: step, managesFullScreen: false)
        }
        snap("13-present-horizontal", size: windowSize, dark: false, present(4), in: directory)
        defaults.set(TimelineLayout.vertical.rawValue, forKey: PrefKey.layout)
        defaults.set(CanvasBackground.paper.rawValue, forKey: PrefKey.background)
        snap("14-present-intro", size: windowSize, dark: false, present(-1), in: directory)
        snap("15-present-first", size: windowSize, dark: false, present(0), in: directory)
        snap("16-present-step4", size: windowSize, dark: false, present(4), in: directory)
        snap("17-present-step5-dark", size: windowSize, dark: true, present(5), in: directory)
        for exit in [PresentationExit.blurAndDim, .recede, .slideAside, .grayscale] {
            defaults.set(exit.rawValue, forKey: PrefKey.presentationExit)
            snap("18-exit-\(exit.rawValue)", size: windowSize, dark: false, present(4), in: directory)
        }
        defaults.removeObject(forKey: PrefKey.presentationExit)

        // Parallel timelines: the texts-vs-calls sample.
        let comparison = try! ModelContainer(for: TimelineEvent.self, CustomCategory.self, TimelineDivider.self,
                                             configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        defaults.set(TimelineDefaults.title, forKey: PrefKey.title)
        retained.append(comparison)
        SampleData.insertComparison(into: comparison.mainContext)
        let comparisonEvents = (try? comparison.mainContext.fetch(
            FetchDescriptor<TimelineEvent>(sortBy: [SortDescriptor(\.date)]))) ?? []
        defaults.set("Text Messages - Mom, Dad & the moving crew", forKey: PrefKey.laneLabel(0))
        defaults.set("Phone Calls - Movers & building manager", forKey: PrefKey.laneLabel(1))
        defaults.set(TimelineLayout.vertical.rawValue, forKey: PrefKey.layout)
        snap("19-lanes-vertical", size: windowSize, dark: false, app(comparison), in: directory)
        snap("21-present-lanes-vertical", size: windowSize, dark: false,
             PresentationView(events: comparisonEvents, onExit: {}, initialStep: 3, managesFullScreen: false), in: directory)
        defaults.set(TimelineLayout.horizontal.rawValue, forKey: PrefKey.layout)
        snap("20-lanes-horizontal", size: windowSize, dark: false, app(comparison), in: directory)
        snap("22-present-lanes-horizontal", size: windowSize, dark: false,
             PresentationView(events: comparisonEvents, onExit: {}, initialStep: 3, managesFullScreen: false), in: directory)
        defaults.set(LaneLabelSide.trailing.rawValue, forKey: PrefKey.laneLabelSide)
        defaults.set(true, forKey: PrefKey.newestFirst)
        snap("23-present-lanes-horizontal-right", size: windowSize, dark: true,
             PresentationView(events: comparisonEvents, onExit: {}, initialStep: 3, managesFullScreen: false), in: directory)
        defaults.set(false, forKey: PrefKey.newestFirst)

        // The three-timeline sample (emails, texts, meetings), plus a check that its CSV twin imports cleanly.
        let three = try! ModelContainer(for: TimelineEvent.self, CustomCategory.self, TimelineDivider.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        retained.append(three)
        SampleData.insertThreeTimelines(into: three.mainContext, replacingTitle: true)
        three.mainContext.insert(TimelineDivider(
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12, minute: 30)) ?? .now,
            title: "Chapter 2 · The counter-offer"))
        let threeEvents = (try? three.mainContext.fetch(FetchDescriptor<TimelineEvent>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let threeDividers = (try? three.mainContext.fetch(FetchDescriptor<TimelineDivider>())) ?? []
        defaults.set(LaneLabelSide.leading.rawValue, forKey: PrefKey.laneLabelSide)
        defaults.set(TimelineLayout.vertical.rawValue, forKey: PrefKey.layout)
        snap("26-three-sample-canvas", size: windowSize, dark: false, app(three), in: directory)
        snap("27-three-sample-present-vertical", size: windowSize, dark: false,
             PresentationView(events: threeEvents, dividers: threeDividers, onExit: {}, initialStep: 9, managesFullScreen: false), in: directory)
        defaults.set(TimelineLayout.horizontal.rawValue, forKey: PrefKey.layout)
        snap("28-three-sample-present-horizontal", size: windowSize, dark: true,
             PresentationView(events: threeEvents, dividers: threeDividers, onExit: {}, initialStep: 9, managesFullScreen: false), in: directory)
        let fullScreen = CGSize(width: 1512, height: 982)
        for step in [0, 4, 6] {
            snap("29-three-horizontal-fullscreen-step\(step + 1)", size: fullScreen, dark: false,
                 PresentationView(events: threeEvents, dividers: threeDividers, onExit: {}, initialStep: step, managesFullScreen: false), in: directory)
        }
        snap("30-three-horizontal-window-step7", size: windowSize, dark: false,
             PresentationView(events: threeEvents, dividers: threeDividers, onExit: {}, initialStep: 6, managesFullScreen: false), in: directory)
        defaults.set(TimelineLayout.vertical.rawValue, forKey: PrefKey.layout)
        snap("31-three-vertical-fullscreen-step7", size: fullScreen, dark: false,
             PresentationView(events: threeEvents, dividers: threeDividers, onExit: {}, initialStep: 6, managesFullScreen: false), in: directory)
        defaults.set(PresentationExit.blurAndDim.rawValue, forKey: PrefKey.presentationExit)
        defaults.set(TimelineLayout.horizontal.rawValue, forKey: PrefKey.layout)
        snap("32-three-horizontal-blurdim-step12", size: fullScreen, dark: true,
             PresentationView(events: threeEvents, dividers: threeDividers, onExit: {}, initialStep: 11, managesFullScreen: false), in: directory)
        defaults.removeObject(forKey: PrefKey.presentationExit)
        if let csv = ProcessInfo.processInfo.environment["SNAPSHOT_CSV3"],
           let analysis = try? CSVImporter.analyze(text: csv, fileName: "three-timelines.csv", catalog: CategoryCatalog(),
                                                   laneLabels: ["Emails", "Text Messages", "Meetings"]) {
            let lanes = analysis.candidates.map { $0.laneIndex.map(String.init) ?? "-" }.joined()
            let types = analysis.candidates.map { $0.categoryID ?? "-" }
            let matchesCode = zip(analysis.candidates, SampleData.threeTimelineItems).allSatisfy { candidate, item in
                candidate.date == item.date && candidate.laneIndex == item.lane && candidate.categoryID == item.categoryID
                    && candidate.title == item.title
            }
            print("CSV3: rows \(analysis.candidates.count), issues \(analysis.candidates.flatMap(\.issues)), lanes \(lanes), types \(Set(types)), matches built-in sample: \(matchesCode)")
        }

        // Three timelines from the main sample, split by type.
        for event in events {
            event.laneIndex = [EventCategory.messageID, EventCategory.emailID].contains(event.categoryID) ? 0
                : [EventCategory.callID, EventCategory.meetingID].contains(event.categoryID) ? 1 : 2
        }
        defaults.set(3, forKey: PrefKey.laneCount)
        defaults.set(LaneLabelSide.leading.rawValue, forKey: PrefKey.laneLabelSide)
        defaults.set("Messages", forKey: PrefKey.laneLabel(0))
        defaults.set("Calls & Meetings", forKey: PrefKey.laneLabel(1))
        defaults.set("Everything Else", forKey: PrefKey.laneLabel(2))
        defaults.set(TimelineLayout.vertical.rawValue, forKey: PrefKey.layout)
        snap("24-three-lanes-vertical", size: windowSize, dark: true, app(filled), in: directory)
        snap("25-present-three-lanes", size: windowSize, dark: false,
             PresentationView(events: events, dividers: filledDividers, onExit: {}, initialStep: 6, managesFullScreen: false), in: directory)
        for event in events { event.laneIndex = 0 }
        defaults.set(1, forKey: PrefKey.laneCount)

        snap("07-editor", size: CGSize(width: 560, height: 780), dark: false,
             EventEditorView(target: .edit(events[4])).modelContainer(filled), in: directory)
        snap("08-editor-dark", size: CGSize(width: 560, height: 780), dark: true,
             EventEditorView(target: .new(nil)).modelContainer(filled), in: directory)

        let csv = ProcessInfo.processInfo.environment["SNAPSHOT_CSV"]
        if let csv, let analysis = try? CSVImporter.analyze(text: csv, fileName: "sample-events.csv", catalog: CategoryCatalog()) {
            snap("09-import", size: CGSize(width: 900, height: 600), dark: false,
                 ImportPreviewView(analysis: analysis) { _, _, _, _ in }, in: directory)
        }
        snap("11-inspector", size: CGSize(width: 300, height: 840), dark: false,
             InspectorView(onManageCategories: {}, onExport: { _ in }, onExportPackage: {}, onPresent: {}).background(Color(nsColor: .windowBackgroundColor)), in: directory)
        snap("12-sidebar", size: CGSize(width: 240, height: 640), dark: false,
             SidebarView(selection: .constant([EventCategory.meetingID]), events: events, onManageCategories: {})
                .background(Color(nsColor: .windowBackgroundColor)), in: directory)
        snap("10-categories", size: CGSize(width: 520, height: 680), dark: false,
             CategoryManagerView().modelContainer(filled), in: directory)

        for layout in TimelineLayout.allCases {
            let export = TimelineExportView(title: SampleData.title, subtitle: SampleData.subtitle,
                                            yAxisLabel: layout == .vertical ? "Momentum" : "",
                                            background: .paper, layout: layout, events: events, dividers: filledDividers, showTimes: true)
                .environment(\.colorScheme, .light)
            let url = directory.appendingPathComponent("export-\(layout.rawValue).png")
            try? TimelineExporter.write(export, format: .png, to: url, appearance: NSAppearance(named: .aqua)!)
        }
        let pdf = TimelineExportView(title: SampleData.title, subtitle: SampleData.subtitle, yAxisLabel: "",
                                     background: .warmBeige, layout: .vertical, events: events, dividers: filledDividers, showTimes: true)
        try? TimelineExporter.write(pdf, format: .pdf, to: directory.appendingPathComponent("export.pdf"),
                                    appearance: NSAppearance(named: .aqua)!)

        print("SNAPSHOTS: \(directory.path)")
    }

    private static func snap<V: View>(_ name: String, size: CGSize, dark: Bool, _ view: V, in directory: URL) {
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20000, y: -20000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(ProcessInfo.processInfo.environment["SNAPSHOT_WAIT"].flatMap(Double.init) ?? 1.2))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("\(name).png"))
        window.orderOut(nil)
    }
}
#endif

#if DEBUG
/// Debug-only: launch with `-presentTrace` to step through a presentation offscreen
/// and log every movement of the track, to check that each step settles once.
@MainActor
enum PresentationTrace {
    static let advance = Notification.Name("PresentationTraceAdvance")
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-presentTrace") }
    private static var start = Date()
    /// In-memory stores must outlive the views using their events.
    private static var retained: [ModelContainer] = []

    static func log(_ message: String) {
        guard isRequested else { return }
        print(String(format: "[%6.3fs] %@", Date().timeIntervalSince(start), message))
    }

    static func run() {
        let container = try! ModelContainer(for: TimelineEvent.self, CustomCategory.self, TimelineDivider.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        retained.append(container)
        let useThree = ProcessInfo.processInfo.arguments.contains("three")
        let useLanes = useThree || ProcessInfo.processInfo.arguments.contains("lanes")
        let keys = [PrefKey.laneCount, PrefKey.laneLabel(0), PrefKey.laneLabel(1), PrefKey.laneLabel(2),
                    PrefKey.title, PrefKey.subtitle]
        let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { UserDefaults.standard.set(value, forKey: key) } }
        if useThree {
            SampleData.insertThreeTimelines(into: container.mainContext)
        } else if useLanes {
            SampleData.insertComparison(into: container.mainContext)
        } else {
            UserDefaults.standard.set(1, forKey: PrefKey.laneCount)
            SampleData.insert(into: container.mainContext)
        }
        let events = (try? container.mainContext.fetch(FetchDescriptor<TimelineEvent>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let dividers = (try? container.mainContext.fetch(FetchDescriptor<TimelineDivider>())) ?? []
        let size = CGSize(width: 1280, height: 840)
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20000, y: -20000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: PresentationView(events: events, dividers: dividers, onExit: {}, initialStep: 0,
                                                                      managesFullScreen: false)
            .frame(width: size.width, height: size.height))
        window.orderFrontRegardless()

        start = Date()
        log("presented at step 1")
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        for step in 2...(useThree ? 20 : useLanes ? 8 : 6) {
            log("--- advance to step \(step)")
            NotificationCenter.default.post(name: advance, object: nil)
            RunLoop.main.run(until: Date().addingTimeInterval(2))
        }
        log("done")
    }
}
#endif

#if DEBUG
/// Debug-only: launch with `-tagTest` to click, type into and commit a timeline label offscreen,
/// using real mouse and key events, and print what was saved.
@MainActor
enum LaneTagTest {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-tagTest") }

    private struct Host: View {
        var lanes = LaneSettings()
        var body: some View {
            // Same text width as a label in the horizontal view's gutter.
            LaneTag(label: lanes.label(0), index: 0, side: .leading, text: lanes.labelBinding(0),
                    maxTextWidth: LaneMetrics.labelGutter - 32 - 27)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CanvasBackground.paper.baseColor)
        }
    }

    static func run() {
        let key = PrefKey.laneLabel(0)
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.set("Messages", forKey: key)

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("snapshots")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let size = CGSize(width: 420, height: 160)
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20000, y: -20000), size: size),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: Host())
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settle()

        func label() -> String { UserDefaults.standard.string(forKey: key) ?? "(nil)" }
        func snap(_ name: String) {
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("\(name).png"))
        }
        func click() {
            let point = CGPoint(x: size.width / 2, y: size.height / 2)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                if let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                                  windowNumber: window.windowNumber, context: nil,
                                                  eventNumber: 0, clickCount: 1, pressure: 1) {
                    window.sendEvent(event)
                    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                }
            }
            settle()
        }
        func type(_ text: String, keyCode: UInt16 = 0) {
            for character in text {
                for kind in [NSEvent.EventType.keyDown, .keyUp] {
                    if let event = NSEvent.keyEvent(with: kind, location: .zero, modifierFlags: [],
                                                    timestamp: ProcessInfo.processInfo.systemUptime,
                                                    windowNumber: window.windowNumber, context: nil,
                                                    characters: String(character),
                                                    charactersIgnoringModifiers: String(character),
                                                    isARepeat: false, keyCode: keyCode) {
                        window.sendEvent(event)
                    }
                }
            }
            settle()
        }
        func selectAll() {
            if let editor = window.firstResponder as? NSTextView { editor.selectAll(nil) }
        }

        snap("tag-1-idle")
        click()
        print("TAGTEST editing after click: \(window.firstResponder is NSTextView)")
        if let editor = window.firstResponder as? NSTextView {
            print("TAGTEST field text \"\(editor.string)\", selection \(NSStringFromRange(editor.selectedRange()))")
        }
        snap("tag-2-editing")
        type(" & Texts")
        snap("tag-3-typed")
        type("\r", keyCode: 36)
        print("TAGTEST after Return: \(label())")
        snap("tag-4-saved")

        click()
        type(" DRAFT")
        type("\u{1b}", keyCode: 53)
        print("TAGTEST after Esc (should be unchanged): \(label())")

        click()
        selectAll()
        type("\u{7f}", keyCode: 51)
        type("\r", keyCode: 36)
        print("TAGTEST after clearing: stored \"\(label())\", shown \"\(LaneSettings().label(0))\"")
        snap("tag-5-cleared")

        // Long names wrap rather than being cut off, both at rest and while editing.
        UserDefaults.standard.set("Text Messages - Mom", forKey: key)
        settle()
        click()
        type(", Dad & the moving crew")
        snap("tag-6-long-editing")
        type("\r", keyCode: 36)
        print("TAGTEST long name saved: \(label())")
        snap("tag-7-long-saved")
    }

    private static func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    }
}
#endif

#if DEBUG
/// Debug-only: launch with `-dividerTest` to click and drag a divider with real mouse events
/// and print what happened.
@MainActor
enum DividerTest {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-dividerTest") }
    private static var retained: [ModelContainer] = []

    private struct Host: View {
        @Query(sort: \TimelineEvent.date) private var events: [TimelineEvent]
        @Query(sort: \TimelineDivider.date) private var dividers: [TimelineDivider]

        var body: some View {
            VerticalTimelineView(months: TimelineGrouping.months(from: TimelineGrouping.entries(
                                    events: events, dividers: dividers, newestFirst: false)),
                                 alternating: false, showTimes: true)
                .environment(\.eventActions, EventActions(
                    editDivider: { print("DIVTEST click opened the editor for \"\($0.title)\"") },
                    moveDivider: { divider, date in
                        divider.date = date
                        print("DIVTEST drop moved the divider to \(date.formatted(date: .abbreviated, time: .shortened))")
                    }))
                .background(CanvasBackground.paper.baseColor)
        }
    }

    static func run() {
        let container = try! ModelContainer(for: TimelineEvent.self, CustomCategory.self, TimelineDivider.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        retained.append(container)
        SampleData.insert(into: container.mainContext)
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 8)) ?? .now
        container.mainContext.insert(TimelineDivider(date: start, title: "Test chapter"))

        let size = CGSize(width: 1100, height: 760)
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20000, y: -20000), size: size),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: Host().modelContainer(container))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        settle(1.0)

        func order() -> String {
            let events = (try? container.mainContext.fetch(FetchDescriptor<TimelineEvent>())) ?? []
            let dividers = (try? container.mainContext.fetch(FetchDescriptor<TimelineDivider>())) ?? []
            return TimelineGrouping.entries(events: events.sorted { $0.date < $1.date }, dividers: dividers, newestFirst: false)
                .prefix(9).map { entry -> String in
                    switch entry {
                    case .event(let event): return event.title
                    case .divider(let divider): return "[\(divider.title)]"
                    }
                }.joined(separator: " → ")
        }

        print("DIVTEST order before: \(order())")
        snap(host, "divider-1-before")
        let dividers = (try? container.mainContext.fetch(FetchDescriptor<TimelineDivider>())) ?? []
        guard let divider = dividers.first else { return }

        // SwiftUI's drag gesture can't be driven by synthetic events, so check what a drop at a given
        // distance would resolve to, using the real measured layout, then apply it as the drop would.
        guard let resolver = DividerDragDebug.resolver(containing: divider.id),
              let center = resolver.center(of: divider.id) else {
            print("DIVTEST divider not measured")
            return
        }
        print("DIVTEST measured \(resolver.frames.count) entries; divider centre at y=\(Int(center))")
        for distance in [-80.0, 120, 300, 520] {
            let date = resolver.date(at: center + distance, excluding: divider.id)
            print("DIVTEST drop \(Int(distance))pt → \(date?.formatted(date: .abbreviated, time: .shortened) ?? "nil")")
        }
        if let date = resolver.date(at: center + 300, excluding: divider.id) {
            divider.date = date
            settle(0.8)
            print("DIVTEST order after a 300pt drop: \(order())")
            snap(host, "divider-3-after")
        }
    }

    /// The dashed line is the row with the most accent-coloured pixels.
    private static func findDividerLine(in view: NSView) -> CGFloat? {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        var best: (row: Int, count: Int) = (0, 0)
        for row in 0..<rep.pixelsHigh {
            var count = 0
            for column in stride(from: 0, to: rep.pixelsWide, by: 2) {
                guard let color = rep.colorAt(x: column, y: row)?.usingColorSpace(.sRGB) else { continue }
                if color.blueComponent - color.redComponent > 0.18 && color.blueComponent > 0.6 { count += 1 }
            }
            if count > best.count { best = (row, count) }
        }
        guard best.count > 50 else { return nil }
        let scale = CGFloat(rep.pixelsHigh) / view.bounds.height
        return view.bounds.height - CGFloat(best.row) / scale
    }

    /// Delivers a mouse event through the application (as real input is), addressed to the test window.
    /// Nothing is posted to the system, so the real pointer never moves.
    private static func send(_ type: NSEvent.EventType, at point: CGPoint, in window: NSWindow) {
        if let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                                          timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: window.windowNumber, context: nil,
                                          eventNumber: 0, clickCount: 1,
                                          pressure: type == .leftMouseUp ? 0 : 1) {
            NSApp.sendEvent(event)
        }
        settle(0.03)
    }

    private static func snap(_ view: NSView, _ name: String) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("snapshots")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("\(name).png"))
    }

    private static func settle(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
}
#endif

#if DEBUG
/// Debug-only maintenance: `-sampleDividerCleanup` lists the dividers saved in the app's own store;
/// add `apply` to delete the four chapter lines an earlier version of the three-timeline sample added.
/// Only exact title matches are touched, so dividers you made yourself are left alone.
@MainActor
enum SampleDividerCleanup {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-sampleDividerCleanup") }
    static let oldSampleTitles: Set<String> = [
        "Chapter 1 · First drafts", "Chapter 2 · The counter-offer", "Chapter 3 · Negotiation", "Chapter 4 · Signed",
    ]

    static func run() {
        let apply = ProcessInfo.processInfo.arguments.contains("apply")
        guard let container = try? ModelContainer(for: TimelineEvent.self, CustomCategory.self, TimelineDivider.self) else {
            print("CLEANUP couldn't open the store")
            return
        }
        let context = container.mainContext
        let dividers = (try? context.fetch(FetchDescriptor<TimelineDivider>(sortBy: [SortDescriptor(\.date)]))) ?? []
        print("CLEANUP \(dividers.count) divider(s) saved:")
        for divider in dividers {
            let match = oldSampleTitles.contains(divider.title)
            print("CLEANUP   \(match ? "[old sample]" : "[yours]     ") \(divider.title) — \(divider.date.formatted(date: .abbreviated, time: .shortened))")
        }
        guard apply else { return }
        let matches = dividers.filter { oldSampleTitles.contains($0.title) }
        matches.forEach(context.delete)
        do {
            try context.save()
            let remaining = (try? context.fetchCount(FetchDescriptor<TimelineDivider>())) ?? -1
            print("CLEANUP deleted \(matches.count); \(remaining) divider(s) remain")
        } catch {
            print("CLEANUP save failed: \(error)")
        }
    }
}
#endif
