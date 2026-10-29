import SwiftUI

/// The live timeline: background, editable header, optional Y-axis, and the selected layout.
struct TimelineCanvas: View {
    let events: [TimelineEvent]
    let dividers: [TimelineDivider]
    let isFiltered: Bool
    let onClearFilters: () -> Void

    @AppStorage(PrefKey.title) private var title = TimelineDefaults.title
    @AppStorage(PrefKey.subtitle) private var subtitle = ""
    @AppStorage(PrefKey.yAxisLabel) private var yAxisLabel = ""
    @AppStorage(PrefKey.showYAxis) private var showYAxis = false
    @AppStorage(PrefKey.background) private var background: CanvasBackground = .paper
    @AppStorage(PrefKey.layout) private var layout: TimelineLayout = .vertical
    @AppStorage(PrefKey.showTimes) private var showTimes = true
    @AppStorage(PrefKey.newestFirst) private var newestFirst = false
    private var lanes = LaneSettings()

    init(events: [TimelineEvent], dividers: [TimelineDivider], isFiltered: Bool, onClearFilters: @escaping () -> Void) {
        self.events = events
        self.dividers = dividers
        self.isFiltered = isFiltered
        self.onClearFilters = onClearFilters
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineHeader(title: $title, subtitle: $subtitle,
                           meta: TimelineGrouping.summary(for: events))

            HStack(spacing: 0) {
                if showYAxis && !yAxisLabel.isEmpty {
                    YAxisColumn(label: yAxisLabel)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(background.fill, ignoresSafeAreaEdges: .all)
        .environment(\.canvasBaseColor, background.baseColor)
    }

    @ViewBuilder
    private var content: some View {
        if events.isEmpty {
            ContentUnavailableView {
                Label("No Matching Events", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text(isFiltered ? "Try a different search or show more categories." : "There’s nothing to show yet.")
            } actions: {
                if isFiltered {
                    Button("Clear Filters", action: onClearFilters)
                }
            }
        } else {
            TimelineLayoutContent(entries: TimelineGrouping.entries(events: events, dividers: dividers,
                                                                    newestFirst: newestFirst),
                                  layout: layout, isMultiLane: lanes.isMultiLane, laneCount: lanes.count,
                                  showTimes: showTimes)
        }
    }
}

/// A static, fully-expanded rendering of the timeline used for PDF and PNG export.
struct TimelineExportView: View {
    let title: String
    let subtitle: String
    let yAxisLabel: String
    let background: CanvasBackground
    let layout: TimelineLayout
    let events: [TimelineEvent]
    let dividers: [TimelineDivider]
    let showTimes: Bool
    private var lanes = LaneSettings()
    @AppStorage(PrefKey.newestFirst) private var newestFirst = false

    init(title: String, subtitle: String, yAxisLabel: String, background: CanvasBackground,
         layout: TimelineLayout, events: [TimelineEvent], dividers: [TimelineDivider] = [], showTimes: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.yAxisLabel = yAxisLabel
        self.background = background
        self.layout = layout
        self.events = events
        self.dividers = dividers
        self.showTimes = showTimes
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineHeader(title: .constant(title), subtitle: .constant(subtitle),
                           meta: TimelineGrouping.summary(for: events), editable: false)
                .padding(.top, 16)

            HStack(alignment: .top, spacing: 0) {
                if !yAxisLabel.isEmpty {
                    YAxisColumn(label: yAxisLabel)
                }
                TimelineLayoutContent(entries: TimelineGrouping.entries(events: events, dividers: dividers,
                                                                        newestFirst: newestFirst),
                                      layout: layout, isMultiLane: lanes.isMultiLane, laneCount: lanes.count,
                                      showTimes: showTimes)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .background(background.fill)
        .environment(\.canvasBaseColor, background.baseColor)
        .environment(\.isExporting, true)
    }
}

/// Picks the view for the current layout and number of timelines. Shared by the live canvas and export,
/// which sizes the vertical layouts to a fixed width.
private struct TimelineLayoutContent: View {
    let entries: [TimelineEntry]
    let layout: TimelineLayout
    let isMultiLane: Bool
    let laneCount: Int
    let showTimes: Bool
    @Environment(\.isExporting) private var isExporting

    var body: some View {
        switch (layout, isMultiLane) {
        case (.vertical, true), (.alternating, true):
            LanesVerticalView(months: TimelineGrouping.months(from: entries), showTimes: showTimes)
                .frame(width: isExporting ? CGFloat(laneCount) * 440 : nil)
        case (.horizontal, true):
            LanesHorizontalView(entries: entries, showTimes: showTimes)
        case (.vertical, false), (.alternating, false):
            VerticalTimelineView(months: TimelineGrouping.months(from: entries),
                                 alternating: layout == .alternating, showTimes: showTimes)
                .frame(width: isExporting ? (layout == .alternating ? 1000 : 880) : nil)
        case (.horizontal, false):
            HorizontalTimelineView(entries: entries, showTimes: showTimes)
        }
    }
}
