import CoreLocation
import Foundation

@MainActor
final class LocationSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var suggestions: [SearchSuggestion] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSuggestionsVisible: Bool = true

    private let service: LocationSearchServicing
    private var searchTask: Task<Void, Never>?
    private var pendingTarget: CLLocationCoordinate2D?

    init(service: LocationSearchServicing = NominatimSearchService()) {
        self.service = service
    }

    func updateQuery(_ newValue: String) {
        query = newValue
        errorMessage = nil
        searchTask?.cancel()
        pendingTarget = nil
        isSuggestionsVisible = true

        let trimmedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 3 else {
            suggestions = []
            isLoading = false
            isSuggestionsVisible = false
            return
        }

        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { return }
                self.isLoading = true
                let results = try await service.search(query: trimmedQuery)
                if Task.isCancelled { return }
                self.suggestions = results
                self.isLoading = false
            } catch is CancellationError {
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = "Unable to load locations right now."
                self.suggestions = []
            }
        }
    }

    func clear() {
        query = ""
        suggestions = []
        errorMessage = nil
        isLoading = false
        searchTask?.cancel()
        pendingTarget = nil
        isSuggestionsVisible = false
    }

    func select(_ suggestion: SearchSuggestion) {
        query = suggestion.displayName
        searchTask?.cancel()
        isSuggestionsVisible = false
    }

    func hideSuggestions() {
        isSuggestionsVisible = false
    }

    func showSuggestions() {
        isSuggestionsVisible = true
    }

    func setSearchTarget(_ coordinate: CLLocationCoordinate2D) {
        pendingTarget = coordinate
        isSuggestionsVisible = false
    }

    func mapDidMove(to center: CLLocationCoordinate2D) {
        guard let target = pendingTarget else { return }
        let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
            .distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
        if distance < 100 {
            pendingTarget = nil
            isSuggestionsVisible = true
        }
    }

    func mapDidInteract() {
        pendingTarget = nil
        isSuggestionsVisible = false
    }
}
