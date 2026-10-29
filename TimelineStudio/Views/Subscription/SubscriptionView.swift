import SwiftUI

/// The two paid plans. A signed license is what turns a plan on in this copy.
struct SubscriptionView: View {
    @Environment(SubscriptionCenter.self) private var subscription
    @Environment(\.dismiss) private var dismiss

    var showsClose: Bool = true

    @State private var licenseKey = ""
    @State private var message: String?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    plans
                    featureSection
                    licenseSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 560, minHeight: 580)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Subscription")
                    .font(.title2.weight(.semibold))
                Text(statusLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if showsClose {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
    }

    private var statusLine: String {
        switch subscription.tier {
        case .free:
            "The timeline is free. AI tools start with Pro or Private AI."
        case .pro:
            "Pro is on until \(expiry). Connect the model you already pay for."
        case .privateAI:
            "Private AI is on until \(expiry). The hosted model is included."
        }
    }

    private var expiry: String {
        subscription.license?.expires.formatted(date: .abbreviated, time: .omitted) ?? ""
    }

    private var plans: some View {
        HStack(alignment: .top, spacing: 12) {
            planCard(
                tier: .pro,
                detail: "Every feature in the list below, using the model you already pay for. The timeline is sent only to the provider you connect.")
            planCard(
                tier: .privateAI,
                detail: "The same list, with the model included. It runs in a Google Cloud Assured Workloads environment. You do not connect a key.")
        }
    }

    private func planCard(tier: SubscriptionTier, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tier.title)
                    .font(.headline)
                Spacer()
                if subscription.tier == tier {
                    Text("Current")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
            }
            Text(tier.price)
                .font(.title3.weight(.semibold))
            if !tier.yearlyPrice.isEmpty {
                Text(tier.yearlyPrice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("License key")
                .font(.headline)
            Text("Paste the license from your subscription. The key itself chooses Pro or Private AI.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("TS1.…", text: $licenseKey)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
            HStack {
                Button("Activate") { activate() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if subscription.tier != .free {
                    Button("Remove License") { subscription.removeLicense() }
                }
                Spacer()
            }
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
            }
        }
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Included with Pro")
                    .font(.headline)
                Text("Private AI includes this same list. “In this version” marks the tools you can run now.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(ProFeatureList.groups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                    if !group.note.isEmpty {
                        Text(group.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(group.features) { feature in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(feature.title)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                            if feature.inThisVersion {
                                Text("In this version")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func activate() {
        do {
            try subscription.activate(licenseKey)
            licenseKey = ""
            failed = false
            message = "\(subscription.tier.title) is on until \(expiry)."
        } catch {
            failed = true
            message = error.localizedDescription
        }
    }
}
