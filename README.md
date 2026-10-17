# OSM MapCore iOS Framework

[![Platform](https://img.shields.io/badge/platform-iOS%2014%2B-lightgrey)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://swift.org)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An iOS framework that wraps the [MapCore](https://github.com/openmobilemaps/maps-core)
SDK to render OpenStreetMap maps with a simple, Swift-friendly API — raster or
vector tiles, markers, roads, shapes, POIs and user-location tracking.

 * current version : `0.9.0`

> [!WARNING]
> **CocoaPods support is suspended.** No further pod releases will be
> published and the podspec is frozen. New versions ship via
> **Swift Package Manager only**.

## Features

- **Raster & vector tiles** — OSM raster tiles out of the box, or any
  MapCore vector style via a style JSON URL; switch at runtime
- **Markers** — add, update, remove, cluster-ready icon layers with custom
  icons, anchors and scaling
- **Roads** — polylines with border styling, dotted lines, encoded polyline
  strings, tap handling per road
- **Shapes** — rectangles and circles with configurable borders
- **POIs** — grouped icon layers per POI
- **User location** — tracking mode that follows the user, direction marker
  rotation, custom user/location icons
- **Camera control** — zoom, rotation, move-to, bounding-box framing,
  min/max zoom clamping
- **Gesture delegates** — taps, long taps, rotation and move callbacks

## Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 16+

## Installation (Swift Package Manager)

 * In `Package.swift`
 ```swift
 .package(url: "https://github.com/liodali/OSMMapCoreIOSFramework.git", from: "0.9.0")
 ```
 * Or in Xcode: *File → Add Package Dependencies…* → paste the repo URL.

MapCore and all its dependencies resolve automatically — no extra setup needed.

## Quick Start

### UIKit

```swift
import OSMFlutterFramework

let zoomConfig = ZoomConfiguration(initZoom: 16, minZoom: 1, maxZoom: 19)

// Raster OSM tiles (default). For vector tiles pass a CustomTiles with
// ["isVector": true, "styleURL": "<your style json url>"].
let map = OSMView(
    rect: view.bounds,
    location: CLLocationCoordinate2D(latitude: 47.4358, longitude: 8.4737),
    zoomConfig: zoomConfig
)

view.addSubview(map)

// Camera
map.moveTo(location: target, zoom: 14, animated: true)
map.zoomIn()

// Content
map.markerManager.addMarker(marker: /* … */)
map.roadManager.addRoad(/* … */)
map.shapeManager.drawShape(key: "area", shape: myShape)

// Follow the user
map.locationManager.toggleTracking(configuration: trackConfig)
```

### SwiftUI (bridge)

```swift
import OSMFlutterFramework
import SwiftUI

struct MapView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        let map = OSMView(
            rect: controller.view.bounds,
            location: CLLocationCoordinate2D(latitude: 47.4358, longitude: 8.4737),
            zoomConfig: ZoomConfiguration(initZoom: 16, minZoom: 1, maxZoom: 19)
        )
        controller.view.addSubview(map)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
```

## API Overview

**Camera & view**

| API | Purpose |
| --- | --- |
| `moveTo(location:zoom:animated:)` | Center the map |
| `moveToByBoundingBox(bounds:animated:)` | Frame a region |
| `setZoom(_:animated:)`, `zoomIn()`, `zoomOut()` | Zoom control (clamped to `ZoomConfiguration`) |
| `getBoundingBox()`, `center()`, `zoom()` | Current state |
| `enableRotation(_:)`, `setRotation(angle:animated:)` | Rotation control |
| `setCustomTile(tile:)` | Swap raster/vector base layer at runtime |
| `stopCamera()` | Cancel in-flight camera animation |
| `hideAllLayers()` / `showAllLayers()` | Layer visibility |

**Managers** — `markerManager`, `roadManager`, `poisManager`, `shapeManager`,
`locationManager`: each exposes add/remove/update calls plus `hideAll()` /
`showAll()`.

**Delegates** — `onMapGestureDelegate` (taps), `onMapMove` (move/zoom/rotation),
`mapHandlerDelegate` (marker taps), `roadTapHandlerDelegate` (road taps),
`userLocationDelegate` (location updates).

## Examples

- `example/OSMMapCoreFrameworkExample/` — full iOS app: search (Nominatim),
  routing (OSRM), markers, road tap handling, settings with tile-source
  switching, location tracking.
- `example/MapCoreMacOSExample/` — native macOS smoke test with
  vector/raster selection.

## About the MapCore dependency

The package currently resolves MapCore 4.0.0 through the
[`liodali/maps-core`](https://github.com/liodali/maps-core) fork (tag
`4.0.1-spm.2`) because the upstream tag is unresolvable via SwiftPM on
Xcode 16.4+/26.x ([openmobilemaps/maps-core#929](https://github.com/openmobilemaps/maps-core/issues/929)).
The fork only changes dependency resolution; it will be dropped in favor of
the official package once upstream ships a fixed release.

## CocoaPods (suspended)

The last pod release remains available for existing projects, but it will
not receive updates:

```ruby
pod "OSMFlutterFramework"
```

Migrate to SPM to keep receiving new versions.

## License

MIT — see [LICENSE](LICENSE).
