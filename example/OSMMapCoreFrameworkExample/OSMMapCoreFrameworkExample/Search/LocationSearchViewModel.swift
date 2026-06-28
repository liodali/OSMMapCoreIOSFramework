import Foundation

@MainActor
final class LocationSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var suggestions: [SearchSuggestion] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    private let service: LocationSearchServicing
    private var searchTask: Task<Void, Never>?

    init(service: LocationSearchServicing = NominatimSearchService()) {
        self.service = service
    }

    func updateQuery(_ newValue: String) {
        query = newValue
        errorMessage = nil
        searchTask?.cancel()

        let trimmedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 3 else {
            suggestions = []
            isLoading = false
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
    }

    func select(_ suggestion: SearchSuggestion) {
        query = suggestion.displayName
        suggestions = []
        searchTask?.cancel()
    }
}
