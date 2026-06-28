import SwiftUI

struct LocationSearchBar: View {
    @Binding var text: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search", text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
}

struct LocationSearchSuggestionsView: View {
    let isLoading: Bool
    let suggestions: [SearchSuggestion]
    let errorMessage: String?
    let onSelect: (SearchSuggestion) -> Void

    var body: some View {
        if isLoading || !suggestions.isEmpty || errorMessage != nil {
            VStack(alignment: .leading, spacing: 10) {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Searching locations...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }

                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.displayName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)

                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            )
        }
    }
}
