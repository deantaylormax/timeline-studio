import SwiftUI

extension VerticalAlignment {
    private enum SpineAlignment: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }

    /// Aligns every column's node on a single horizontal spine.
    static let spine = VerticalAlignment(SpineAlignment.self)
}

/// A compact, graph-like layout: events alternate above and below a horizontal spine.
struct HorizontalTimelineView: View {
    let entries: [TimelineEntry]
    let showTimes: Bool

    @Environment(\.isExporting) private var isExporting
    @Environment(\.categoryCatalog) private var catalog
    @Environment(\.canvasBaseColor) private var baseColor

    private enum Item: Identifiable {
        case month(Date)
        case event(TimelineEvent, Int)
        case divider(TimelineDivider)

        var id: String {
            switch self {
            case .month(let date): "month-\(date.timeIntervalSince1970)"
            case .event(let event, _): event.id.uuidString
            case .divider(let divider): divider.id.uuidString
            }
        }
    }

    private var items: [Item] {
        var result: [Item] = []
        var lastMonth: Date?
        var eventIndex = 0
        for entry in entries {
            let month = Calendar.current.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
            if month != lastMonth {
                result.append(.month(month))
                lastMonth = month
            }
            switch entry {
            case .event(let event):
                result.append(.event(event, eventIndex))
                eventIndex += 1
            case .divider(let divider):
                result.append(.divider(divider))
            }
        }
        return result
    }

    var body: some View {
        if isExporting {
            strip
        } else {
            ScrollView(.horizontal) {
                strip.frame(maxHeight: .infinity)
            }
        }
    }

    private var strip: some View {
        HStack(alignment: .spine, spacing: 0) {
            cap(fadingIn: true)
            ForEach(items) { item in
                switch item {
                case .month(let date):
                    monthMarker(date)
                case .event(let event, let index):
                    HorizontalEventColumn(event: event,
                                          category: catalog.category(for: event.categoryID),
                                          above: index.isMultiple(of: 2),
                                          showTimes: showTimes)
                        .reportsEntryFrame(id: event.id, date: event.date)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                case .divider(let divider):
                    dividerColumn(divider)
                        .draggableDivider(divider, axis: .horizontal)
                        .reportsEntryFrame(id: divider.id, date: divider.date)
                        .transition(.opacity)
                }
            }
            cap(fadingIn: false)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .supportsDividerDragging(axis: .horizontal)
    }

    /// A vertical chapter line through the spine, with its label above.
    private func dividerColumn(_ divider: TimelineDivider) -> some View {
        let halfLine: CGFloat = 150
        return VStack(spacing: 8) {
            DividerLabel(divider: divider)
            DividerStyle.line(.vertical).frame(height: halfLine * 2)
        }
        .frame(width: 170)
        .background(alignment: .bottom) {
            Rectangle().fill(Palette.spine).frame(height: 2).padding(.bottom, halfLine - 1)
        }
        .alignmentGuide(.spine) { d in d.height - halfLine }
    }

    private func cap(fadingIn: Bool) -> some View {
        let colors = [Palette.spine.opacity(0), Palette.spine]
        return Rectangle()
            .fill(LinearGradient(colors: fadingIn ? colors : colors.reversed(), startPoint: .leading, endPoint: .trailing))
            .frame(width: 36, height: 2)
            .alignmentGuide(.spine) { d in d[VerticalAlignment.center] }
    }

    private func monthMarker(_ date: Date) -> some View {
        Text(date.formatted(.dateTime.month(.abbreviated).year()))
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .surface(Capsule(), exporting: isExporting)
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background { Rectangle().fill(Palette.spine).frame(height: 2) }
            .alignmentGuide(.spine) { d in d[VerticalAlignment.center] }
    }
}

private struct HorizontalEventColumn: View {
    let event: TimelineEvent
    let category: EventCategory
    let above: Bool
    let showTimes: Bool

    var body: some View {
        VStack(spacing: 0) {
            if above {
                card
                stem
            } else {
                dateLabel.padding(.bottom, 8)
            }

            TimelineNode(category: category)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background { Rectangle().fill(Palette.spine).frame(height: 2) }
                .alignmentGuide(.spine) { d in d[VerticalAlignment.center] }

            if above {
                dateLabel.padding(.top, 8)
            } else {
                stem
                card
            }
        }
        .frame(width: 236)
    }

    private var card: some View {
        EventCard(event: event, category: category, compact: true, maxWidth: 218)
            .padding(.horizontal, 9)
    }

    private var stem: some View {
        Rectangle()
            .fill(category.color.opacity(0.4))
            .frame(width: 1.5, height: 16)
    }

    private var dateLabel: some View {
        VStack(spacing: 2) {
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
