import CoreLocation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: MapSettings
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            Form {
                Section("Tile Type") {
                    Picker("Type", selection: $settings.tileType) {
                        ForEach(TileType.allCases, id: \.self) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if settings.tileType == .vector {
                    Section {
                        TextField("Vector Style URL", text: $settings.vectorStyleURL)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundColor(settings.isValidVectorURL ? .primary : .red)

                        if !settings.isValidVectorURL {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(
                                    "Invalid URL — the default style will be used until a valid http(s) URL is entered."
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Vector Tile URL")
                    } footer: {
                        Text(
                            "Enter a style JSON URL. URLs with API keys are supported (e.g. …?key=YOUR_KEY)."
                        )
                    }

                    Section {
                        Button {
                            settings.resetVectorURL()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset to Default (OpenFreeMap)")
                            }
                        }
                    }
                }

                if settings.tileType == .raster {
                    Section {
                        Picker("Source", selection: $settings.rasterSource) {
                            ForEach(RasterSource.allCases, id: \.self) { source in
                                Text(source.label).tag(source)
                            }
                        }

                        if settings.rasterSource == .custom {
                            TextField(
                                "https://tile.example.com/{z}/{x}/{y}.png",
                                text: $settings.customRasterURL
                            )
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundColor(settings.isValidRasterURL ? .primary : .red)

                            if !settings.isValidRasterURL {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Enter a valid http(s) tile URL.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Raster Tile Source")
                    } footer: {
                        Text(
                            settings.rasterSource == .custom
                                ? "Enter a tile URL template. Use {z}/{x}/{y} for tile coordinates and {s} for subdomains (auto a/b/c). Extension auto-detected or defaults to .png."
                                : "Choose a preset raster tile provider."
                        )
                    }
                }

                Section("Startup Location") {
                    Picker("Mode", selection: $settings.startupMode) {
                        ForEach(StartupLocationMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if settings.startupMode == .fixedLocation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Default Location")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(
                                String(
                                    format: "Lat: %.6f, Lon: %.6f",
                                    settings.fixedLocation.latitude,
                                    settings.fixedLocation.longitude)
                            )
                            .font(.callout)
                            Text("Use the map to pick a location, or keep the current default.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Map Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
