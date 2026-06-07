import SwiftUI

enum AppAccentColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case green
    case purple
    case blue
    case yellow
    case red

    var id: String {
        rawValue
    }

    var name: String {
        switch self {
        case .green:
            "Green"
        case .purple:
            "Purple"
        case .blue:
            "Blue"
        case .yellow:
            "Yellow"
        case .red:
            "Red"
        }
    }

    var color: Color {
        switch self {
        case .green:
            .green
        case .purple:
            .purple
        case .blue:
            .blue
        case .yellow:
            .yellow
        case .red:
            .red
        }
    }

    static func normalized(_ rawValue: String?) -> AppAccentColor {
        guard let rawValue,
              let color = AppAccentColor(rawValue: rawValue)
        else {
            return .green
        }

        return color
    }
}
