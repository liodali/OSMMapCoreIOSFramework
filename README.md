# OSM MapCore iOS Framework

[![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20macOS%2012%2B-lightgrey)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.2%2B-orange)](https://swift.org)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An Apple-platform framework that wraps the [MapCore](https://github.com/openmobilemaps/maps-core)
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
- macOS 12.0+ for native AppKit builds; Mac Catalyst 14.0+ remains supported
- Swift 6.2+ / Xcode 26 or newer (CI uses Xcode 26.3)

## Installation (Swift Package Manager)

 * In `Package.swift`
 ```swift
 .package(url: "https://github.com/liodali/OSMMapCoreIOSFramework.git", from: "0.9.0")
 ```
 * Or in Xcode: *File → Add Package Dependencies…* → paste the repo URL.

MapCore and all its dependencies resolve automatically — no extra setup needed.

## Native macOS (working tree / next release)

The macOS port is not included in the published `0.9.0` tag yet. Use this local
package while testing; keep released applications on their verified version.

`OSMView` is an `NSView` on native macOS and a `UIView` on iOS/Catalyst. Public
`OSMPlatformImage` and `OSMPlatformColor` aliases resolve to `NSImage`/`NSColor`
on macOS and `UIImage`/`UIColor` on iOS, preserving existing iOS call sites.
The public managers and camera commands are shared.

```swift
import AppKit
import CoreLocation
import OSMFlutterFramework

let map = OSMView(
    rect: view.bounds,
    location: CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
    zoomConfig: ZoomConfiguration(initZoom: 14)
)
map.autoresizingMask = [.width, .height]
view.addSubview(map)
```

Open `OSMFlutterFramework.xcworkspace`, select **MapCoreMacOSExample → My Mac**,
and run to exercise the wrapper with vector/raster tiles, bundled labels,
markers, POIs, roads, circles, rotation, static mode, and view recreation.
The shared scheme uses Release for smooth vector rendering; Debug also builds.

Sandboxed hosts need `com.apple.security.network.client` for remote maps.
Location is opt-in: a macOS host needs `NSLocationUsageDescription` and, when
sandboxed, `com.apple.security.personal-information.location`. iOS hosts retain
`NSLocationWhenInUseUsageDescription`. Configure these in the host application,
not in package resources. macOS reports heading as zero and uses a fixed marker;
location denial does not prevent the rest of the map from working.

Mouse clicks, dragging, wheel/pinch zoom use MapCore's AppKit support. Programmatic
rotation is shared; native rotation gestures, hover, and long-press behavior
are not provided by the pinned MapCore AppKit adapter. Intel/AMD runtime graphics
and moving between Retina/non-Retina displays still require device validation.
The separate Flutter plugin has not been ported by this change.

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
