import Foundation

struct UserProfile: Equatable, Sendable, Identifiable {
    let uid: String
    var displayName: String
    var teamId: String?
    var createdAt: Date

    var id: String { uid }

    nonisolated func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "displayName": displayName,
            "createdAt": createdAt.timeIntervalSince1970
        ]
        if let teamId {
            dict["teamId"] = teamId
        }
        return dict
    }

    nonisolated static func fromDict(uid: String, _ dict: [String: Any]) -> UserProfile? {
        guard let displayName = dict["displayName"] as? String else { return nil }
        let createdAt: Date
        if let timestamp = dict["createdAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            createdAt = Date()
        }
        return UserProfile(
            uid: uid,
            displayName: displayName,
            teamId: dict["teamId"] as? String,
            createdAt: createdAt
        )
    }
}
