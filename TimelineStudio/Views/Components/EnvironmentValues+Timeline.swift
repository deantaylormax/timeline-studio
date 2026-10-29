import SwiftUI

/// Callbacks that event cards use to talk back to the window without owning its state.
struct EventActions {
    var isExpanded: (UUID) -> Bool = { _ in false }
    var toggle: (TimelineEvent) -> Void = { _ in }
    var edit: (TimelineEvent) -> Void = { _ in }
    var duplicate: (TimelineEvent) -> Void = { _ in }
    var delete: (TimelineEvent) -> Void = { _ in }
    var moveToLane: (TimelineEvent, Int) -> Void = { _, _ in }
    var addDivider: (Date) -> Void = { _ in }
    var editDivider: (TimelineDivider) -> Void = { _ in }
    var deleteDivider: (TimelineDivider) -> Void = { _ in }
    var moveDivider: (TimelineDivider, Date) -> Void = { _, _ in }
    var openAttachment: (TimelineEvent) -> Void = { _ in }
}

private struct EventActionsKey: EnvironmentKey {
    static let defaultValue = EventActions()
}

private struct IsExportingKey: EnvironmentKey {
    static let defaultValue = false
}

private struct CanvasBaseColorKey: EnvironmentKey {
    static let defaultValue: Color = CanvasBackground.paper.baseColor
}

private struct CategoryCatalogKey: EnvironmentKey {
    static let defaultValue = CategoryCatalog()
}

extension EnvironmentValues {
    var eventActions: EventActions {
        get { self[EventActionsKey.self] }
        set { self[EventActionsKey.self] = newValue }
    }

    /// True while the view tree is being rendered into a PDF or image.
    var isExporting: Bool {
        get { self[IsExportingKey.self] }
        set { self[IsExportingKey.self] = newValue }
    }

    /// The canvas background color, used to "cut" the spine around nodes.
    var canvasBaseColor: Color {
        get { self[CanvasBaseColorKey.self] }
        set { self[CanvasBaseColorKey.self] = newValue }
    }

    var categoryCatalog: CategoryCatalog {
        get { self[CategoryCatalogKey.self] }
        set { self[CategoryCatalogKey.self] = newValue }
    }
}
