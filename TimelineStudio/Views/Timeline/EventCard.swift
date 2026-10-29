import SwiftUI

struct EventCard: View {
    let event: TimelineEvent
    let category: EventCategory
    var compact = false
    var maxWidth: CGFloat = 600
    /// Presentation draws its own control, because the card there ignores clicks.
    var showsAttachmentButton = true

    @Environment(\.eventActions) private var actions
    @Environment(\.isExporting) private var isExporting
    @State private var isHovering = false
    private var lanes = LaneSettings()

    private var isExpanded: Bool { isExporting || actions.isExpanded(event.id) }

    private var notesAreLong: Bool {
        event.notes.count > (compact ? 90 : 160) || event.notes.contains("\n")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: TimelineMetrics.cardCornerRadius, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            Text(category.name.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(category.color)

            Text(event.title.isEmpty ? "Untitled Event" : event.title)
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !event.location.isEmpty || event.amount != nil {
                metadata
            }

            if !event.notes.isEmpty {
                Text(event.notes)
                    .font(.system(size: compact ? 12 : 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .lineLimit(isExpanded ? nil : (compact ? 3 : 2))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                if notesAreLong && !isExporting {
                    HStack(spacing: 3) {
                        Text(isExpanded ? "Show Less" : "Show More")
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(category.color)
                }
            }

            if event.hasAttachment && showsAttachmentButton {
                attachmentControl
            }
        }
        .padding(.horizontal, compact ? 12 : 15)
        .padding(.vertical, compact ? 10 : 13)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background {
            shape.fill(Palette.cardFill)
                .overlay(shape.fill(LinearGradient(
                    colors: [category.color.opacity(0.07), category.color.opacity(0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)))
        }
        .overlay(shape.strokeBorder(isHovering ? category.color.opacity(0.35) : Palette.cardStroke,
                                    lineWidth: isHovering ? 1 : 0.5))
        .overlay(alignment: .topTrailing) {
            if isHovering && !isExporting {
                Button { actions.edit(event) } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("Edit Event")
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .shadow(color: .black.opacity(isHovering ? 0.12 : 0.05), radius: isHovering ? 14 : 6, y: isHovering ? 6 : 2)
        .scaleEffect(isHovering ? 1.005 : 1)
        .contentShape(shape)
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.22)) { isHovering = hovering }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { actions.toggle(event) }
        }
        .contextMenu {
            Button("Edit…") { actions.edit(event) }
            if event.hasAttachment {
                Button("Open Linked File") { actions.openAttachment(event) }
            }
            if !event.notes.isEmpty {
                Button(isExpanded ? "Collapse Notes" : "Expand Notes") {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { actions.toggle(event) }
                }
            }
            Button("Duplicate") { actions.duplicate(event) }
            Button("Add Divider Before…") { actions.addDivider(event.date.addingTimeInterval(-1)) }
            Button("Add Divider After…") { actions.addDivider(event.date.addingTimeInterval(1)) }
            if lanes.isMultiLane {
                Menu("Move to Timeline") {
                    ForEach(lanes.order, id: \.self) { lane in
                        Button(lanes.label(lane)) { actions.moveToLane(event, lane) }
                            .disabled(lanes.lane(of: event) == lane)
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { actions.delete(event) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .modifier(OpenAttachmentAction(isEnabled: event.hasAttachment) { actions.openAttachment(event) })
    }

    @ViewBuilder
    private var attachmentControl: some View {
        if isExporting {
            HStack(spacing: 5) {
                Image(systemName: AttachmentKind.detect(contentType: event.attachmentContentType,
                                                        fileName: event.attachmentFileName).symbol)
                Text(event.attachmentPlace.map { "\(event.attachmentFileName) · \($0)" } ?? event.attachmentFileName)
                    .lineLimit(1)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(category.color)
            .padding(.top, 2)
        } else {
            AttachmentChip(event: event, tint: category.color) {
                actions.openAttachment(event)
            }
            .padding(.top, 2)
        }
    }

    private var metadata: some View {
        HStack(spacing: 12) {
            if !event.location.isEmpty {
                Label(event.location, systemImage: "mappin")
                    .lineLimit(1)
            }
            if let amount = event.amount {
                Label(amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                      systemImage: "creditcard")
                    .monospacedDigit()
            }
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(.secondary)
        .labelStyle(MetadataLabelStyle())
    }
}

private struct OpenAttachmentAction: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    @ViewBuilder func body(content: Content) -> some View {
        if isEnabled {
            content.accessibilityAction(named: "Open Linked File", action)
        } else {
            content
        }
    }
}

private struct MetadataLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            configuration.title
        }
    }
}
