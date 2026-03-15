import Foundation

enum ManagementMode: String, Equatable, Sendable {
    case managerOnly = "manager_only"
    case allMembers = "all_members"
}

struct FirebaseTeam: Equatable, Sendable, Identifiable {
    static let maxMembers = 6

    let id: String
    var name: String
    var joinCode: String
    var creatorUid: String
    var members: [String]
    var status: String
    var createdAt: Date
    var avatar: TeamAvatar
    var managementMode: ManagementMode
    var lockedAt: Date?

    var isLocked: Bool { status == "locked" }
    var isFull: Bool { members.count >= FirebaseTeam.maxMembers }

    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "joinCode": joinCode,
            "creatorUid": creatorUid,
            "members": members,
            "status": status,
            "createdAt": createdAt.timeIntervalSince1970,
            "avatar": avatar.toDict(),
            "managementMode": managementMode.rawValue
        ]
        if let lockedAt {
            dict["lockedAt"] = lockedAt.timeIntervalSince1970
        }
        return dict
    }

    static func fromDict(id: String, _ dict: [String: Any]) -> FirebaseTeam? {
        guard
            let name = dict["name"] as? String,
            let joinCode = dict["joinCode"] as? String,
            let creatorUid = dict["creatorUid"] as? String,
            let status = dict["status"] as? String
        else { return nil }

        let members: [String]
        if let arr = dict["members"] as? [String] {
            members = arr
        } else if let map = dict["members"] as? [String: Any] {
            // RTDB may store arrays as dictionaries with numeric keys
            members = map.sorted { Int($0.key) ?? 0 < Int($1.key) ?? 0 }.compactMap { $0.value as? String }
        } else {
            members = []
        }

        let createdAt: Date
        if let timestamp = dict["createdAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            createdAt = Date()
        }

        let avatar: TeamAvatar
        if let avatarDict = dict["avatar"] as? [String: String] {
            avatar = TeamAvatar.fromDict(avatarDict)
        } else {
            avatar = .none
        }

        let managementMode: ManagementMode
        if let modeRaw = dict["managementMode"] as? String,
           let mode = ManagementMode(rawValue: modeRaw) {
            managementMode = mode
        } else {
            managementMode = .managerOnly
        }

        let lockedAt: Date?
        if let lockedTimestamp = dict["lockedAt"] as? TimeInterval {
            lockedAt = Date(timeIntervalSince1970: lockedTimestamp)
        } else {
            lockedAt = nil
        }

        return FirebaseTeam(
            id: id,
            name: name,
            joinCode: joinCode,
            creatorUid: creatorUid,
            members: members,
            status: status,
            createdAt: createdAt,
            avatar: avatar,
            managementMode: managementMode,
            lockedAt: lockedAt
        )
    }
}
