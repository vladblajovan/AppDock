import SwiftUI

enum AppCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case developerTools = "Developer Tools"
    case productivity = "Productivity"
    case creativityDesign = "Creativity & Design"
    case browsersInternet = "Internet"
    case communication = "Communication"
    case mediaEntertainment = "Entertainment"
    case utilities = "Utilities"
    case system = "System"
    case games = "Games"
    case education = "Education"
    case finance = "Finance"
    case healthFitness = "Health & Fitness"
    case other = "Other"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .developerTools: "hammer.fill"
        case .productivity: "doc.text.fill"
        case .creativityDesign: "paintbrush.fill"
        case .browsersInternet: "globe"
        case .communication: "message.fill"
        case .mediaEntertainment: "play.circle.fill"
        case .utilities: "wrench.and.screwdriver.fill"
        case .system: "gearshape.fill"
        case .games: "gamecontroller.fill"
        case .education: "graduationcap.fill"
        case .finance: "dollarsign.circle.fill"
        case .healthFitness: "heart.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .developerTools: .blue
        case .productivity: .orange
        case .creativityDesign: .purple
        case .browsersInternet: .cyan
        case .communication: .green
        case .mediaEntertainment: .red
        case .utilities: .gray
        case .system: .secondary
        case .games: .pink
        case .education: .yellow
        case .finance: .mint
        case .healthFitness: .red
        case .other: .secondary
        }
    }

    /// Parse from LLM response string (fuzzy match against rawValue)
    init?(fromLLMResponse response: String) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let exact = AppCategory.allCases.first(where: { $0.rawValue.lowercased() == trimmed }) {
            self = exact
            return
        }
        // Partial match
        if let partial = AppCategory.allCases.first(where: { trimmed.contains($0.rawValue.lowercased()) }) {
            self = partial
            return
        }
        return nil
    }

    /// Map from Apple's LSApplicationCategoryType string
    init?(fromAppStoreCategory category: String) {
        let mapping: [String: AppCategory] = [
            "public.app-category.developer-tools": .developerTools,
            "public.app-category.productivity": .productivity,
            "public.app-category.graphics-design": .creativityDesign,
            "public.app-category.photography": .creativityDesign,
            "public.app-category.video": .creativityDesign,
            "public.app-category.music": .mediaEntertainment,
            "public.app-category.entertainment": .mediaEntertainment,
            "public.app-category.games": .games,
            "public.app-category.action-games": .games,
            "public.app-category.adventure-games": .games,
            "public.app-category.arcade-games": .games,
            "public.app-category.board-games": .games,
            "public.app-category.card-games": .games,
            "public.app-category.casino-games": .games,
            "public.app-category.puzzle-games": .games,
            "public.app-category.racing-games": .games,
            "public.app-category.role-playing-games": .games,
            "public.app-category.simulation-games": .games,
            "public.app-category.sports-games": .games,
            "public.app-category.strategy-games": .games,
            "public.app-category.trivia-games": .games,
            "public.app-category.word-games": .games,
            "public.app-category.education": .education,
            "public.app-category.finance": .finance,
            "public.app-category.business": .productivity,
            "public.app-category.healthcare-fitness": .healthFitness,
            "public.app-category.medical": .healthFitness,
            "public.app-category.lifestyle": .other,
            "public.app-category.books": .education,
            "public.app-category.reference": .education,
            "public.app-category.navigation": .utilities,
            "public.app-category.news": .browsersInternet,
            "public.app-category.social-networking": .communication,
            "public.app-category.travel": .other,
            "public.app-category.utilities": .utilities,
            "public.app-category.weather": .utilities,
        ]
        if let mapped = mapping[category.lowercased()] {
            self = mapped
        } else {
            return nil
        }
    }
}
