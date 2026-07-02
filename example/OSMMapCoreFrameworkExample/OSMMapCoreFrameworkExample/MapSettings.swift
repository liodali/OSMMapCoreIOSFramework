import CoreLocation
import Foundation
import OSMFlutterFramework
import SwiftUI

enum TileType: String, CaseIterable {
    case vector
    case raster

    var label: String {
        switch self {
        case .vector: return "Vector"
        case .raster: return "Raster"
        }
    }
}

enum RasterSource: String, CaseIterable {
    case osmStandard
    case cartodbPositron
    case esriSatellite
    case custom

    var label: String {
        switch self {
        case .osmStandard: return "OSM Standard"
        case .cartodbPositron: return "CartoDB Light"
        case .esriSatellite: return "Esri Satellite"
        case .custom: return "Custom URL"
        }
    }
}

enum StartupLocationMode: String, CaseIterable {
    case fixedLocation
    case userLocation

    var label: String {
        switch self {
        case .fixedLocation: return "Fixed Location"
        case .userLocation: return "User Location"
        }
    }
}

@MainActor
final class MapSettings: ObservableObject {
    nonisolated static let defaultVectorStyleURL = "https://tiles.openfreemap.org/styles/liberty"

    @Published var tileType: TileType
    @Published var vectorStyleURL: String
    @Published var rasterSource: RasterSource
    @Published var customRasterURL: String
    @Published var startupMode: StartupLocationMode
    @Published var fixedLocation: CLLocationCoordinate2D

    init(
        tileType: TileType = .vector,
        vectorStyleURL: String = MapSettings.defaultVectorStyleURL,
        rasterSource: RasterSource = .osmStandard,
        customRasterURL: String = "",
        startupMode: StartupLocationMode = .fixedLocation,
        fixedLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(
            latitude: 47.4358055, longitude: 8.4737324)
    ) {
        self.tileType = tileType
        self.vectorStyleURL = vectorStyleURL
        self.rasterSource = rasterSource
        self.customRasterURL = customRasterURL
        self.startupMode = startupMode
        self.fixedLocation = fixedLocation
    }

    var isVector: Bool { tileType == .vector }

    var isValidVectorURL: Bool {
        let trimmed = vectorStyleURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let url = URL(string: trimmed),
            url.scheme == "http" || url.scheme == "https"
        else {
            return false
        }
        return true
    }

    var effectiveVectorStyleURL: String {
        isValidVectorURL ? vectorStyleURL : MapSettings.defaultVectorStyleURL
    }

    func resetVectorURL() {
        vectorStyleURL = MapSettings.defaultVectorStyleURL
    }

    var isValidRasterURL: Bool {
        guard rasterSource == .custom else { return true }
        let trimmed = customRasterURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let url = URL(string: trimmed),
            url.scheme == "http" || url.scheme == "https"
        else {
            return false
        }
        return true
    }

    func makeCustomTiles() -> CustomTiles {
        if isVector {
            return CustomTiles([
                "styleURL": effectiveVectorStyleURL,
                "isVector": true,
                "tileSize": 256,
                "maxZoomLevel": "19",
            ])
        } else {
            return makeRasterCustomTiles()
        }
    }

    private func makeRasterCustomTiles() -> CustomTiles {
        switch rasterSource {
        case .osmStandard:
            return CustomTiles([
                "urls": [
                    [
                        "url": "https://{s}.tile.openstreetmap.org/",
                        "subdomains": ["a", "b", "c"],
                    ]
                ],
                "tileExtension": ".png",
                "tileSize": 256,
                "maxZoomLevel": "19",
            ])
        case .cartodbPositron:
            return CustomTiles([
                "urls": [
                    [
                        "url": "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}",
                        "subdomains": ["a", "b", "c"],
                    ]
                ],
                "tileExtension": ".png",
                "tileSize": 256,
                "maxZoomLevel": "19",
            ])
        case .esriSatellite:
            return CustomTiles([
                "urls": [
                    [
                        "url":
                            "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
                    ]
                ],
                "tileExtension": "",
                "tileSize": 256,
                "maxZoomLevel": "19",
            ])
        case .custom:
            var baseURL = customRasterURL.trimmingCharacters(in: .whitespacesAndNewlines)
            var ext = ".png"
            for knownExt in [".png", ".jpg", ".jpeg", ".webp"] {
                if baseURL.hasSuffix(knownExt) {
                    ext = knownExt == ".jpeg" ? ".jpg" : knownExt
                    baseURL = String(baseURL.dropLast(knownExt.count))
                    break
                }
            }
            var urlEntry: [String: Any] = ["url": baseURL]
            if baseURL.contains("{s}") {
                urlEntry["subdomains"] = ["a", "b", "c"]
            }
            return CustomTiles([
                "urls": [urlEntry],
                "tileExtension": ext,
                "tileSize": 256,
                "maxZoomLevel": "19",
            ])
        }
    }
}
