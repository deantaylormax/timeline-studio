import SwiftUI

/// How a newly revealed event enters the center of a presentation.
enum PresentationEntrance: String, CaseIterable, Identifiable {
    case appear, fade, rise, slide, grow, zoom, pop, blurIn, flip, drop, unfold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appear: "Appear"
        case .fade: "Fade In"
        case .rise: "Rise"
        case .slide: "Slide In"
        case .grow: "Grow"
        case .zoom: "Zoom"
        case .pop: "Pop"
        case .blurIn: "Blur In"
        case .flip: "Flip"
        case .drop: "Drop"
        case .unfold: "Unfold"
        }
    }

    var animation: Animation {
        switch self {
        case .appear: .linear(duration: 0)
        case .pop: .spring(response: 0.45, dampingFraction: 0.55)
        case .flip, .unfold: .easeOut(duration: 0.55)
        case .fade, .blurIn: .easeInOut(duration: 0.6)
        default: .spring(response: 0.55, dampingFraction: 1)
        }
    }

}

/// The "before" state of each entrance; SwiftUI animates from it to the identity state.
struct EntranceModifier: ViewModifier {
    let effect: PresentationEntrance
    let isActive: Bool
    let axis: Axis
    let fromLeading: Bool

    private var opacity: Double { isActive ? 0 : 1 }

    private var scale: CGFloat {
        guard isActive else { return 1 }
        switch effect {
        case .grow: return 0.6
        case .zoom: return 1.45
        case .pop: return 0.4
        default: return 1
        }
    }

    private var offset: CGSize {
        guard isActive else { return .zero }
        switch effect {
        case .rise:
            return axis == .vertical ? CGSize(width: 0, height: 90) : CGSize(width: 0, height: 60)
        case .drop:
            return CGSize(width: 0, height: -110)
        case .slide:
            return axis == .vertical
                ? CGSize(width: fromLeading ? -160 : 160, height: 0)
                : CGSize(width: 180, height: 0)
        default:
            return .zero
        }
    }

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .scaleEffect(x: 1, y: isActive && effect == .unfold ? 0.02 : 1, anchor: .center)
            .rotation3DEffect(.degrees(isActive && effect == .flip ? 90 : 0),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .blur(radius: isActive && effect == .blurIn ? 22 : 0)
            .offset(offset)
    }
}

/// How an event looks once it has moved out of the center position.
enum PresentationExit: String, CaseIterable, Identifiable {
    case shrinkAndDim, dim, shrink, fadeAway, blur, blurAndDim, grayscale, recede, slideAside, none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shrinkAndDim: "Shrink & Dim"
        case .dim: "Dim"
        case .shrink: "Shrink"
        case .fadeAway: "Fade Away"
        case .blur: "Blur"
        case .blurAndDim: "Blur & Dim"
        case .grayscale: "Grayscale"
        case .recede: "Recede"
        case .slideAside: "Slide Aside"
        case .none: "No Change"
        }
    }

    var opacity: Double {
        switch self {
        case .shrinkAndDim, .dim: 0.38
        case .blurAndDim: 0.45
        case .fadeAway: 0
        case .recede, .slideAside: 0.5
        case .grayscale: 0.85
        case .shrink, .blur, .none: 1
        }
    }

    var saturation: Double {
        switch self {
        case .shrinkAndDim, .dim, .blurAndDim: 0.55
        case .grayscale: 0
        default: 1
        }
    }

    var blurRadius: CGFloat {
        switch self {
        case .blur: 4
        case .blurAndDim: 2.5
        default: 0
        }
    }

    var cardScale: CGFloat {
        switch self {
        case .shrinkAndDim, .shrink: 0.94
        case .recede: 0.9
        default: 1
        }
    }

    var nodeScale: CGFloat {
        switch self {
        case .none: 1
        case .shrinkAndDim, .shrink, .recede: 0.8
        default: 0.9
        }
    }

    /// Tilt away from the viewer, in degrees.
    var tilt: Double { self == .recede ? 28 : 0 }

    /// Distance the card moves away from the spine.
    var sideShift: CGFloat { self == .slideAside ? 70 : 0 }
}
