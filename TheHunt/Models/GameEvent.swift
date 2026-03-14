import Foundation

enum GameEventType: String {
    case clueUnlockedMedium = "clue_unlocked_medium"
    case clueUnlockedEasy = "clue_unlocked_easy"
    case arrivedAtLocation = "arrived_at_location"
    case evidenceSubmitted = "evidence_submitted"
    case huntCompleted = "hunt_completed"

    var icon: String {
        switch self {
        case .clueUnlockedMedium: "bolt.fill"
        case .clueUnlockedEasy: "leaf.fill"
        case .arrivedAtLocation: "mappin.circle.fill"
        case .evidenceSubmitted: "camera.fill"
        case .huntCompleted: "trophy.fill"
        }
    }

    func message(teamName: String, locationName: String?) -> String {
        switch self {
        case .clueUnlockedMedium:
            "\(teamName) unlocked a medium clue"
        case .clueUnlockedEasy:
            "\(teamName) unlocked an easy clue"
        case .arrivedAtLocation:
            if let loc = locationName {
                "\(teamName) arrived at \(loc)"
            } else {
                "\(teamName) found a location"
            }
        case .evidenceSubmitted:
            "\(teamName) submitted evidence"
        case .huntCompleted:
            "\(teamName) completed the hunt!"
        }
    }
}

struct GameEvent: Identifiable {
    let id: String
    let teamID: String
    let teamName: String
    let avatar: TeamAvatar
    let eventType: GameEventType
    let locationName: String?
    let timestamp: Date

    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "teamId": teamID,
            "teamName": teamName,
            "avatarType": avatar.toDict()["type"] ?? "emoji",
            "avatarValue": avatar.toDict()["value"] ?? "🏃",
            "eventType": eventType.rawValue,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        if let locationName {
            dict["locationName"] = locationName
        }
        return dict
    }

    static func fromDict(id: String, _ dict: [String: Any]) -> GameEvent? {
        guard
            let teamID = dict["teamId"] as? String,
            let teamName = dict["teamName"] as? String,
            let eventTypeRaw = dict["eventType"] as? String,
            let eventType = GameEventType(rawValue: eventTypeRaw),
            let timestamp = dict["timestamp"] as? Double
        else { return nil }

        let avatarType = dict["avatarType"] as? String ?? "emoji"
        let avatarValue = dict["avatarValue"] as? String ?? "🏃"
        let avatar = TeamAvatar.fromDict(["type": avatarType, "value": avatarValue])
        let locationName = dict["locationName"] as? String

        return GameEvent(
            id: id,
            teamID: teamID,
            teamName: teamName,
            avatar: avatar,
            eventType: eventType,
            locationName: locationName,
            timestamp: Date(timeIntervalSince1970: timestamp)
        )
    }
}
