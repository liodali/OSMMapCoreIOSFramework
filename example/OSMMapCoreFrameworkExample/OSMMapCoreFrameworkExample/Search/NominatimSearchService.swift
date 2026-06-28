import Foundation

protocol LocationSearchServicing {
    func search(query: String) async throws -> [SearchSuggestion]
}

final class NominatimSearchService: LocationSearchServicing {
    private let session: URLSession
    private let baseURL = URL(string: "https://nominatim.openstreetmap.org/search")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async throws -> [SearchSuggestion] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "addressdetails", value: "1"),
            URLQueryItem(name: "limit", value: "8")
        ]

        guard let url = components?.url else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OSMMapCoreFrameworkExample/1.0 (SwiftUI demo)", forHTTPHeaderField: "User-Agent")
        request.setValue(Locale.current.identifier, forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            return []
        }

        return try JSONDecoder().decode([SearchSuggestion].self, from: data)
    }
}
