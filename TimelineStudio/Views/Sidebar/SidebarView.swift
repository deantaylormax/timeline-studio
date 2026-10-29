import SwiftUI

enum SidebarID {
    static let all = "__all__"
}

struct SidebarView: View {
    @Binding var selection: Set<String>
    let events: [TimelineEvent]
    let onManageCategories: () -> Void
    @Environment(\.categoryCatalog) private var catalog
    private var lanes = LaneSettings()

    init(selection: Binding<Set<String>>, events: [TimelineEvent], onManageCategories: @escaping () -> Void) {
        _selection = selection
        self.events = events
        self.onManageCategories = onManageCategories
    }

    var body: some View {
        let counts = Dictionary(grouping: events) { catalog.category(for: $0.categoryID).id }.mapValues(\.count)

        List(selection: $selection) {
            // A section header here pins into the title bar and lands under the traffic lights.
            // All Events is the library; it sits with the rows, below the window controls.
            row(title: "All Events", count: events.count) {
                IconTile(symbol: "calendar.day.timeline.left", color: .accentColor, size: 22, rounded: true)
            }
            .tag(SidebarID.all)

            if lanes.isMultiLane {
                let laneCounts = Dictionary(grouping: events, by: lanes.lane(of:)).mapValues(\.count)
                Section("Timelines") {
                    ForEach(lanes.order, id: \.self) { lane in
                        row(title: lanes.label(lane), count: laneCounts[lane] ?? 0) {
                            Circle()
                                .fill(Lanes.tints[lane].gradient)
                                .frame(width: 10, height: 10)
                                .frame(width: 22, height: 22)
                        }
                    }
                }
            }

            Section("Categories") {
                ForEach(catalog.all) { category in
                    row(title: category.name, count: counts[category.id] ?? 0) {
                        CategoryBadge(category: category, size: 22, rounded: true)
                    }
                    .tag(category.id)
                    .contextMenu {
                        if lanes.isMultiLane {
                            Menu("Move All \(category.name) Events To") {
                                ForEach(lanes.order, id: \.self) { lane in
                                    Button(lanes.label(lane)) { move(category, toLane: lane) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            OverviewCard(events: events, onManageCategories: onManageCategories)
                .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func move(_ category: EventCategory, toLane lane: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            for event in events where catalog.category(for: event.categoryID).id == category.id {
                event.laneIndex = lane
            }
        }
    }

    private func row<Icon: View>(title: String, count: Int, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 9) {
            icon()
            Text(title).lineLimit(1)
            Spacer(minLength: 4)
            if count > 0 {
                Text("\(count)")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }
}

private struct OverviewCard: View {
    let events: [TimelineEvent]
    let onManageCategories: () -> Void

    private var span: String {
        guard let first = events.first?.date, let last = events.last?.date else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        switch days {
        case 0: return "1 day"
        case ..<60: return "\(days + 1) days"
        case ..<730: return "\(Int((Double(days) / 30.4).rounded())) mo"
        default: return String(format: "%.1f yr", Double(days) / 365.25)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OVERVIEW")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 18) {
                stat(value: "\(events.count)", label: "Events")
                stat(value: span, label: "Span")
            }

            Divider()

            Button(action: onManageCategories) {
                Label("Manage Categories…", systemImage: "square.grid.2x2")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
