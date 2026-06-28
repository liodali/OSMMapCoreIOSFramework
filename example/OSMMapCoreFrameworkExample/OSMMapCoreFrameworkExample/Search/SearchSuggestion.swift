import CoreLocation
import Foundation

struct SearchSuggestion: Identifiable, Decodable, Equatable {
    let placeID: Int
    let displayName: String
    let latitude: Double
    let longitude: Double
    let category: String?
    let type: String?

    var id: Int { placeID }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var subtitle: String {
        [category, type]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    enum CodingKeys: String, CodingKey {
        case placeID = "place_id"
        case displayName = "display_name"
        case lat
        case lon
        case category
        case type
    }

    init(
        placeID: Int,
        displayName: String,
        latitude: Double,
        longitude: Double,
        category: String?,
        type: String?
    ) {
        self.placeID = placeID
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        placeID = try container.decode(Int.self, forKey: .placeID)
        displayName = try container.decode(String.self, forKey: .displayName)
        let latString = try container.decode(String.self, forKey: .lat)
        let lonString = try container.decode(String.self, forKey: .lon)
        latitude = Double(latString) ?? 0
        longitude = Double(lonString) ?? 0
        category = try container.decodeIfPresent(String.self, forKey: .category)
        type = try container.decodeIfPresent(String.self, forKey: .type)
    }
}
