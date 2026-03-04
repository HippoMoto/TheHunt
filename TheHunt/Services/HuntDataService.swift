import Foundation

enum HuntDataError: LocalizedError {
    case fileNotFound
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound: "Hunt data file not found in bundle."
        case .decodingFailed(let error): "Failed to decode hunt data: \(error.localizedDescription)"
        }
    }
}

struct HuntDataService {
    func loadHuntData() throws -> HuntData {
        guard let url = Bundle.main.url(forResource: "hunt_data", withExtension: "json") else {
            throw HuntDataError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HuntData.self, from: data)
    }
}
