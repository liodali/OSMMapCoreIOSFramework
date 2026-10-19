## Unreleased

- Add native macOS 12 support to OSMView and its public managers with AppKit image/color aliases; preserve UIKit on iOS and Catalyst.
- Share image and font-atlas decoding through CoreGraphics, CoreText, and ImageIO, with resources loaded from the framework bundle. Normalize AppKit symbol images to RGBA8 for Metal upload.
- Cancel stale vector-style downloads and keep the working map when a replacement download or layer creation fails.
- Adapt location authorization and guard unsupported heading APIs on macOS; clean up location updates on the main actor.
- Fix embedded-map layout to use bounds and avoid retaining the wrapper through camera listeners.
- Make the native example consume OSMFlutterFramework directly and exercise overlays, input, rotation, location, and recreation. Fix its raster template to avoid duplicate PNG extensions.
- Synchronize standalone Xcode framework source references with the package, including font providers and OSMViewProtocols.swift.
- Add focused platform tests and compile CI for macOS, iOS Simulator, and Catalyst. Require Swift 6.2 for actor-isolated cleanup.

## 0.9.0

- Release through Swift Package Manager; suspend the legacy CocoaPods build and publishing workflows.
- Use the MapCore 4.0.0-based fork with stable remote djinni resolution and the macOS indexed-PNG decoding fix.
- Support vector styles with bundled font atlases and runtime raster/vector switching.
- Add a native AppKit example for testing MapCore on macOS. The framework wrapper remains UIKit-based.

## 0.8.7: Fix Bugs
## 0.8.6: Fix Bugs
## 0.0.4: Fix Bugs
## 0.0.3: Add new APIs
## 0.0.2: Improve APIs
## 0.0.1: 
    * OSMView as UIViewController to be wrapper for MCMapView
    * add APIs to move map,set BoundingBox
    * create BoundingBox,CustomTiles class
