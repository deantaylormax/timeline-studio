import Foundation

/// Free is the GitHub build. The two paid plans unlock the same AI tools.
enum SubscriptionTier: String, Codable, Equatable {
    case free
    case pro
    case privateAI

    var title: String {
        switch self {
        case .free: "Free"
        case .pro: "Pro"
        case .privateAI: "Private AI"
        }
    }

    var price: String {
        switch self {
        case .free: "$0"
        case .pro: "$20 a month"
        case .privateAI: "$79 a month"
        }
    }

    var yearlyPrice: String {
        switch self {
        case .free: ""
        case .pro: "about $199 a year"
        case .privateAI: "about $790 a year"
        }
    }
}

/// The AI list from AI_FEATURES.md. Pro and Private AI include the whole list.
struct ProFeature: Identifiable {
    let title: String
    var inThisVersion = false
    var id: String { title }
}

struct ProFeatureGroup: Identifiable {
    let title: String
    var note = ""
    let features: [ProFeature]
    var id: String { title }
}

enum ProFeatureList {
    static let groups: [ProFeatureGroup] = [
        ProFeatureGroup(title: "Building timelines", features: [
            ProFeature(title: "Extract dated events from documents (police reports, depositions, emails, medical records, PDFs), with page citations", inThisVersion: true),
            ProFeature(title: "OCR for scanned documents and handwriting"),
            ProFeature(title: "Turn an email or text thread into a communication timeline"),
            ProFeature(title: "Transcribe audio and video (bodycam, depositions) into timestamped events"),
            ProFeature(title: "Research to import. Ask for a data set, save it as a CSV in the import format, and load it into the timeline"),
        ]),
        ProFeatureGroup(title: "Editing with plain language", note: "Spoken or typed.", features: [
            ProFeature(title: "Add, move, merge, split, recolor, and relabel events, and create tracks", inThisVersion: true),
            ProFeature(title: "Bulk edits, such as shifting every event from one exhibit by an hour", inThisVersion: true),
            ProFeature(title: "Preview each change before applying it, with full undo", inThisVersion: true),
        ]),
        ProFeatureGroup(title: "Analysis", features: [
            ProFeature(title: "Contradiction detection", inThisVersion: true),
            ProFeature(title: "Gaps, overlaps, and impossible sequences", inThisVersion: true),
            ProFeature(title: "Map events to legal elements, statute-of-limitations clocks, and deadlines"),
            ProFeature(title: "Patterns across many cases"),
        ]),
        ProFeatureGroup(title: "Questions and answers", features: [
            ProFeature(title: "Ask what happened between two events, answered with linked sources"),
            ProFeature(title: "Ask to see everything one person did, and filter the timeline"),
            ProFeature(title: "Every answer cites the source document and page"),
        ]),
        ProFeatureGroup(title: "Output", features: [
            ProFeature(title: "Narrative summaries, such as a statement of facts, chronology memo, or brief section, with citations", inThisVersion: true),
            ProFeature(title: "Trial exhibits and demonstratives"),
            ProFeature(title: "Deposition outlines built from gaps and contradictions"),
            ProFeature(title: "Export to Word, PDF, and PowerPoint"),
        ]),
        ProFeatureGroup(title: "Data cleanup", features: [
            ProFeature(title: "Standardize dates and time zones, and remove duplicate events"),
            ProFeature(title: "Flag uncertain dates"),
            ProFeature(title: "Extract people, places, and vehicles into linked profiles"),
        ]),
        ProFeatureGroup(title: "Trust and compliance", features: [
            ProFeature(title: "Every AI change logged and reversible, with a citation trail"),
            ProFeature(title: "Local-only mode for sensitive matters"),
            ProFeature(title: "Data-handling policy, no-retention commitment, and a DPA for Private AI"),
        ]),
        ProFeatureGroup(
            title: "Trial Mode",
            note: "The same chronology used through the case, with a contradiction view for closing argument.",
            features: [
                ProFeature(title: "Split-screen comparison of testimony and the contradicting evidence, anchored to the same moment"),
                ProFeature(title: "Contradiction markers between a statement and the evidence, with a click to full screen"),
                ProFeature(title: "Build-up animation that plays the chronology, then reveals contradictions one at a time"),
                ProFeature(title: "Layers by witness or theme"),
                ProFeature(title: "Courtroom presenter: full screen, clicker control, an exhibit-only view, and a view with argument"),
                ProFeature(title: "AI help that flags contradictions and drafts a cited closing point for each"),
                ProFeature(title: "Neutral evidence layer: admitted exhibits and testimony, quoted exactly"),
                ProFeature(title: "Argument layer: contradiction labels and the presenting side’s interpretation, used in closing"),
                ProFeature(title: "Every element links to an exhibit number or transcript cite, and the slides can be exported for the record"),
            ]),
    ]
}

/// Where a Pro subscriber's own model lives. Private AI does not use this.
enum ModelProvider: String, CaseIterable, Identifiable {
    case openAI
    case anthropic
    case xAI
    case local
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .xAI: "xAI"
        case .local: "Local model"
        case .custom: "Other OpenAI-compatible"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-4o-mini"
        case .anthropic: "claude-sonnet-4-5"
        case .xAI: "grok-4.5"
        case .local: "llama3.2"
        case .custom: ""
        }
    }

    /// Empty when the subscriber types the address (local or custom).
    var fixedBaseURL: String {
        switch self {
        case .openAI: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com/v1"
        case .xAI: "https://api.x.ai/v1"
        case .local, .custom: ""
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .local: "http://127.0.0.1:11434/v1"
        case .custom: ""
        default: fixedBaseURL
        }
    }

    var requiresKey: Bool {
        switch self {
        case .local, .custom: false
        default: true
        }
    }

    var usesAnthropic: Bool { self == .anthropic }

    var baseURLIsEditable: Bool {
        switch self {
        case .local, .custom: true
        default: false
        }
    }
}

/// Hosted model for the $79 plan. The address stays empty until the proxy is deployed.
enum PrivateAIService {
    static let baseURL = ""
    static let model = "timeline"
}

enum AITool: String, CaseIterable, Identifiable {
    case edit
    case extract
    case review
    case narrative

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edit: "Edit"
        case .extract: "Extract"
        case .review: "Review"
        case .narrative: "Memo"
        }
    }

    var headline: String {
        switch self {
        case .edit: "Edit in plain language"
        case .extract: "Extract events from a document"
        case .review: "Contradictions and gaps"
        case .narrative: "Chronology memo"
        }
    }
}
