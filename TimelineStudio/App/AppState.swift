import SwiftUI
import Observation

/// Actions that can be triggered from menus/keyboard shortcuts and handled by the main window.
enum TimelineAction: Equatable {
    case newEvent
    case importCSV
    case exportPDF
    case exportImage
    case toggleInspector
    case loadSample
    case expandAllNotes
    case collapseAllNotes
    case manageCategories
    case startPresentation
    case loadComparisonSample
    case loadThreeTimelineSample
    case newDivider
    case exportPackage
    case openPackage
    case showAI
}

enum EditorTarget: Identifiable {
    case new(Date?)
    case edit(TimelineEvent)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let event): event.id.uuidString
        }
    }
}

@Observable
final class AppState {
    var editorTarget: EditorTarget?
    var dividerTarget: DividerTarget?
    var isInspectorPresented = false
    var isPresenting = false
    var expandedEvents: Set<UUID> = []
    var pendingAction: TimelineAction?
    /// The event whose linked file is open in the viewer. Nil hides the viewer.
    var attachmentEventID: UUID?
    /// Shown on the timeline after a natural-language change. Nil hides it.
    var aiNotice: AIResultNotice?

    func perform(_ action: TimelineAction) {
        pendingAction = action
    }
}
