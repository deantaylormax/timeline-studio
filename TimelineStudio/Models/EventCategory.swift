import SwiftUI
import AppKit

/// Refined, system-adaptive tints used for event categories.
enum CategoryTint: String, CaseIterable, Identifiable {
    case blue, green, indigo, orange, teal, purple, gray, pink, red, yellow, mint, cyan, brown

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: Color(nsColor: .systemBlue)
        case .green: Color(nsColor: .systemGreen)
        case .indigo: Color(nsColor: .systemIndigo)
        case .orange: Color(nsColor: .systemOrange)
        case .teal: Color(nsColor: .systemTeal)
        case .purple: Color(nsColor: .systemPurple)
        case .gray: Color(nsColor: .systemGray)
        case .pink: Color(nsColor: .systemPink)
        case .red: Color(nsColor: .systemRed)
        case .yellow: Color(nsColor: .systemYellow)
        case .mint: Color(nsColor: .systemMint)
        case .cyan: Color(nsColor: .systemCyan)
        case .brown: Color(nsColor: .systemBrown)
        }
    }
}

struct EventCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let tint: CategoryTint
    var isBuiltIn: Bool = true
    var keywords: [String] = []

    var color: Color { tint.color }

    static let messageID = "message"
    static let callID = "call"
    static let emailID = "email"
    static let meetingID = "meeting"
    static let outingID = "outing"
    static let purchaseID = "purchase"
    static let noteID = "note"

    static let builtIns: [EventCategory] = [
        EventCategory(id: messageID, name: "Text Message", symbol: "message.fill", tint: .blue,
                      keywords: ["text", "sms", "message", "imessage", "texted", "chat", "whatsapp"]),
        EventCategory(id: callID, name: "Phone Call", symbol: "phone.fill", tint: .green,
                      keywords: ["call", "phone", "voicemail", "facetime", "called"]),
        EventCategory(id: emailID, name: "Email", symbol: "envelope.fill", tint: .indigo,
                      keywords: ["email", "e-mail", "mail", "emailed"]),
        EventCategory(id: meetingID, name: "Meeting", symbol: "person.2.fill", tint: .orange,
                      keywords: ["meeting", "in-person", "in person", "inperson", "meet", "met", "appointment"]),
        EventCategory(id: outingID, name: "Outing", symbol: "mappin.and.ellipse", tint: .teal,
                      keywords: ["outing", "event", "physical", "trip", "visit", "activity", "physical event"]),
        EventCategory(id: purchaseID, name: "Purchase", symbol: "cart.fill", tint: .purple,
                      keywords: ["purchase", "buy", "bought", "order", "payment", "receipt", "transaction"]),
        EventCategory(id: noteID, name: "Note", symbol: "note.text", tint: .gray,
                      keywords: ["note", "other", "misc", "general"]),
    ]

    static func builtIn(_ id: String) -> EventCategory {
        builtIns.first { $0.id == id } ?? builtIns[builtIns.count - 1]
    }
}

/// Resolves category IDs (built-in or custom) to display information.
struct CategoryCatalog {
    let all: [EventCategory]

    init(custom: [CustomCategory] = []) {
        all = EventCategory.builtIns + custom.map(\.category)
    }

    func category(for id: String) -> EventCategory {
        all.first { $0.id == id } ?? EventCategory.builtIn(EventCategory.noteID)
    }

    /// Best-effort match for free-form type text, e.g. from a CSV "type" column.
    func match(_ raw: String) -> EventCategory? {
        let key = Self.normalize(raw)
        guard !key.isEmpty else { return nil }

        if let exact = all.first(where: { category in
            Self.normalize(category.id) == key
                || Self.normalize(category.name) == key
                || category.keywords.contains { Self.normalize($0) == key }
        }) {
            return exact
        }

        return all.first { category in
            key.contains(Self.normalize(category.name))
                || category.keywords.contains { keyword in
                    let normalized = Self.normalize(keyword)
                    return normalized.count >= 4 && key.contains(normalized)
                }
        }
    }

    static func normalize(_ string: String) -> String {
        String(string.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }
}
