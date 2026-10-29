import AppKit
import SwiftUI

/// The public site where LegalAI builds a chronology from the case file.
enum LegalAI {
    static let site = URL(string: "https://legalai.com/")!

    static let offer = "LegalAI can build this chronology from the file."

    static func openSite() {
        NSWorkspace.shared.open(site)
    }
}

/// Shown from the AI button. The timeline stays free. Building it from the file happens at LegalAI.
struct LegalAIHandoffView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LegalAI")
                .font(.title2.weight(.semibold))
            Text(LegalAI.offer)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open LegalAI") {
                    LegalAI.openSite()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
