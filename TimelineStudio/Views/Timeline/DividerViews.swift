import SwiftUI
import AppKit

/// A straight dashed line along one axis, filling its frame.
struct DashedLine: Shape {
    let axis: Axis

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if axis == .horizontal {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        } else {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        return path
    }
}

enum DividerStyle {
    static let lineColor = Color.accentColor.opacity(0.5)
    static let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 5])

    /// The chapter line itself, along `axis`, filling the space it's given.
    static func line(_ axis: Axis) -> some View {
        DashedLine(axis: axis)
            .stroke(lineColor, style: stroke)
            .frame(width: axis == .vertical ? 2 : nil, height: axis == .horizontal ? 2 : nil)
    }
}

/// A divider's name in a pill with a bookmark glyph.
/// When interactive (the main view), clicking it edits the divider, hovering reveals a delete button,
/// and right-clicking offers Edit/Delete. Dragging is handled by the row around it (`draggableDivider`).
struct DividerLabel: View {
    let divider: TimelineDivider
    var isInteractive = true
    var emphasized = false

    @Environment(\.eventActions) private var actions
    @Environment(\.isExporting) private var isExporting
    @State private var isHovering = false

    private var interactive: Bool { isInteractive && !isExporting }

    var body: some View {
        if interactive {
            pill
                .onTapGesture { actions.editDivider(divider) }
                .onHover { hovering in withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering } }
                .help("Click to edit, drag to move")
                .contextMenu {
                    Button("Edit Divider…") { actions.editDivider(divider) }
                    Divider()
                    Button("Delete Divider", role: .destructive) { actions.deleteDivider(divider) }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Divider: \(divider.displayTitle)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { actions.editDivider(divider) }
                .accessibilityAction(named: "Delete") { actions.deleteDivider(divider) }
        } else {
            pill
        }
    }

    private var pill: some View {
        HStack(spacing: 6) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: emphasized ? 12 : 10, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(divider.displayTitle)
                .font(.system(size: emphasized ? 15 : 12.5, weight: .semibold))
                .lineLimit(1)
            if interactive && isHovering {
                Button { actions.deleteDivider(divider) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete this divider")
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .padding(.horizontal, emphasized ? 14 : 11)
        .padding(.vertical, emphasized ? 7 : 5)
        .surface(Capsule(), exporting: isExporting)
        .background {
            Capsule()
                .fill(Color.accentColor)
                .padding(-1)
                .opacity(isHovering && interactive ? 0.45 : 0)
        }
        .contentShape(Capsule())
    }
}

// MARK: - Dragging

enum DividerDrag {
    /// The coordinate space of a timeline's scrolling content, shared by entries and the dragged divider.
    static let space = "timelineContent"
}

/// Where an event or divider sits in the timeline's content, and when it happens.
struct EntryFrame: Equatable {
    let date: Date
    let rect: CGRect
}

#if DEBUG
/// Lets the debug harness check drop resolution against a real layout.
@MainActor
enum DividerDragDebug {
    /// Recent resolvers from every timeline on screen (the main window may be open too).
    static var recentResolvers: [DividerDropResolver] = []

    static func resolver(containing id: UUID) -> DividerDropResolver? {
        recentResolvers.last { $0.frames[id] != nil }
    }
}
#endif

private struct EntryFramesKey: PreferenceKey {
    static let defaultValue: [UUID: EntryFrame] = [:]

    static func reduce(value: inout [UUID: EntryFrame], nextValue: () -> [UUID: EntryFrame]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Turns a drop position into a time: halfway between the entries on either side of it.
struct DividerDropResolver {
    var axis: Axis = .vertical
    var frames: [UUID: EntryFrame] = [:]

    private func center(_ frame: EntryFrame) -> CGFloat {
        axis == .vertical ? frame.rect.midY : frame.rect.midX
    }

    func center(of id: UUID) -> CGFloat? {
        frames[id].map(center)
    }

    func date(at position: CGFloat, excluding id: UUID) -> Date? {
        let others = frames.filter { $0.key != id }.values.sorted { center($0) < center($1) }
        guard !others.isEmpty else { return nil }
        let before = others.last { center($0) < position }
        let after = others.first { center($0) >= position }
        switch (before, after) {
        case let (before?, after?):
            return before.date.addingTimeInterval(after.date.timeIntervalSince(before.date) / 2)
        case let (before?, nil):
            return before.date.addingTimeInterval(60 * direction(others))
        case let (nil, after?):
            return after.date.addingTimeInterval(-60 * direction(others))
        case (nil, nil):
            return nil
        }
    }

    /// +1 when time runs forward along the axis (oldest first), -1 when newest is first.
    private func direction(_ ordered: [EntryFrame]) -> Double {
        guard let first = ordered.first, let last = ordered.last else { return 1 }
        return last.date >= first.date ? 1 : -1
    }
}

private struct DividerDropResolverKey: EnvironmentKey {
    static let defaultValue = DividerDropResolver()
}

extension EnvironmentValues {
    var dividerDropResolver: DividerDropResolver {
        get { self[DividerDropResolverKey.self] }
        set { self[DividerDropResolverKey.self] = newValue }
    }
}

/// Collects where every entry sits so a dragged divider can tell where it was dropped.
private struct DividerDragContainer: ViewModifier {
    let axis: Axis
    @State private var frames: [UUID: EntryFrame] = [:]

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: DividerDrag.space)
            .onPreferenceChange(EntryFramesKey.self) { frames in
                self.frames = frames
                #if DEBUG
                DividerDragDebug.recentResolvers = Array((DividerDragDebug.recentResolvers + [DividerDropResolver(axis: axis, frames: frames)]).suffix(8))
                #endif
            }
            .environment(\.dividerDropResolver, DividerDropResolver(axis: axis, frames: frames))
    }
}

/// Lets a divider row or column be dragged along the timeline to a new time.
private struct DraggableDivider: ViewModifier {
    let divider: TimelineDivider
    let axis: Axis

    @Environment(\.dividerDropResolver) private var resolver
    @Environment(\.eventActions) private var actions
    @Environment(\.isExporting) private var isExporting
    @State private var translation: CGFloat = 0
    @State private var isDragging = false

    private var targetDate: Date? {
        guard isDragging, let center = resolver.center(of: divider.id) else { return nil }
        return resolver.date(at: center + translation, excluding: divider.id)
    }

    func body(content: Content) -> some View {
        if isExporting {
            content
        } else {
            content
                .contentShape(Rectangle())
                .offset(x: axis == .horizontal ? translation : 0, y: axis == .vertical ? translation : 0)
                .overlay(alignment: axis == .vertical ? .bottom : .top) {
                    if let targetDate {
                        Label(targetDate.formatted(date: .abbreviated, time: .shortened), systemImage: "arrow.down.to.line")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1))
                            .offset(x: axis == .horizontal ? translation : 0,
                                    y: axis == .vertical ? translation + 4 : translation - 4)
                            .allowsHitTesting(false)
                    }
                }
                .opacity(isDragging ? 0.85 : 1)
                .zIndex(isDragging ? 10 : 0)
                .onHover { hovering in
                    if hovering { NSCursor.openHand.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .named(DividerDrag.space))
                        .onChanged { value in
                            if !isDragging { NSCursor.closedHand.push() }
                            isDragging = true
                            translation = axis == .vertical ? value.translation.height : value.translation.width
                        }
                        .onEnded { _ in
                            NSCursor.pop()
                            let date = targetDate
                            // Land in the new slot directly, rather than animating back and then across.
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                if let date { actions.moveDivider(divider, date) }
                                translation = 0
                                isDragging = false
                            }
                        }
                )
        }
    }
}

extension View {
    /// Reports this entry's position, so a dragged divider can work out where it was dropped.
    func reportsEntryFrame(id: UUID, date: Date) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: EntryFramesKey.self,
                                       value: [id: EntryFrame(date: date, rect: proxy.frame(in: .named(DividerDrag.space)))])
            }
        }
    }

    /// Put on a timeline's scrolling content so the dividers inside it can be dragged.
    func supportsDividerDragging(axis: Axis) -> some View {
        modifier(DividerDragContainer(axis: axis))
    }

    /// Makes a divider's row (or column) draggable along `axis` to a new time.
    func draggableDivider(_ divider: TimelineDivider, axis: Axis) -> some View {
        modifier(DraggableDivider(divider: divider, axis: axis))
    }
}

/// A divider across a vertical timeline: a dashed line with the label in the middle.
struct HorizontalDividerBand: View {
    let divider: TimelineDivider
    var isInteractive = true
    var emphasized = false

    var body: some View {
        HStack(spacing: 10) {
            DividerStyle.line(.horizontal)
            DividerLabel(divider: divider, isInteractive: isInteractive, emphasized: emphasized)
                .layoutPriority(1)
            DividerStyle.line(.horizontal)
        }
    }
}
