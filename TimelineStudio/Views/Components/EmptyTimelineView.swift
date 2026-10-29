import SwiftUI

struct EmptyTimelineView: View {
    let onNew: () -> Void
    let onImport: () -> Void
    let onSample: () -> Void

    @State private var appeared = false

    private let illustrationItems: [(category: EventCategory, width: CGFloat)] = [
        (EventCategory.builtIn(EventCategory.messageID), 132),
        (EventCategory.builtIn(EventCategory.meetingID), 98),
        (EventCategory.builtIn(EventCategory.purchaseID), 116),
    ]

    var body: some View {
        VStack(spacing: 0) {
            illustration
                .padding(.bottom, 30)

            Text("Start Your Timeline")
                .font(.system(size: 26, weight: .bold))

            Text("Add moments one at a time, or import a CSV and watch your story take shape.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .padding(.top, 8)

            HStack(spacing: 12) {
                Button(action: onNew) {
                    Label("New Event", systemImage: "plus")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onImport) {
                    Label("Import CSV…", systemImage: "square.and.arrow.down")
                        .padding(.horizontal, 6)
                }
            }
            .controlSize(.large)
            .padding(.top, 26)

            Button("Explore a sample timeline", action: onSample)
                .buttonStyle(.link)
                .padding(.top, 16)

            Button(LegalAI.offer) { LegalAI.openSite() }
                .buttonStyle(.link)
                .padding(.top, 10)

            Text("⌘N  New Event     ⇧⌘I  Import CSV")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.top, 28)
        }
        .padding(40)
        .onAppear { appeared = true }
    }

    private var illustration: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(illustrationItems.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 14) {
                    CategoryBadge(category: item.category, size: 34)
                        .shadow(color: item.category.color.opacity(0.35), radius: 6, y: 3)
                        .padding(3)
                        .background(Circle().fill(Palette.cardFill))
                    VStack(alignment: .leading, spacing: 7) {
                        Capsule().fill(.primary.opacity(0.13)).frame(width: item.width, height: 8)
                        Capsule().fill(.primary.opacity(0.06)).frame(width: item.width * 0.68, height: 8)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.1 + Double(index) * 0.12), value: appeared)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 28)
        .background(alignment: .leading) {
            Rectangle()
                .fill(Palette.spine)
                .frame(width: 2)
                .padding(.leading, 28 + 20 - 1)
                .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.cardFill)
                .shadow(color: .black.opacity(0.08), radius: 24, y: 10)
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.cardStroke, lineWidth: 0.5))
    }
}
