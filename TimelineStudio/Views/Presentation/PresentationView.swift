import SwiftUI
import AppKit

/// The time model behind a presentation: a shared clock steps through every distinct moment,
/// and each timeline (lane) is positioned relative to that clock.
struct PresentationModel {
    /// Entries per lane, in presentation order. Dividers appear in every lane, so they span them all.
    let lanes: [[TimelineEntry]]
    /// Each distinct moment in presentation order; entries at the same instant are revealed together.
    /// A divider is its own moment, so it gets its own step.
    let steps: [Date]
    private let stepOf: [UUID: Int]

    init(events: [TimelineEvent], dividers: [TimelineDivider], newestFirst: Bool,
         laneCount: Int, laneOf: (TimelineEvent) -> Int) {
        var lanes = Array(repeating: [TimelineEntry](), count: max(laneCount, 1))
        var steps: [Date] = []
        var stepOf: [UUID: Int] = [:]
        for entry in TimelineGrouping.entries(events: events, dividers: dividers, newestFirst: newestFirst) {
            if steps.last != entry.date { steps.append(entry.date) }
            stepOf[entry.id] = steps.count - 1
            switch entry {
            case .event(let event):
                lanes[min(max(laneOf(event), 0), lanes.count - 1)].append(entry)
            case .divider:
                for lane in lanes.indices { lanes[lane].append(entry) }
            }
        }
        self.lanes = lanes
        self.steps = steps
        self.stepOf = stepOf
    }

    func step(of entry: TimelineEntry) -> Int { stepOf[entry.id] ?? .max }
    func isRevealed(_ entry: TimelineEntry, at step: Int) -> Bool { self.step(of: entry) <= step }
    func isFocused(_ entry: TimelineEntry, at step: Int) -> Bool { self.step(of: entry) == step }

    /// Index of the lane's most recently revealed event, or -1 if the lane hasn't started.
    func lastRevealedIndex(inLane lane: Int, at step: Int) -> Int {
        (lanes[lane].firstIndex { self.step(of: $0) > step } ?? lanes[lane].count) - 1
    }

    /// Where a lane should be centered, as a fractional index into its events.
    ///
    /// The lane that owns the current moment sits exactly on that event. Any other lane sits
    /// between its previous and next events in proportion to elapsed time: if its last event was
    /// 12:55, its next is 1:03 and the clock reads 1:00, it is 5/8 of the way along.
    /// -1 is a virtual slot just before the lane's first event.
    func position(ofLane lane: Int, at step: Int) -> Double? {
        let entries = lanes[lane]
        guard step >= 0, steps.indices.contains(step), !entries.isEmpty else { return nil }
        let last = lastRevealedIndex(inLane: lane, at: step)
        if last >= 0, isFocused(entries[last], at: step) { return Double(last) }
        guard last + 1 < entries.count else { return Double(last) }

        let now = steps[step]
        let previous = last >= 0 ? entries[last].date : steps[0]
        let next = entries[last + 1].date
        let span = next.timeIntervalSince(previous)
        let fraction = span == 0 ? 0 : now.timeIntervalSince(previous) / span
        return Double(last) + min(max(fraction, 0), 1)
    }
}

/// Full-window, step-through presentation of one to three timelines.
/// Each → (or click) moves a shared clock to the next moment: the timeline it belongs to centers and
/// magnifies that event, while the others glide part of the way toward their own next event.
struct PresentationView: View {
    let events: [TimelineEvent]
    let dividers: [TimelineDivider]
    let onExit: () -> Void
    var managesFullScreen = true

    @AppStorage(PrefKey.title) private var title = TimelineDefaults.title
    @AppStorage(PrefKey.subtitle) private var subtitle = ""
    @AppStorage(PrefKey.background) private var background: CanvasBackground = .paper
    @AppStorage(PrefKey.layout) private var layout: TimelineLayout = .vertical
    @AppStorage(PrefKey.presentationEntrance) private var entrance: PresentationEntrance = .appear
    @AppStorage(PrefKey.presentationExit) private var exitStyle: PresentationExit = .shrinkAndDim
    @AppStorage(PrefKey.newestFirst) private var newestFirst = false
    private var lanes = LaneSettings()
    @Environment(\.categoryCatalog) private var catalog
    @Environment(AppState.self) private var appState

    /// -1 is the title card; 0...steps-1 is the current moment.
    @State private var step: Int
    @State private var enteredFullScreen = false
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var viewportSize: CGSize = .zero
    @State private var laneOffsets: [CGFloat] = Array(repeating: 0, count: Lanes.maxCount)
    /// False until the lanes have been placed once, so they appear already centered instead of sliding in.
    @State private var hasPositioned = false
    @FocusState private var isFocused: Bool
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var showsSidebar = true
    /// Category ids hidden for this presentation only.
    @State private var hiddenCategoryIDs: Set<String> = []

    // Critically damped: lanes glide into place without overshooting.
    private let motion = Animation.spring(response: 0.6, dampingFraction: 1)

    init(events: [TimelineEvent], dividers: [TimelineDivider] = [], onExit: @escaping () -> Void,
         initialStep: Int = -1, managesFullScreen: Bool = true) {
        self.events = events
        self.dividers = dividers
        self.onExit = onExit
        self.managesFullScreen = managesFullScreen
        _step = State(initialValue: initialStep)
    }

    private var model: PresentationModel {
        PresentationModel(events: presentedEvents(hiding: hiddenCategoryIDs), dividers: dividers,
                          newestFirst: newestFirst, laneCount: lanes.count, laneOf: lanes.lane(of:))
    }

    private func presentedEvents(hiding hidden: Set<String>) -> [TimelineEvent] {
        guard !hidden.isEmpty else { return events }
        return events.filter { !hidden.contains(catalog.category(for: $0.categoryID).id) }
    }

    private var bookmarkDividers: [TimelineDivider] {
        TimelineGrouping.entries(events: events, dividers: dividers, newestFirst: newestFirst).compactMap {
            if case .divider(let divider) = $0 { divider } else { nil }
        }
    }

    private var categoryRows: [PresentationSidebar.CategoryRow] {
        let counts = Dictionary(grouping: events) { catalog.category(for: $0.categoryID).id }.mapValues(\.count)
        return catalog.all.compactMap { category in
            guard let count = counts[category.id], count > 0 else { return nil }
            return PresentationSidebar.CategoryRow(category: category, count: count,
                                                   isShown: !hiddenCategoryIDs.contains(category.id))
        }
    }

    private var axis: Axis { layout == .horizontal ? .horizontal : .vertical }
    private var isMultiLane: Bool { lanes.isMultiLane }

    var body: some View {
        let model = self.model
        let currentStep = min(step, model.steps.count - 1)

        HStack(spacing: 0) {
            if showsSidebar {
                PresentationSidebar(
                    dividers: bookmarkDividers,
                    activeDividerID: activeDividerID(in: model, step: currentStep),
                    categories: categoryRows,
                    onSelect: { jump(to: $0, model: model) },
                    onToggle: toggleCategory,
                    onCollapse: { withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { showsSidebar = false } }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            timelineColumn(model, currentStep: currentStep)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.fill, ignoresSafeAreaEdges: .all)
        .overlay(alignment: .topLeading) {
            if !showsSidebar {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { showsSidebar = true }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)
                .padding(16)
                .help("Show navigation")
                .accessibilityLabel("Show navigation")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: showsSidebar)
        .environment(\.canvasBaseColor, background.baseColor)
        // Expanding notes would change lane heights mid-comparison, so only a single timeline expands them.
        .environment(\.eventActions, EventActions(
            isExpanded: { [isMultiLane] id in
                !isMultiLane && model.isFocusedID(id, at: currentStep)
            },
            openAttachment: { appState.attachmentEventID = $0.id }
        ))
        .overlay {
            if let event = events.first(where: { $0.id == appState.attachmentEventID }) {
                AttachmentViewer(event: event) { appState.attachmentEventID = nil }
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if currentStep >= 0, controlsVisible {
                controls(model, step: currentStep)
                    .padding(.leading, showsSidebar ? 260 : 0)
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) { exitButton.padding(18) }
        .onContinuousHover { phase in
            if case .active = phase { showControls() }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(keys: [.rightArrow, .downArrow, .space, .return]) { _ in
            guard appState.attachmentEventID == nil else { return .ignored }
            advance()
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, .upArrow, .delete]) { _ in
            guard appState.attachmentEventID == nil else { return .ignored }
            goBack()
            return .handled
        }
        .onKeyPress(keys: [.home]) { _ in
            guard appState.attachmentEventID == nil else { return .ignored }
            withAnimation(motion) { step = -1 }
            return .handled
        }
        .onKeyPress(.escape) {
            if appState.attachmentEventID != nil {
                appState.attachmentEventID = nil
            } else {
                exit()
            }
            return .handled
        }
        .onChange(of: hiddenCategoryIDs) { old, _ in
            realignStep(afterHiding: old)
        }
        .onChange(of: step) { _, newStep in
            if newStep < 0 {
                hasPositioned = false
            } else {
                recenter(animated: hasPositioned)
            }
            showControls()
        }
        .onAppear {
            isFocused = true
            enterFullScreen()
            showControls()
        }
        .onDisappear { hideControlsTask?.cancel() }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: PresentationTrace.advance)) { _ in advance() }
        #endif
    }

    private func timelineColumn(_ model: PresentationModel, currentStep: Int) -> some View {
        VStack(spacing: 0) {
            if currentStep < 0 { Spacer(minLength: 0) }

            TimelineHeader(title: .constant(title), subtitle: .constant(subtitle),
                           meta: TimelineGrouping.summary(for: presentedEvents(hiding: hiddenCategoryIDs)),
                           editable: false, compact: isMultiLane && currentStep >= 0)
                .scaleEffect(currentStep < 0 ? 1.4 : 1)
                .padding(.top, currentStep < 0 ? 0 : 8)

            if currentStep < 0 {
                introHint
                    .padding(.top, 44)
                    .transition(.opacity)
                Spacer(minLength: 0)
            } else {
                // The controls hide themselves, but horizontal lanes keep a full margin so the bottom lane's
                // focused event is never covered while they're showing.
                track(model, step: currentStep)
                    .padding(.bottom, axis == .horizontal ? 64 : 24)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard appState.attachmentEventID == nil else { return }
            advance()
        }
    }

    private func activeDividerID(in model: PresentationModel, step: Int) -> UUID? {
        guard step >= 0 else { return nil }
        return bookmarkDividers.last { model.step(of: .divider($0)) <= step }?.id
    }

    private func jump(to divider: TimelineDivider, model: PresentationModel) {
        let target = model.step(of: .divider(divider))
        guard target != .max, model.steps.indices.contains(target) else { return }
        withAnimation(motion) { step = target }
        isFocused = true
    }

    private func toggleCategory(_ id: String) {
        withAnimation(motion) {
            if hiddenCategoryIDs.contains(id) {
                hiddenCategoryIDs.remove(id)
            } else {
                hiddenCategoryIDs.insert(id)
            }
        }
    }

    /// Keeps the presentation on the same moment when a category is hidden or shown.
    private func realignStep(afterHiding old: Set<String>) {
        guard step >= 0 else { return }
        let previous = PresentationModel(events: presentedEvents(hiding: old), dividers: dividers,
                                        newestFirst: newestFirst, laneCount: lanes.count, laneOf: lanes.lane(of:))
        let steps = model.steps
        guard !steps.isEmpty else {
            step = -1
            return
        }
        guard previous.steps.indices.contains(step) else {
            step = min(step, steps.count - 1)
            return
        }
        let date = previous.steps[step]
        if let match = steps.firstIndex(where: { $0 == date }) {
            step = match
        } else if newestFirst {
            step = steps.lastIndex(where: { $0 <= date }) ?? steps.count - 1
        } else {
            step = steps.firstIndex(where: { $0 >= date }) ?? steps.count - 1
        }
    }

    // MARK: - Track

    /// Every event is laid out up front (unrevealed ones are invisible), so positions are known before
    /// they're needed. Each lane is then offset so its current position lands at the viewport's center.
    private func track(_ model: PresentationModel, step: Int) -> some View {
        GeometryReader { geometry in
            Group {
                if !isMultiLane {
                    laneStack(0, model: model, step: step, size: geometry.size)
                } else if axis == .vertical {
                    HStack(spacing: 0) {
                        ForEach(lanes.order, id: \.self) { lane in
                            laneColumn(lane, model: model, step: step,
                                       size: CGSize(width: geometry.size.width / CGFloat(lanes.count),
                                                    height: geometry.size.height))
                                .zIndex(model.laneHasFocus(lane, at: step) ? 1 : 0)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(lanes.order, id: \.self) { lane in
                            laneRow(lane, model: model, step: step,
                                    size: CGSize(width: geometry.size.width,
                                                 height: geometry.size.height / CGFloat(lanes.count)))
                                .zIndex(model.laneHasFocus(lane, at: step) ? 1 : 0)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
            .onPreferenceChange(ItemFramesKey.self) { frames in
                let relative = relativeFrames(frames)
                // While a lane glides, every measurement moves with it; only real layout changes matter.
                guard !Self.isSame(relative, itemFrames) else { return }
                itemFrames = relative
                recenter(animated: hasPositioned)
            }
            .onChange(of: geometry.size, initial: true) { _, size in
                viewportSize = size
                recenter(animated: false)
            }
        }
    }

    /// A lane's events, stacked along the axis and offset to center its current position.
    @ViewBuilder
    private func laneStack(_ lane: Int, model: PresentationModel, step: Int, size: CGSize) -> some View {
        if axis == .vertical {
            VStack(spacing: 0) { laneContent(lane, model: model, step: step) }
                .background(alignment: .top) { if !isMultiLane { singleSpine(model, step: step) } }
                .background { originReader(lane) }
                .coordinateSpace(name: Self.space(lane))
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: size.width)
                .offset(y: laneOffsets[lane])
        } else {
            HStack(spacing: 0) { laneContent(lane, model: model, step: step) }
                .background(alignment: .leading) { if !isMultiLane { singleSpine(model, step: step) } }
                .background { originReader(lane) }
                .coordinateSpace(name: Self.space(lane))
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: size.height)
                .offset(x: laneOffsets[lane])
        }
    }

    @ViewBuilder
    private func laneContent(_ lane: Int, model: PresentationModel, step: Int) -> some View {
        capSpacer
        ForEach(Array(model.lanes[lane].enumerated()), id: \.element.id) { index, entry in
            let state = ItemState(isRevealed: model.isRevealed(entry, at: step),
                                  isFocused: model.isFocused(entry, at: step))
            Group {
                switch entry {
                case .event(let event):
                    let category = catalog.category(for: event.categoryID)
                    if isMultiLane {
                        LanePresentationItem(event: event, category: category, index: index, state: state,
                                             exitStyle: exitStyle, axis: axis, side: lanes.side)
                    } else {
                        PresentationItem(event: event, category: category, index: index, state: state,
                                         exitStyle: exitStyle, axis: axis)
                    }
                case .divider(let divider):
                    // Only the first lane carries the label, so one divider reads as one line.
                    PresentationDividerItem(divider: divider, state: state, exitStyle: exitStyle, axis: axis,
                                            isMultiLane: isMultiLane, showsLabel: lane == (lanes.order.first ?? 0))
                }
            }
            .modifier(RevealModifier(isRevealed: state.isRevealed, entrance: entrance, axis: axis,
                                     fromLeading: !index.isMultiple(of: 2)))
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: ItemFramesKey.self,
                                           value: [Self.frameKey(lane, entry.id): proxy.frame(in: .named(Self.space(lane)))])
                }
            }
            .zIndex(state.isFocused ? 1 : 0)
        }
        capSpacer
    }

    /// A vertical lane: a fixed line down the column with the label pinned at the top, beside the line.
    private func laneColumn(_ lane: Int, model: PresentationModel, step: Int, size: CGSize) -> some View {
        let spineX = lanes.side == .leading ? LaneMetrics.spineInset + 20 : size.width - LaneMetrics.spineInset - 20
        return laneStack(lane, model: model, step: step, size: size)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(alignment: .topLeading) {
                Rectangle().fill(Palette.spine).frame(width: 2).offset(x: spineX - 1)
            }
            .clipped()
            .overlay(alignment: lanes.side == .leading ? .topLeading : .topTrailing) {
                LaneTag(label: lanes.label(lane), index: lane, side: lanes.side)
                    .padding(lanes.side == .leading ? .leading : .trailing,
                             LaneMetrics.spineInset + 20 - LaneTag.dotInset)
                    .padding(.top, 10)
                    .frame(width: size.width, alignment: lanes.side == .leading ? .leading : .trailing)
                    .padding(.bottom, 24)
                    .background(LinearGradient(colors: [background.baseColor, background.baseColor.opacity(0)],
                                               startPoint: .center, endPoint: .bottom))
            }
    }

    /// A horizontal lane: a fixed line across the screen with the label pinned at the left or right edge.
    private func laneRow(_ lane: Int, model: PresentationModel, step: Int, size: CGSize) -> some View {
        // Matches LanePresentationItem: cards above the line, time below it.
        let lineY = size.height - LaneMetrics.presentationDateBand - LaneMetrics.presentationNodeBand / 2
        return laneStack(lane, model: model, step: step, size: size)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(alignment: .top) {
                Rectangle().fill(Palette.spine).frame(height: 2).offset(y: lineY - 1)
            }
            .overlay(alignment: lanes.side == .leading ? .leading : .trailing) {
                LinearGradient(colors: [background.baseColor, background.baseColor.opacity(0)],
                               startPoint: lanes.side == .leading ? .leading : .trailing,
                               endPoint: lanes.side == .leading ? .trailing : .leading)
                    .frame(width: LaneMetrics.labelGutter)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: lanes.side == .leading ? .topLeading : .topTrailing) {
                LaneTag(label: lanes.label(lane), index: lane, side: lanes.side,
                        maxTextWidth: LaneMetrics.labelGutter - 40 - 27)
                    .padding(.horizontal, 20)
                    .frame(height: 40)
                    .offset(y: lineY - 20)
            }
    }

    private static func space(_ lane: Int) -> String { "presentationLane\(lane)" }

    /// Measured positions can include a lane's own offset, which fed back into the next target and made
    /// the lane oscillate. Measuring the lane's origin the same way and subtracting it cancels that out.
    private static let originKeys = (0..<Lanes.maxCount).map { "origin-\($0)" }

    /// Frames are keyed per lane: a divider is laid out once in every lane.
    private static func frameKey(_ lane: Int, _ id: UUID) -> String { "\(lane)-\(id.uuidString)" }

    private func originReader(_ lane: Int) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ItemFramesKey.self,
                                   value: [Self.originKeys[lane]: proxy.frame(in: .named(Self.space(lane)))])
        }
    }

    private var capSpacer: some View {
        Color.clear.frame(width: axis == .vertical ? 2 : 90, height: axis == .vertical ? 90 : 2)
    }

    /// Single-timeline spine: fades in at the start and out just past the most recently revealed event.
    @ViewBuilder
    private func singleSpine(_ model: PresentationModel, step: Int) -> some View {
        let last = model.lastRevealedIndex(inLane: 0, at: step)
        let fadeIn = [Palette.spine.opacity(0), Palette.spine]
        let start: UnitPoint = axis == .vertical ? .top : .leading
        let end: UnitPoint = axis == .vertical ? .bottom : .trailing
        if last >= 0, let frame = itemFrames[Self.frameKey(0, model.lanes[0][last].id)],
           let origin = itemFrames[Self.originKeys[0]] {
            let solid = max(0, axis == .vertical ? frame.maxY - origin.minY - 90 : frame.maxX - origin.minX - 90)
            let layout = axis == .vertical ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
            layout {
                Rectangle().fill(LinearGradient(colors: fadeIn, startPoint: start, endPoint: end))
                    .frame(width: axis == .vertical ? 2 : 90, height: axis == .vertical ? 90 : 2)
                Rectangle().fill(Palette.spine)
                    .frame(width: axis == .vertical ? 2 : solid, height: axis == .vertical ? solid : 2)
                Rectangle().fill(LinearGradient(colors: fadeIn.reversed(), startPoint: start, endPoint: end))
                    .frame(width: axis == .vertical ? 2 : 90, height: axis == .vertical ? 90 : 2)
            }
        }
    }

    // MARK: - Centering

    /// Moves every lane so its current position sits at the center of the viewport.
    /// Lanes only move toward measured positions, never guesses.
    private func recenter(animated: Bool) {
        let model = self.model
        let currentStep = min(step, model.steps.count - 1)
        guard currentStep >= 0, viewportSize != .zero else { return }

        var targets = laneOffsets
        for lane in 0..<model.lanes.count {
            guard let position = model.position(ofLane: lane, at: currentStep),
                  let center = center(ofLane: lane, at: position, model: model) else {
                #if DEBUG
                PresentationTrace.log("lane \(lane): not measured yet")
                #endif
                continue
            }
            let laneLength = axis == .vertical ? viewportSize.height : viewportSize.width
            targets[lane] = laneLength / 2 - center
            #if DEBUG
            PresentationTrace.log(String(format: "lane %d: position %.2f -> offset %.1f", lane, position, targets[lane]))
            #endif
        }
        guard zip(targets, laneOffsets).contains(where: { abs($0 - $1) > 0.5 }) else { return }

        if animated {
            withAnimation(motion) { laneOffsets = targets }
        } else {
            // Window resizes (including the full-screen menu bar sliding in) shouldn't spring.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { laneOffsets = targets }
        }
        hasPositioned = true
    }

    /// Re-expresses measured frames relative to each lane's origin, which cancels out the lane's own
    /// (possibly mid-animation) offset. Origins are kept, moved to zero, so code can still read their size.
    private func relativeFrames(_ frames: [String: CGRect]) -> [String: CGRect] {
        var result: [String: CGRect] = [:]
        for (lane, entries) in model.lanes.enumerated() {
            guard let origin = frames[Self.originKeys[lane]] else { continue }
            result[Self.originKeys[lane]] = CGRect(origin: .zero, size: origin.size)
            for entry in entries {
                let key = Self.frameKey(lane, entry.id)
                if let frame = frames[key] {
                    result[key] = frame.offsetBy(dx: -origin.minX, dy: -origin.minY)
                }
            }
        }
        return result
    }

    private static func isSame(_ a: [String: CGRect], _ b: [String: CGRect]) -> Bool {
        guard a.count == b.count else { return false }
        return a.allSatisfy { key, frame in
            guard let other = b[key] else { return false }
            return abs(frame.minX - other.minX) < 0.5 && abs(frame.minY - other.minY) < 0.5
                && abs(frame.width - other.width) < 0.5 && abs(frame.height - other.height) < 0.5
        }
    }

    /// The center of a fractional position along a lane, measured from the lane's origin.
    private func center(ofLane lane: Int, at position: Double, model: PresentationModel) -> CGFloat? {
        guard let origin = itemFrames[Self.originKeys[lane]] else { return nil }
        let entries = model.lanes[lane]

        func center(_ index: Int) -> CGFloat? {
            // The virtual slot before a lane's first entry sits one typical gap earlier.
            if index < 0 { return center(0).map { $0 - (axis == .vertical ? 260 : 340) } }
            guard let frame = itemFrames[Self.frameKey(lane, entries[index].id)] else { return nil }
            return axis == .vertical ? frame.midY - origin.minY : frame.midX - origin.minX
        }

        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        guard let a = center(lower), let b = center(upper) else { return nil }
        return a + (b - a) * CGFloat(position - Double(lower))
    }

    // MARK: - Chrome

    private var introHint: some View {
        VStack(spacing: 14) {
            Text(introSummary)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                KeyCap(label: "→")
                Text("or click to begin")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var introSummary: String {
        let count = presentedEvents(hiding: hiddenCategoryIDs).count
        let moments = count == 1 ? "1 moment" : "\(count) moments"
        return isMultiLane ? "\(moments) across \(lanes.count) timelines" : moments
    }

    private func controls(_ model: PresentationModel, step: Int) -> some View {
        let total = max(model.steps.count, 1)
        let isAtEnd = step >= model.steps.count - 1
        return HStack(spacing: 14) {
            Text("\(step + 1) of \(total)")
                .monospacedDigit()
                .foregroundStyle(.primary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.1))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(step + 1) / CGFloat(total))
                }
            }
            .frame(width: 140, height: 4)

            if isMultiLane {
                // With several timelines the shared clock is what ties them together, so show it.
                Text(model.steps[step].formatted(date: .abbreviated, time: .shortened))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Text(isAtEnd ? "End · Esc to exit" : "→ next   ← back   Esc exit")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.cardStroke, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .animation(motion, value: step)
    }

    private var exitButton: some View {
        Button(action: exit) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Palette.cardStroke, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help("Exit Presentation (Esc)")
    }

    /// Shows the bottom controls, then hides them after a few quiet seconds so they don't cover the timeline.
    private func showControls() {
        if !controlsVisible {
            withAnimation(.easeOut(duration: 0.2)) { controlsVisible = true }
        }
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.45)) { controlsVisible = false }
        }
    }

    // MARK: - Navigation

    private func advance() {
        guard appState.attachmentEventID == nil, step < model.steps.count - 1 else { return }
        withAnimation(motion) { step += 1 }
    }

    private func goBack() {
        guard step > -1 else { return }
        withAnimation(motion) { step -= 1 }
    }

    private func enterFullScreen() {
        guard managesFullScreen,
              let window = NSApp.keyWindow ?? NSApp.mainWindow,
              !window.styleMask.contains(.fullScreen) else { return }
        enteredFullScreen = true
        window.toggleFullScreen(nil)
    }

    private func exit() {
        if enteredFullScreen, let window = NSApp.keyWindow ?? NSApp.mainWindow, window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
        withAnimation(.easeInOut(duration: 0.35)) { onExit() }
    }
}

private extension PresentationModel {
    func laneHasFocus(_ lane: Int, at step: Int) -> Bool {
        lanes[lane].contains { isFocused($0, at: step) }
    }

    func isFocusedID(_ id: UUID, at step: Int) -> Bool {
        lanes.contains { lane in lane.contains { $0.id == id && isFocused($0, at: step) } }
    }
}

// MARK: - Items

private struct ItemFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct ItemState: Equatable {
    let isRevealed: Bool
    let isFocused: Bool
}

/// Hides an event until it's reached, then plays the chosen entrance in place.
private struct RevealModifier: ViewModifier {
    let isRevealed: Bool
    let entrance: PresentationEntrance
    let axis: Axis
    let fromLeading: Bool

    func body(content: Content) -> some View {
        content
            .modifier(EntranceModifier(effect: entrance, isActive: !isRevealed, axis: axis, fromLeading: fromLeading))
            .opacity(isRevealed ? 1 : 0)
            .animation(isRevealed ? entrance.animation : .easeOut(duration: 0.2), value: isRevealed)
    }
}

/// The look applied to an event once it has left the center. Dimming is applied per part (cards are
/// dimmed opaquely), because fading a whole item let overlapping cards show through each other.
private struct DepartureModifier: ViewModifier {
    let state: ItemState
    let exitStyle: PresentationExit

    func body(content: Content) -> some View {
        let isPast = state.isRevealed && !state.isFocused
        content
            .saturation(isPast ? exitStyle.saturation : 1)
            .blur(radius: isPast ? exitStyle.blurRadius : 0)
    }
}

/// Dims a departing card by blending it toward the background, so it stays solid and hides what's behind it.
private struct SolidDimModifier<S: Shape>: ViewModifier {
    let shape: S
    let isFocused: Bool
    let exitStyle: PresentationExit
    @Environment(\.canvasBaseColor) private var baseColor

    func body(content: Content) -> some View {
        content
            .overlay {
                if !isFocused, exitStyle.opacity > 0 {
                    shape.fill(baseColor.opacity(1 - exitStyle.opacity))
                }
            }
            .opacity(!isFocused && exitStyle.opacity == 0 ? 0 : 1)
    }
}

/// The single-timeline item: date on one side of a centered spine, card on the other.
private struct PresentationItem: View {
    let event: TimelineEvent
    let category: EventCategory
    let index: Int
    let state: ItemState
    let exitStyle: PresentationExit
    let axis: Axis

    private var isFocused: Bool { state.isFocused }
    /// Alternate sides so the focused card always sits beside the center line.
    private var cardOnLeading: Bool { !index.isMultiple(of: 2) }
    private var cardAnchor: UnitPoint {
        axis == .vertical ? (cardOnLeading ? .trailing : .leading) : (cardOnLeading ? .bottom : .top)
    }

    var body: some View {
        Group {
            if axis == .vertical { verticalBody } else { horizontalBody }
        }
        .modifier(DepartureModifier(state: state, exitStyle: exitStyle))
    }

    private var verticalBody: some View {
        HStack(alignment: .center, spacing: 0) {
            Group {
                if cardOnLeading { card(maxWidth: 440) } else { dateLabel(alignment: .trailing) }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            node.frame(width: 96)

            Group {
                if cardOnLeading { dateLabel(alignment: .leading) } else { card(maxWidth: 440) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 1080)
        .padding(.vertical, 24)
        .padding(.horizontal, 48)
    }

    private var horizontalBody: some View {
        VStack(spacing: 0) {
            Group {
                if cardOnLeading { card(maxWidth: 340) } else { dateLabel(alignment: .center) }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 20)

            node.frame(height: 96)

            Group {
                if cardOnLeading { dateLabel(alignment: .center) } else { card(maxWidth: 340) }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 20)
        }
        .frame(width: 400)
    }

    private func card(maxWidth: CGFloat) -> some View {
        PresentationCard(event: event, category: category, maxWidth: maxWidth, compact: false,
                         isFocused: isFocused, exitStyle: exitStyle, anchor: cardAnchor,
                         asideOffset: asideOffset)
            .padding(axis == .vertical ? .horizontal : .vertical, 8)
    }

    private var node: some View {
        PresentationNode(category: category, size: 40, isFocused: isFocused, exitStyle: exitStyle)
    }

    /// Moves a departing card away from the spine, for Slide Aside.
    private var asideOffset: CGSize {
        let shift = exitStyle.sideShift
        return axis == .vertical
            ? CGSize(width: cardOnLeading ? -shift : shift, height: 0)
            : CGSize(width: 0, height: cardOnLeading ? -shift : shift)
    }

    private func dateLabel(alignment: HorizontalAlignment) -> some View {
        let textAlignment: TextAlignment = alignment == .leading ? .leading : alignment == .trailing ? .trailing : .center
        let time = event.isAllDay ? "All-day" : event.date.formatted(date: .omitted, time: .shortened)
        return VStack(alignment: alignment, spacing: 3) {
            Text(event.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 18, weight: .semibold))
            Text("\(event.date.formatted(.dateTime.year())) · \(time)")
                .font(.system(size: 14))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(textAlignment)
        .padding(.horizontal, 24)
        .scaleEffect(isFocused ? 1.06 : (exitStyle.cardScale < 1 ? 0.94 : 1),
                     anchor: axis == .vertical ? (cardOnLeading ? .leading : .trailing) : .center)
        .opacity(isFocused ? 1 : exitStyle.opacity)
    }
}

/// The multi-timeline item. Only the event in focus gets a full card; earlier events condense to a
/// one-line tag so three timelines can share the screen without their cards colliding.
private struct LanePresentationItem: View {
    let event: TimelineEvent
    let category: EventCategory
    let index: Int
    let state: ItemState
    let exitStyle: PresentationExit
    let axis: Axis
    let side: LaneLabelSide

    private var isFocused: Bool { state.isFocused }
    /// Not-yet-reached events keep their full size (invisibly) so the lane knows where its next card will sit.
    private var isCondensed: Bool { state.isRevealed && !state.isFocused }

    var body: some View {
        Group {
            if axis == .vertical { verticalBody } else { horizontalBody }
        }
        .modifier(DepartureModifier(state: state, exitStyle: exitStyle))
    }

    /// Node on the column's line (left or right, matching the label side), details beside it.
    private var verticalBody: some View {
        HStack(alignment: .center, spacing: 14) {
            if side == .trailing { verticalDetails }
            node.frame(width: 2 * (LaneMetrics.spineInset + 20) - 40, height: 60)
            if side == .leading { verticalDetails }
        }
        .padding(side == .leading ? .leading : .trailing, 20)
        .padding(side == .leading ? .trailing : .leading, 24)
        .frame(maxWidth: .infinity, alignment: side == .leading ? .leading : .trailing)
        .padding(.vertical, isCondensed ? 8 : 22)
    }

    @ViewBuilder
    private var verticalDetails: some View {
        if isCondensed {
            tag(showsTime: true)
        } else {
            VStack(alignment: side == .leading ? .leading : .trailing, spacing: 5) {
                Text(dateText)
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
                card(maxWidth: 360, anchor: side == .leading ? .leading : .trailing)
            }
        }
    }

    /// Every card sits above its lane's line, with the time below it, so neighbouring lanes never face each
    /// other. Cards are overlays: a tall one spills upward rather than pushing the node off the line.
    private var horizontalBody: some View {
        VStack(spacing: 0) {
            Color.clear.overlay(alignment: .bottom) {
                Group {
                    if isCondensed { tag(showsTime: false) } else { card(maxWidth: 290, anchor: .bottom) }
                }
                .padding(.bottom, 8)
            }
            node.frame(height: LaneMetrics.presentationNodeBand)
            Text(dateText)
                .font(.system(size: 12, weight: isFocused ? .semibold : .medium))
                .monospacedDigit()
                .foregroundStyle(isFocused ? .primary : .secondary)
                .opacity(isFocused ? 1 : exitStyle.opacity)
                .frame(height: LaneMetrics.presentationDateBand, alignment: .top)
        }
        .frame(width: 330)
    }

    private var node: some View {
        PresentationNode(category: category, size: 34, isFocused: isFocused, exitStyle: exitStyle)
    }

    private func card(maxWidth: CGFloat, anchor: UnitPoint) -> some View {
        PresentationCard(event: event, category: category, maxWidth: maxWidth, compact: true,
                         isFocused: isFocused, exitStyle: exitStyle, anchor: anchor, asideOffset: .zero)
    }

    /// The condensed form of an earlier event: its title (and time, in columns) on one line.
    private func tag(showsTime: Bool) -> some View {
        HStack(spacing: 6) {
            if showsTime {
                Text(event.isAllDay ? "All-day" : event.date.formatted(date: .omitted, time: .shortened))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Text(event.title.isEmpty ? "Untitled Event" : event.title)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Palette.cardFill))
        .overlay(Capsule().strokeBorder(Palette.cardStroke, lineWidth: 0.5))
        .modifier(SolidDimModifier(shape: Capsule(), isFocused: false, exitStyle: exitStyle))
        .frame(maxWidth: 240)
    }

    private var dateText: String {
        event.isAllDay
            ? event.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            : event.date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}

/// A divider in a presentation. In each lane it's a dashed line across (or down through) the lane;
/// the first lane also carries the label, which is emphasized while the divider is the current moment.
private struct PresentationDividerItem: View {
    let divider: TimelineDivider
    let state: ItemState
    let exitStyle: PresentationExit
    let axis: Axis
    let isMultiLane: Bool
    let showsLabel: Bool

    private var isFocused: Bool { state.isFocused }

    var body: some View {
        Group {
            if axis == .vertical { verticalBody } else { horizontalBody }
        }
        .opacity(isFocused ? 1 : max(exitStyle.opacity, 0.15))
    }

    private var label: some View {
        DividerLabel(divider: divider, isInteractive: false, emphasized: isFocused)
            .scaleEffect(isFocused ? 1.08 : 1)
            .shadow(color: Color.accentColor.opacity(isFocused ? 0.25 : 0), radius: 16, y: 6)
    }

    @ViewBuilder
    private var verticalBody: some View {
        if showsLabel {
            HStack(spacing: 12) {
                DividerStyle.line(.horizontal)
                label.layoutPriority(1)
                DividerStyle.line(.horizontal)
            }
            .frame(maxWidth: 1080)
            .padding(.horizontal, isMultiLane ? 16 : 48)
            .padding(.vertical, 30)
        } else {
            DividerStyle.line(.horizontal)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .padding(.vertical, 30)
        }
    }

    /// A vertical line through the lane, with the label sitting on the lane's line.
    private var horizontalBody: some View {
        VStack(spacing: 0) {
            Color.clear
            Color.clear
                .frame(height: isMultiLane ? LaneMetrics.presentationNodeBand : 96)
                .overlay { if showsLabel { label.fixedSize() } }
            if isMultiLane {
                Color.clear.frame(height: LaneMetrics.presentationDateBand)
            } else {
                Color.clear
            }
        }
        .frame(width: 240)
        .background { DividerStyle.line(.vertical) }
    }
}

/// An event card with the focus magnification and the chosen departure treatment.
private struct PresentationCard: View {
    let event: TimelineEvent
    let category: EventCategory
    let maxWidth: CGFloat
    let compact: Bool
    /// Narrow multi-timeline columns use a gentler magnification so the focused card stays in its lane.
    private var focusScale: CGFloat { compact ? 1.06 : 1.12 }
    let isFocused: Bool
    let exitStyle: PresentationExit
    let anchor: UnitPoint
    let asideOffset: CGSize

    @Environment(\.eventActions) private var actions

    var body: some View {
        EventCard(event: event, category: category, compact: compact, maxWidth: maxWidth, showsAttachmentButton: false)
            .allowsHitTesting(false)
            .overlay(alignment: .topTrailing) {
                if isFocused && event.hasAttachment {
                    AttachmentIconButton(event: event, tint: category.color) {
                        actions.openAttachment(event)
                    }
                    .padding(8)
                }
            }
            .modifier(SolidDimModifier(shape: RoundedRectangle(cornerRadius: TimelineMetrics.cardCornerRadius,
                                                               style: .continuous),
                                       isFocused: isFocused, exitStyle: exitStyle))
            .scaleEffect(isFocused ? focusScale : exitStyle.cardScale, anchor: anchor)
            .rotation3DEffect(.degrees(isFocused ? 0 : exitStyle.tilt), axis: (x: 1, y: 0, z: 0),
                              anchor: anchor, perspective: 0.5)
            .offset(isFocused ? .zero : asideOffset)
            .shadow(color: category.color.opacity(isFocused ? 0.22 : 0), radius: 26, y: 12)
    }
}

private struct PresentationNode: View {
    let category: EventCategory
    let size: CGFloat
    let isFocused: Bool
    let exitStyle: PresentationExit

    var body: some View {
        ZStack {
            Circle()
                .fill(category.color.opacity(0.16))
                .frame(width: size * 1.7, height: size * 1.7)
                .scaleEffect(isFocused ? 1 : 0.5)
                .opacity(isFocused ? 1 : 0)
            TimelineNode(category: category, size: size)
        }
        .scaleEffect(isFocused ? 1.1 : exitStyle.nodeScale)
        .opacity(isFocused ? 1 : exitStyle.opacity)
    }
}

private struct KeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(minWidth: 26, minHeight: 24)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Palette.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.cardStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
    }
}
