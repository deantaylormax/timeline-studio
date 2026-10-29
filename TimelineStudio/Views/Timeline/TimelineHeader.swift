import SwiftUI

/// Graph-style title block. Editable in place when live; static text when exporting.
struct TimelineHeader: View {
    @Binding var title: String
    @Binding var subtitle: String
    let meta: String
    var editable = true
    /// A smaller, single-line treatment that leaves more room for the timeline (used while presenting).
    var compact = false

    @State private var isHovering = false
    @FocusState private var focusedField: Field?

    private enum Field { case title, subtitle }

    private var titleFont: Font { .system(size: compact ? 22 : 30, weight: .bold) }
    private var subtitleFont: Font { .system(size: compact ? 13 : 15, weight: .regular) }

    private var showsSubtitleField: Bool {
        !subtitle.isEmpty || isHovering || focusedField != nil
    }

    var body: some View {
        VStack(spacing: 5) {
            if editable {
                TextField("Untitled Timeline", text: $title)
                    .textFieldStyle(.plain)
                    .font(titleFont)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: .title)
                    .onSubmit { focusedField = .subtitle }
                    .help("Click to edit the title")

                if showsSubtitleField {
                    TextField("Add a subtitle", text: $subtitle)
                        .textFieldStyle(.plain)
                        .font(subtitleFont)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .focused($focusedField, equals: .subtitle)
                        .onSubmit { focusedField = nil }
                        .transition(.opacity)
                }
            } else {
                Text(title.isEmpty ? "Untitled Timeline" : title)
                    .font(titleFont)
                    .multilineTextAlignment(.center)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(subtitleFont)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if !meta.isEmpty, !compact {
                Text(meta.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 48)
        .padding(.top, compact ? 12 : 26)
        .padding(.bottom, compact ? 6 : 14)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) { isHovering = hovering }
        }
    }
}

/// A vertical, graph-style axis label shown along the left edge of the timeline.
struct YAxisColumn: View {
    let label: String

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 7))
                .foregroundStyle(Palette.spine)
            Rectangle().fill(Palette.spine).frame(width: 1)
            RotatedLayout {
                Text(label.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
            }
            .padding(.vertical, 12)
            Rectangle().fill(Palette.spine).frame(width: 1)
        }
        .frame(width: 30)
        .padding(.leading, 18)
        .padding(.vertical, 20)
    }
}

/// Lays out a single subview with its width and height swapped, for rotated text.
private struct RotatedLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let size = subviews.first?.sizeThatFits(.unspecified) else { return .zero }
        return CGSize(width: size.height, height: size.width)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
    }
}
