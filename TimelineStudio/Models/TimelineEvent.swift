import Foundation
import SwiftData

@Model
final class TimelineEvent {
    var id: UUID = UUID()
    var date: Date = Date.now
    var isAllDay: Bool = false
    var categoryID: String = EventCategory.noteID
    var title: String = ""
    var notes: String = ""
    var location: String = ""
    var amount: Double?
    var createdAt: Date = Date.now
    /// Which of the (up to three) parallel timelines this event belongs to.
    var laneIndex: Int = 0
    /// Security-scoped bookmark to the original file on this Mac. Nil when nothing is linked.
    var attachmentBookmark: Data?
    var attachmentFileName: String = ""
    var attachmentContentType: String = ""
    /// 1-based PDF page to open. Nil opens at the first page.
    var attachmentPage: Int?
    /// Playback position for audio and video, in seconds.
    var attachmentStart: Double?

    init(
        date: Date,
        isAllDay: Bool = false,
        categoryID: String,
        title: String,
        notes: String = "",
        location: String = "",
        amount: Double? = nil,
        laneIndex: Int = 0
    ) {
        self.id = UUID()
        self.date = date
        self.isAllDay = isAllDay
        self.categoryID = categoryID
        self.title = title
        self.notes = notes
        self.location = location
        self.amount = amount
        self.createdAt = .now
        self.laneIndex = laneIndex
    }

    var hasAttachment: Bool { !attachmentFileName.isEmpty }

    /// "p. 4" or "1:30" when the link opens somewhere other than the start.
    var attachmentPlace: String? {
        if AttachmentKind.detect(contentType: attachmentContentType, fileName: attachmentFileName) == .pdf,
           let attachmentPage, attachmentPage > 1 {
            return "p. \(attachmentPage)"
        }
        if let attachmentStart, attachmentStart > 0.5 {
            return AttachmentTime.format(attachmentStart)
        }
        return nil
    }

    func duplicate() -> TimelineEvent {
        let copy = TimelineEvent(date: date, isAllDay: isAllDay, categoryID: categoryID, title: title,
                                 notes: notes, location: location, amount: amount, laneIndex: laneIndex)
        copy.attachmentBookmark = attachmentBookmark
        copy.attachmentFileName = attachmentFileName
        copy.attachmentContentType = attachmentContentType
        copy.attachmentPage = attachmentPage
        copy.attachmentStart = attachmentStart
        return copy
    }

    func clearAttachment() {
        attachmentBookmark = nil
        attachmentFileName = ""
        attachmentContentType = ""
        attachmentPage = nil
        attachmentStart = nil
    }
}
