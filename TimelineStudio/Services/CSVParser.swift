import Foundation

/// A small RFC 4180-style CSV parser that handles quoted fields, escaped quotes,
/// embedded newlines, and auto-detects comma / semicolon / tab / pipe delimiters.
enum CSVParser {
    static func parse(_ input: String) -> [[String]] {
        var text = input
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let delimiter = detectDelimiter(in: text)

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"" where field.trimmingCharacters(in: .whitespaces).isEmpty:
                    field = ""
                    inQuotes = true
                case delimiter:
                    row.append(field)
                    field = ""
                case "\n", "\r\n", "\r":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                default:
                    field.append(character)
                }
            }
            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
            .map { $0.map { $0.trimmingCharacters(in: .whitespaces) } }
            .filter { !$0.allSatisfy(\.isEmpty) }
    }

    static func detectDelimiter(in text: String) -> Character {
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r\n" && $0 != "\r" }
        var best: Character = ","
        var bestCount = 0
        for candidate in [",", ";", "\t", "|"] as [Character] {
            var count = 0
            var inQuotes = false
            for character in firstLine {
                if character == "\"" {
                    inQuotes.toggle()
                } else if character == candidate, !inQuotes {
                    count += 1
                }
            }
            if count > bestCount {
                best = candidate
                bestCount = count
            }
        }
        return best
    }
}
