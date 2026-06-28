import SwiftUI

struct SearchInteractionView: View {
    @ObservedObject var viewModel: LocationSearchViewModel
    let onSelect: (SearchSuggestion) -> Void

    var body: some View {
        VStack(spacing: 12) {
            LocationSearchBar(
                text: Binding(
                    get: { viewModel.query },
                    set: { newValue in
                        viewModel.updateQuery(newValue)
                    }
                ),
                onClear: {
                    viewModel.clear()
                }
            )

            if viewModel.isSuggestionsVisible {
                LocationSearchSuggestionsView(
                    isLoading: viewModel.isLoading,
                    suggestions: viewModel.suggestions,
                    errorMessage: viewModel.errorMessage,
                    onSelect: { suggestion in
                        onSelect(suggestion)
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSuggestionsVisible)
    }
}
