import Foundation
import SwiftData

/// A labelled chapter line dropped at a moment in time, e.g. "Person arrives".
/// It spans every timeline and sorts just before any event at the same instant.
@Model
final class TimelineDivider {
    var id: UUID = UUID()
    var date: Date = Date.now
    var title: String = ""
    var createdAt: Date = Date.now

    init(date: Date, title: String) {
        self.id = UUID()
        self.date = date
        self.title = title
        self.createdAt = .now
    }

    var displayTitle: String { title.isEmpty ? "Untitled Divider" : title }
}
