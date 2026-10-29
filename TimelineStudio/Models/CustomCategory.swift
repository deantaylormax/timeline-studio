import Foundation
import SwiftData

/// A user-defined event category, persisted alongside events.
@Model
final class CustomCategory {
    var id: String = UUID().uuidString
    var name: String = ""
    var symbol: String = "star.fill"
    var tintRaw: String = CategoryTint.pink.rawValue
    var createdAt: Date = Date.now

    init(name: String, symbol: String, tint: CategoryTint) {
        self.id = UUID().uuidString
        self.name = name
        self.symbol = symbol
        self.tintRaw = tint.rawValue
        self.createdAt = .now
    }

    var tint: CategoryTint { CategoryTint(rawValue: tintRaw) ?? .gray }

    var category: EventCategory {
        EventCategory(id: id, name: name, symbol: symbol, tint: tint, isBuiltIn: false, keywords: keywords)
    }

    /// The full name, plus each word, so a CSV type of "Hearing" matches "Court Hearing".
    private var keywords: [String] {
        let words = name.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        var results = [name]
        for word in words where !results.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) {
            results.append(word)
        }
        return results
    }
}
