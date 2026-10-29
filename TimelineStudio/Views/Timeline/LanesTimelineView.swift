import SwiftUI
import AppKit

enum LaneMetrics {
    /// Distance from a lane column's edge to its spine.
    static let spineInset: CGFloat = 36
    static let nodeColumn: CGFloat = 48
    static let maxContentWidth: CGFloat = 1200
    /// Height of one lane in the horizontal layout.
    static let rowHeight: CGFloat = 280
    /// Space above the horizontal lanes for month markers.
    static let monthBand: CGFloat = 40
    /// Room left at the pinned-label edge so events don't start underneath a label.
    static let labelGutter: CGFloat = 210
    /// In presentation lanes: the node's band on the line, and the band below it for the time.
    static let presentationNodeBand: CGFloat = 60
    static let presentationDateBand: CGFloat = 34
}

/// A timeline's name, sitting on its line with a colored dot.
/// Given a `text` binding it can be renamed in place: click it, type, and press Return (Esc cancels).
struct LaneTag: View {
    let label: String
    let index: Int
    let side: LaneLabelSide
    /// The stored label to edit; nil makes the tag read-only (presentations, exports).
    var text: Binding<String>?
    /// Long names wrap onto more lines past this width rather than being cut off.
    var maxTextWidth: CGFloat = 220

    @Environment(\.isExporting) private var isExporting
    @State private var isEditing = false
    @State private var isHovering = false
    @State private var draft = ""

    /// Distance from the tag's outer edge to the center of its dot, used to put the dot on the line.
    static let dotInset: CGFloat = 15

    private var isEditable: Bool { text != nil && !isExporting }
    private let font = Font.system(size: 12.5, weight: .semibold)

    var body: some View {
        Group {
            if isEditable && !isEditing {
                // A real button (rather than a tap gesture) so renaming also works from the keyboard
                // and VoiceOver.
                Button(action: beginEditing) { capsule }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rename \(label)")
            } else {
                capsule
            }
        }
        .onHover { hovering in
            guard isEditable else { return }
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
            if hovering { NSCursor.iBeam.push() } else { NSCursor.pop() }
        }
        .help(isEditable ? (lanes.isMultiLane ? "Click to rename. Right-click to change the order." : "Click to rename this timeline") : "")
        .contextMenu {
            if isEditable, lanes.isMultiLane, let position = lanes.order.firstIndex(of: index) {
                let stacked = layout == .horizontal
                Button(stacked ? "Move Up" : "Move Left") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { lanes.move(from: position, by: -1) }
                }
                .disabled(position == 0)
                Button(stacked ? "Move Down" : "Move Right") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { lanes.move(from: position, by: 1) }
                }
                .disabled(position == lanes.order.count - 1)
            }
        }
    }

    @AppStorage(PrefKey.layout) private var layout: TimelineLayout = .vertical
    private var lanes = LaneSettings()

    /// A one-line tag is exactly a capsule; a wrapped one becomes a rounded box with the same corners.
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 13, style: .continuous) }

    private var capsule: some View {
        HStack(alignment: .top, spacing: 7) {
            if side == .leading { dot }
            title
            if side == .trailing { dot }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .surface(shape, exporting: isExporting)
        // The edit/hover ring is a slightly larger shape behind the tag rather than a stroke over it.
        .background {
            shape
                .fill(Color.accentColor)
                .padding(isEditing ? -1.5 : -1)
                .opacity(isEditing ? 1 : (isHovering && isEditable ? 0.45 : 0))
        }
        .contentShape(shape)
    }

    private var textAlignment: TextAlignment { side == .leading ? .leading : .trailing }

    @ViewBuilder
    private var title: some View {
        if isEditing {
            // The hidden text sizes the field, so the tag grows (and wraps) with what's typed.
            WidthLimitedLayout(maxWidth: maxTextWidth) {
                Text(draft.isEmpty ? Lanes.defaultLabel(index) : draft)
                    .font(font)
                    .multilineTextAlignment(textAlignment)
                    .padding(.trailing, 4)
            }
            .hidden()
            .overlay(alignment: .topLeading) {
                InlineNameField(text: $draft, placeholder: Lanes.defaultLabel(index), alignment: textAlignment,
                                onCommit: commit, onCancel: cancel)
                    .padding(.trailing, -4)
            }
        } else {
            WidthLimitedLayout(maxWidth: maxTextWidth) {
                Text(label)
                    .font(font)
                    .multilineTextAlignment(textAlignment)
            }
        }
    }

    /// Sits beside the first line, so it stays on the timeline's line when the name wraps.
    private var dot: some View {
        Circle()
            .fill(Lanes.tints[index].gradient)
            .frame(width: 10, height: 10)
            .padding(.top, 3.5)
    }

    private func beginEditing() {
        draft = label
        isEditing = true
    }

    private func commit() {
        guard isEditing else { return }
        // An empty name falls back to "Timeline N" (see LaneSettings.label).
        text?.wrappedValue = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditing = false
    }

    private func cancel() {
        isEditing = false
    }
}

/// Offers its content at most `maxWidth`, then takes exactly the size the content wants, so short text
/// stays snug while long text wraps. (A plain `.frame(maxWidth:)` would stretch short text to the limit.)
private struct WidthLimitedLayout: Layout {
    let maxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        return subview.sizeThatFits(ProposedViewSize(width: min(proposal.width ?? maxWidth, maxWidth), height: nil))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                              proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

/// The native field used to rename a timeline in place. Unlike SwiftUI's TextField it lets us put the
/// caret at the end (so typing adds to the name) instead of selecting the whole name on focus.
/// Return commits, Esc cancels, and clicking elsewhere commits, matching Finder.
private struct InlineNameField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let alignment: TextAlignment
    let onCommit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> AutoFocusTextField {
        let field = AutoFocusTextField(string: text)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 12.5, weight: .semibold)
        field.placeholderString = placeholder
        // Wraps like the label it replaces; Return still commits (see the coordinator).
        field.cell?.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.lineBreakMode = .byWordWrapping
        field.alignment = alignment == .trailing ? .right : .left
        field.delegate = context.coordinator
        // Take the width SwiftUI proposes (the measured text), not the field's own preference.
        for orientation in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            field.setContentHuggingPriority(.defaultLow, for: orientation)
            field.setContentCompressionResistancePriority(.defaultLow, for: orientation)
        }
        return field
    }

    func updateNSView(_ field: AutoFocusTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: InlineNameField

        init(_ parent: InlineNameField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSTextField { parent.text = field.stringValue }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onCommit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
                return true
            default:
                return false
            }
        }

        /// Focus moved elsewhere. After Return or Esc this is a no-op, because editing has already ended.
        func controlTextDidEndEditing(_ notification: Notification) {
            parent.onCommit()
        }
    }
}

/// Takes keyboard focus as soon as it joins a window, with the caret after the existing text.
private final class AutoFocusTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, window.makeFirstResponder(self) else { return }
            self.currentEditor()?.selectedRange = NSRange(location: (self.stringValue as NSString).length, length: 0)
        }
    }
}

// MARK: - Vertical: lanes side by side

/// Parallel timelines as columns. Rows stay in global chronological order so events can be compared across lanes.
struct LanesVerticalView: View {
    let months: [MonthGroup]
    let showTimes: Bool

    private var lanes = LaneSettings()
    @Environment(\.isExporting) private var isExporting
    @Environment(\.canvasBaseColor) private var baseColor

    init(months: [MonthGroup], showTimes: Bool) {
        self.months = months
        self.showTimes = showTimes
    }

    var body: some View {
        if isExporting {
            VStack(spacing: 0) {
                header
                rows
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        rows
                    } header: {
                        header
                    }
                }
                .supportsDividerDragging(axis: .vertical)
                .padding(.bottom, 40)
            }
        }
    }

    private var header: some View {
        LaneColumnsRow(order: lanes.order, side: lanes.side) { lane, _ in
            LaneTag(label: lanes.label(lane), index: lane, side: lanes.side, text: lanes.labelBinding(lane))
                .padding(lanes.side == .leading ? .leading : .trailing, LaneMetrics.spineInset - LaneTag.dotInset)
                .padding(.vertical, 12)
        }
        .background(LinearGradient(colors: [baseColor, baseColor.opacity(0)], startPoint: .center, endPoint: .bottom))
    }

    @ViewBuilder
    private var rows: some View {
        ForEach(months) { month in
            LaneColumnsRow(order: lanes.order, side: lanes.side) { _, isFirst in
                if isFirst {
                    Text(month.title)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .surface(Capsule(), exporting: isExporting)
                        .alignmentGuide(.leading) { d in d.width / 2 - LaneMetrics.spineInset }
                        .alignmentGuide(.trailing) { d in d.width / 2 + LaneMetrics.spineInset }
                        .padding(.vertical, 12)
                }
            }

            ForEach(month.days) { day in
                LaneColumnsRow(order: lanes.order, side: lanes.side) { _, isFirst in
                    LaneDayCell(day: day.date, showsLabel: isFirst, side: lanes.side)
                }
                ForEach(day.entries) { entry in
                    switch entry {
                    case .event(let event):
                        let lane = lanes.lane(of: event)
                        LaneColumnsRow(order: lanes.order, side: lanes.side) { index, _ in
                            if index == lane {
                                LaneEventCell(event: event, side: lanes.side, showTimes: showTimes)
                            }
                        }
                        .reportsEntryFrame(id: event.id, date: event.date)
                        .transition(.opacity)
                    case .divider(let divider):
                        // One chapter line across every lane.
                        LaneColumnsRow(order: lanes.order, side: lanes.side) { _, _ in
                            Color.clear.frame(height: 56)
                        }
                        .overlay {
                            HorizontalDividerBand(divider: divider)
                                .frame(maxWidth: LaneMetrics.maxContentWidth)
                                .padding(.horizontal, 28)
                        }
                        .draggableDivider(divider, axis: .vertical)
                        .reportsEntryFrame(id: divider.id, date: divider.date)
                        .transition(.opacity)
                    }
                }
            }
        }
    }
}

/// One row across all lanes; each column draws its own segment of its lane's spine.
private struct LaneColumnsRow<Cell: View>: View {
    let order: [Int]
    let side: LaneLabelSide
    /// The lane index, and whether this column is the first one on screen.
    @ViewBuilder let cell: (Int, Bool) -> Cell

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(order.enumerated()), id: \.element) { offset, lane in
                // The zero-height spacer keeps a lane with nothing in this row from collapsing,
                // which would let the next lane's content slide into its place.
                VStack(alignment: side == .leading ? .leading : .trailing, spacing: 0) {
                    Color.clear.frame(height: 0)
                    cell(lane, offset == 0)
                }
                .frame(maxWidth: .infinity, alignment: side == .leading ? .leading : .trailing)
            }
        }
        // Spines are drawn across the whole row so every lane's line stays continuous.
        .background {
            HStack(spacing: 0) {
                ForEach(order, id: \.self) { _ in
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: side == .leading ? .leading : .trailing) {
                            Rectangle()
                                .fill(Palette.spine)
                                .frame(width: 2)
                                .padding(side == .leading ? .leading : .trailing, LaneMetrics.spineInset - 1)
                        }
                }
            }
        }
        .frame(maxWidth: LaneMetrics.maxContentWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
    }
}

private struct LaneDayCell: View {
    let day: Date
    let showsLabel: Bool
    let side: LaneLabelSide
    @Environment(\.canvasBaseColor) private var baseColor

    var body: some View {
        HStack(spacing: 10) {
            if side == .trailing, showsLabel { label }
            Circle()
                .fill(Palette.dayDot)
                .frame(width: 8, height: 8)
                .padding(3)
                .background(Circle().fill(baseColor))
            if side == .leading, showsLabel { label }
        }
        .padding(side == .leading ? .leading : .trailing, LaneMetrics.spineInset - 7)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    private var label: some View {
        Text(day.formatted(.dateTime.weekday(.abbreviated).month(.wide).day().year()))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

private struct LaneEventCell: View {
    let event: TimelineEvent
    let side: LaneLabelSide
    let showTimes: Bool
    @Environment(\.categoryCatalog) private var catalog

    var body: some View {
        let category = catalog.category(for: event.categoryID)
        HStack(alignment: .top, spacing: 0) {
            if side == .trailing { details(category) }
            TimelineNode(category: category)
                .frame(width: LaneMetrics.nodeColumn)
                .padding(.top, showTimes ? 22 : 8)
                .padding(side == .leading ? .leading : .trailing, LaneMetrics.spineInset - LaneMetrics.nodeColumn / 2)
            if side == .leading { details(category) }
        }
        .padding(.vertical, 7)
    }

    private func details(_ category: EventCategory) -> some View {
        VStack(alignment: side == .leading ? .leading : .trailing, spacing: 4) {
            if showTimes {
                Text(event.isAllDay ? "All-day" : event.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            EventCard(event: event, category: category, maxWidth: 380)
        }
        .padding(side == .leading ? .trailing : .leading, 14)
    }
}

// MARK: - Horizontal: lanes stacked

/// Parallel timelines as horizontal rows, with each lane's label pinned to the left or right edge.
struct LanesHorizontalView: View {
    let entries: [TimelineEntry]
    let showTimes: Bool

    private var lanes = LaneSettings()
    @Environment(\.isExporting) private var isExporting
    @Environment(\.categoryCatalog) private var catalog
    @Environment(\.canvasBaseColor) private var baseColor

    init(entries: [TimelineEntry], showTimes: Bool) {
        self.entries = entries
        self.showTimes = showTimes
    }

    private enum Item: Identifiable {
        case month(Date)
        case event(TimelineEvent, lane: Int, laneIndex: Int)
        case divider(TimelineDivider)

        var id: String {
            switch self {
            case .month(let date): "month-\(date.timeIntervalSince1970)"
            case .event(let event, _, _): event.id.uuidString
            case .divider(let divider): divider.id.uuidString
            }
        }
    }

    private var items: [Item] {
        var result: [Item] = []
        var lastMonth: Date?
        var perLane = [Int](repeating: 0, count: Lanes.maxCount)
        for entry in entries {
            let month = Calendar.current.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
            if month != lastMonth {
                result.append(.month(month))
                lastMonth = month
            }
            switch entry {
            case .event(let event):
                let lane = lanes.lane(of: event)
                result.append(.event(event, lane: lane, laneIndex: perLane[lane]))
                perLane[lane] += 1
            case .divider(let divider):
                result.append(.divider(divider))
            }
        }
        return result
    }

    /// Natural height of the live strip, including room below the last lane for a card that hangs under the line.
    private var liveStripHeight: CGFloat {
        LaneMetrics.monthBand + CGFloat(lanes.count) * LaneMetrics.rowHeight + Self.stripTop + Self.stripBottomLive
    }

    var body: some View {
        if isExporting {
            strip.overlay { pinnedTags }
        } else {
            // Vertical scrolling reaches the lower lanes. The inner scroll is locked to the viewport
            // width so the lane names stay pinned while the events move sideways.
            GeometryReader { geo in
                ScrollView(.vertical) {
                    ScrollView(.horizontal) {
                        strip
                    }
                    .frame(width: geo.size.width, height: liveStripHeight)
                    .overlay { pinnedTags }
                }
            }
        }
    }

    private static let stripTop: CGFloat = 12
    private static let stripBottomLive: CGFloat = 48

    private var strip: some View {
        HStack(alignment: .top, spacing: 0) {
            // Lines run through the label gutter so each label is connected to its timeline.
            column(width: lanes.side == .leading ? LaneMetrics.labelGutter : 40) { _ in Color.clear } top: { Color.clear }
            ForEach(items) { item in
                switch item {
                case .month(let date):
                    column(width: 120) { _ in Color.clear } top: {
                        Text(date.formatted(.dateTime.month(.abbreviated).year()))
                            .font(.system(size: 12.5, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .surface(Capsule(), exporting: isExporting)
                    }
                case .event(let event, let lane, let laneIndex):
                    column(width: 240) { index in
                        if index == lane {
                            HorizontalLaneCell(event: event, category: catalog.category(for: event.categoryID),
                                               above: laneIndex.isMultiple(of: 2), showTimes: showTimes)
                        }
                    } top: { Color.clear }
                    .reportsEntryFrame(id: event.id, date: event.date)
                    .transition(.opacity)
                case .divider(let divider):
                    // A vertical chapter line down through every lane, labelled in the month band.
                    column(width: 170) { _ in
                        ZStack {
                            Color.clear
                            DividerStyle.line(.vertical)
                        }
                    } top: {
                        DividerLabel(divider: divider)
                    }
                    .draggableDivider(divider, axis: .horizontal)
                    .reportsEntryFrame(id: divider.id, date: divider.date)
                    .transition(.opacity)
                }
            }
            column(width: lanes.side == .trailing ? LaneMetrics.labelGutter : 40) { _ in Color.clear } top: { Color.clear }
        }
        .padding(.top, Self.stripTop)
        .padding(.bottom, isExporting ? Self.stripTop : Self.stripBottomLive)
        .supportsDividerDragging(axis: .horizontal)
    }

    /// One slice of time across every lane; each lane cell draws its piece of that lane's line.
    private func column<Cell: View, Top: View>(width: CGFloat, @ViewBuilder cell: @escaping (Int) -> Cell,
                                               @ViewBuilder top: () -> Top) -> some View {
        VStack(spacing: 0) {
            top().frame(height: LaneMetrics.monthBand)
            ForEach(lanes.order, id: \.self) { index in
                ZStack {
                    Color.clear
                    cell(index)
                }
                .frame(width: width, height: LaneMetrics.rowHeight)
                    .background { Rectangle().fill(Palette.spine).frame(height: 2) }
            }
        }
    }

    private var pinnedTags: some View {
        tags.frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: Alignment(horizontal: lanes.side == .leading ? .leading : .trailing, vertical: .top))
    }

    private var tags: some View {
        VStack(alignment: lanes.side == .leading ? .leading : .trailing, spacing: 0) {
            Color.clear.frame(height: LaneMetrics.monthBand)
            ForEach(lanes.order, id: \.self) { index in
                LaneTag(label: lanes.label(index), index: index, side: lanes.side, text: lanes.labelBinding(index),
                        maxTextWidth: LaneMetrics.labelGutter - 32 - 27)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: LaneMetrics.labelGutter, maxHeight: .infinity,
                           alignment: lanes.side == .leading ? .leading : .trailing)
                    .frame(height: LaneMetrics.rowHeight)
            }
        }
        .padding(.vertical, Self.stripTop)
        .frame(width: LaneMetrics.labelGutter)
        .frame(maxHeight: isExporting ? nil : .infinity, alignment: .top)
        .background {
            // Lets events slide under the label instead of colliding with it.
            LinearGradient(colors: [baseColor, baseColor.opacity(0)],
                           startPoint: lanes.side == .leading ? .leading : .trailing,
                           endPoint: lanes.side == .leading ? .trailing : .leading)
                .frame(width: LaneMetrics.labelGutter)
                .allowsHitTesting(false)
        }
    }
}

private struct HorizontalLaneCell: View {
    let event: TimelineEvent
    let category: EventCategory
    let above: Bool
    let showTimes: Bool

    private var half: CGFloat { (LaneMetrics.rowHeight - 44) / 2 }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if above {
                    VStack(spacing: 0) { card; stem }
                } else {
                    dateLabel.padding(.bottom, 6)
                }
            }
            .frame(height: half, alignment: .bottom)

            TimelineNode(category: category).frame(height: 44)

            Group {
                if above {
                    dateLabel.padding(.top, 6)
                } else {
                    VStack(spacing: 0) { stem; card }
                }
            }
            .frame(height: half, alignment: .top)
        }
    }

    private var card: some View {
        EventCard(event: event, category: category, compact: true, maxWidth: 218)
            .padding(.horizontal, 11)
    }

    private var stem: some View {
        Rectangle()
            .fill(category.color.opacity(0.4))
            .frame(width: 1.5, height: 12)
    }

    private var dateLabel: some View {
        VStack(spacing: 1) {
            Text(event.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(size: 11.5, weight: .semibold))
            if showTimes {
                Text(event.isAllDay ? "All-day" : event.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10.5))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
