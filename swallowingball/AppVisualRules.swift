import SwiftUI

enum ScoreVisuals {
    static func color(for score: Int) -> Color {
        switch score {
        case 80...:
            return .successGreen
        case 60..<80:
            return .brandBlue
        default:
            return .warningAmber
        }
    }

    static func background(for score: Int) -> Color {
        switch score {
        case 80...:
            return .successGreenBg
        case 60..<80:
            return .neutralBlueBg
        default:
            return .warningAmberBg
        }
    }
}

enum RatioVisuals {
    static func color(for ratio: Double) -> Color {
        switch ratio {
        case 0.8...:
            return .successGreen
        case 0.6..<0.8:
            return .brandBlue
        default:
            return .warningAmber
        }
    }

    static func background(for ratio: Double) -> Color {
        switch ratio {
        case 0.8...:
            return .successGreenBg
        case 0.6..<0.8:
            return .neutralBlueBg
        default:
            return .warningAmberBg
        }
    }
}

enum BadgeStyle {
    case positive
    case neutral
    case attention

    var textColor: Color {
        switch self {
        case .positive:
            return .successGreen
        case .neutral:
            return .brandBlue
        case .attention:
            return .warningAmber
        }
    }

    var backgroundColor: Color {
        switch self {
        case .positive:
            return .successGreenBg
        case .neutral:
            return .neutralBlueBg
        case .attention:
            return .warningAmberBg
        }
    }

    var borderColor: Color {
        switch self {
        case .positive:
            return .successGreen.opacity(0.22)
        case .neutral:
            return .brandBlue.opacity(0.18)
        case .attention:
            return .warningAmber.opacity(0.22)
        }
    }
}
