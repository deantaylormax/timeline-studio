import SwiftUI

enum PrefKey {
    static let title = "timelineTitle"
    static let subtitle = "timelineSubtitle"
    static let yAxisLabel = "timelineYAxisLabel"
    static let showYAxis = "timelineShowYAxis"
    static let background = "timelineBackground"
    static let layout = "timelineLayout"
    static let newestFirst = "timelineNewestFirst"
    static let showTimes = "timelineShowTimes"
    static let presentationEntrance = "timelinePresentationEntrance"
    static let presentationExit = "timelinePresentationExit"
    static let aiProvider = "aiModelProvider"
    static let aiModelName = "aiModelName"
    static let aiBaseURL = "aiModelBaseURL"
}

enum TimelineDefaults {
    static let title = "My Timeline"
}

enum TimelineLayout: String, CaseIterable, Identifiable {
    case vertical, alternating, horizontal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vertical: "Vertical"
        case .alternating: "Alternating"
        case .horizontal: "Horizontal"
        }
    }

    var symbol: String {
        switch self {
        case .vertical: "list.bullet.below.rectangle"
        case .alternating: "square.split.2x1"
        case .horizontal: "timeline.selection"
        }
    }
}

/// Subtle, professional canvas backgrounds. Each adapts to light and dark mode.
enum CanvasBackground: String, CaseIterable, Identifiable {
    case paper, coolGray, warmBeige, blueGray, gradient, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paper: "Paper"
        case .coolGray: "Cool Gray"
        case .warmBeige: "Warm Beige"
        case .blueGray: "Blue Gray"
        case .gradient: "Gradient"
        case .system: "System"
        }
    }

    /// A single representative color, used for cut-outs around nodes on the spine.
    var baseColor: Color {
        switch self {
        case .paper: Color(lightHex: 0xF8F7F4, darkHex: 0x1C1C1A)
        case .coolGray: Color(lightHex: 0xF3F4F6, darkHex: 0x1A1B1E)
        case .warmBeige: Color(lightHex: 0xF5EFE6, darkHex: 0x201C17)
        case .blueGray: Color(lightHex: 0xECF0F5, darkHex: 0x171B21)
        case .gradient: Color(lightHex: 0xF5F6F9, darkHex: 0x1A1B1D)
        case .system: Color(nsColor: .windowBackgroundColor)
        }
    }

    var fill: AnyShapeStyle {
        switch self {
        case .gradient:
            AnyShapeStyle(LinearGradient(
                colors: [Color(lightHex: 0xFCFCFD, darkHex: 0x202124), Color(lightHex: 0xEEF1F6, darkHex: 0x141517)],
                startPoint: .top, endPoint: .bottom))
        default:
            AnyShapeStyle(baseColor)
        }
    }
}

extension PrefKey {
    static let laneCount = "timelineLaneCount"
    static let laneLabelSide = "timelineLaneLabelSide"
    static let laneOrder = "timelineLaneOrder"
    static func laneLabel(_ index: Int) -> String { "timelineLaneLabel\(index)" }
}

/// Where each parallel timeline's label sits.
enum LaneLabelSide: String, CaseIterable, Identifiable {
    case leading, trailing

    var id: String { rawValue }
    var title: String { self == .leading ? "Left" : "Right" }
}

enum Lanes {
    static let maxCount = 3
    static let tints: [Color] = [CategoryTint.indigo.color, CategoryTint.orange.color, CategoryTint.teal.color]

    static func defaultLabel(_ index: Int) -> String { "Timeline \(index + 1)" }

    /// Visual order of the lane indexes `0..<count`. Unknown or repeated values are dropped,
    /// and any lane that isn't listed is appended so every visible timeline still appears.
    static func normalizedOrder(_ raw: String, count: Int) -> [Int] {
        let visible = Array(0..<max(count, 0))
        var seen = Set<Int>()
        var result: [Int] = []
        for part in raw.split(separator: ",") {
            guard let index = Int(part), visible.contains(index), seen.insert(index).inserted else { continue }
            result.append(index)
        }
        for index in visible where seen.insert(index).inserted {
            result.append(index)
        }
        return result
    }

    static func encodedOrder(_ order: [Int]) -> String {
        order.map(String.init).joined(separator: ",")
    }
}

/// The parallel-timeline settings, readable from any view.
struct LaneSettings: DynamicProperty {
    @AppStorage(PrefKey.laneCount) var storedCount = 1
    @AppStorage(PrefKey.laneLabel(0)) var label0 = Lanes.defaultLabel(0)
    @AppStorage(PrefKey.laneLabel(1)) var label1 = Lanes.defaultLabel(1)
    @AppStorage(PrefKey.laneLabel(2)) var label2 = Lanes.defaultLabel(2)
    @AppStorage(PrefKey.laneLabelSide) var side: LaneLabelSide = .leading
    @AppStorage(PrefKey.laneOrder) var orderRaw = ""

    var count: Int { min(max(storedCount, 1), Lanes.maxCount) }
    var isMultiLane: Bool { count > 1 }

    /// Lane indexes in the order they are drawn. The first one is the left column, or the top row.
    var order: [Int] { Lanes.normalizedOrder(orderRaw, count: count) }

    /// Swaps a timeline with the one `delta` places away in the visual order. `-1` moves it earlier.
    func move(from position: Int, by delta: Int) {
        var next = order
        let target = position + delta
        guard next.indices.contains(position), next.indices.contains(target) else { return }
        next.swapAt(position, target)
        UserDefaults.standard.set(Lanes.encodedOrder(next), forKey: PrefKey.laneOrder)
    }

    func label(_ index: Int) -> String {
        let label = [label0, label1, label2][index].trimmingCharacters(in: .whitespaces)
        return label.isEmpty ? Lanes.defaultLabel(index) : label
    }

    /// The stored (possibly empty) label, for editing.
    func labelBinding(_ index: Int) -> Binding<String> {
        switch index {
        case 0: $label0
        case 1: $label1
        default: $label2
        }
    }

    /// Events assigned to a timeline that's been turned off show on the last visible one.
    func lane(of event: TimelineEvent) -> Int {
        min(max(event.laneIndex, 0), count - 1)
    }
}
