# Native macOS example

Open `OSMFlutterFramework.xcworkspace`, select **MapCoreMacOSExample** and **My Mac**, then run. The example uses local ad-hoc signing, so no development team is required.

The shared scheme runs the optimized **Release** configuration to exercise vector rendering. For source debugging, change **Edit Scheme → Run → Build Configuration** to **Debug**; this also disables optimization in MapCore's C++ engine and affects rendering performance.

For a repeatable rendering check, add `--map-performance-check` under the scheme's launch arguments. It runs four zoom steps and logs frame durations, including the number exceeding 50 ms. Remove the argument for normal interaction.

This example uses SwiftUI's `NSViewRepresentable` to embed MapCore's AppKit-based `MCMapView` directly. It uses the remote `liodali/maps-core` fork at `4.0.1-spm.2`, which includes the macOS indexed-PNG decoding fix.

The buttons above the map switch between:

- **Vector** (default): the same OpenFreeMap Liberty style as the iOS example, using the existing bundled Noto Sans MSDF font atlases.
- **Raster**: OpenStreetMap standard raster tiles.

Drag to pan, scroll or pinch to zoom, and use the toolbar to zoom or return to Zurich. The bottom bar displays the live camera center and scale. Tile failures appear in the map and are logged with their underlying error codes.

The font JSON and PNG files are shared Xcode resource references to `Sources/OSMFlutterFramework/Resources`; the native example does not import the UIKit-based framework or duplicate its atlas assets.

Location tracking, the iOS wrapper's marker/road APIs, and Intel/AMD GPUs need separate validation.
