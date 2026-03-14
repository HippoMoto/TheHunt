import Foundation

enum TeamAvatar: Equatable, Sendable {
    case emoji(String)
    case none

    var displayEmoji: String {
        if case .emoji(let e) = self { return e }
        return "🏃"
    }

    /// Convert to Firebase-storable dictionary
    nonisolated func toDict() -> [String: String] {
        switch self {
        case .emoji(let value):
            return ["type": "emoji", "value": value]
        case .none:
            return ["type": "emoji", "value": "🏃"]
        }
    }

    /// Create from Firebase dictionary
    nonisolated static func fromDict(_ dict: [String: String]) -> TeamAvatar {
        guard let type = dict["type"], let value = dict["value"] else {
            return .none
        }
        if type == "emoji" {
            return .emoji(value)
        }
        return .none
    }
}
