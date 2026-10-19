# Native macOS wrapper example

Open `OSMFlutterFramework.xcworkspace`, select **MapCoreMacOSExample** and **My Mac**, then run. The example uses local ad-hoc signing, so no development team is required.

This app imports the local **OSMFlutterFramework** SPM product and embeds its `OSMView` through `NSViewRepresentable`. It does not import MapCore or supply its own font loader. Font atlases come from the framework's SPM resource bundle. The framework still pins the remote MapCore fork to `4.0.1-spm.2`.

The shared scheme runs optimized **Release** builds. To debug source, use **Edit Scheme → Run → Build Configuration → Debug**; unoptimized vector processing will be slower.

Add `--smoke-test` to the scheme launch arguments for a repeatable run of tile switches, camera commands, static input, and view recreation. Results are logged as `Native wrapper smoke`; visual rendering still needs a manual check. Remove the argument for normal use.

Use the buttons above the map to switch between OpenFreeMap Liberty vector tiles and OpenStreetMap raster tiles. Demo overlays exercise the marker, POI, road, and shape managers. Click markers and the blue road to check delegate delivery in the footer. Drag to pan, scroll/pinch to zoom, and use the toolbar for zoom, programmatic rotation, return to Zurich, and map recreation. The **Map input** toggle tests static mode while leaving toolbar commands available.

**My Location** requests location only when clicked. The host provides `NSLocationUsageDescription`, the sandbox location entitlement, and outgoing network access. Native macOS has no compass heading; heading is reported as zero. Declining location does not disable the map.

The deployment minimum is macOS 12. The port uses Swift 6.2 or newer for actor-isolated cleanup. Local checks use Xcode 26.5 / Swift 6.3.2 on macOS 26.5, Apple Silicon. Intel/AMD rendering, display-scale changes, native rotation gestures, hover, and long press remain separate validation or MapCore adapter work.
