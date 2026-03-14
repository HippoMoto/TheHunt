import Foundation

struct FirebaseTeam: Equatable, Sendable, Identifiable {
    let id: String
    var name: String
    var joinCode: String
    var creatorUid: String
    var members: [String]
    var status: String
    var createdAt: Date

    func toDict() -> [String: Any] {
        [
            "name": name,
            "joinCode": joinCode,
            "creatorUid": creatorUid,
            "members": members,
            "status": status,
            "createdAt": createdAt.timeIntervalSince1970
        ]
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

        return FirebaseTeam(
            id: id,
            name: name,
            joinCode: joinCode,
            creatorUid: creatorUid,
            members: members,
            status: status,
            createdAt: createdAt
        )
    }
}
