# Native macOS support plan

Status: framework port implemented; native raster/vector rendering confirmed by the user, five platform tests and the in-app smoke run passed. The iOS example was built, installed and launched on Dali’s paired iPhone through its network hostname. Catalyst compilation passed; additional manual coverage, Flutter integration and release remain follow-ups.

## Goal

Make the existing `OSMFlutterFramework` SPM product usable on native macOS,
while preserving iOS and Mac Catalyst behavior. The Flutter plugin will then
consume this product from one shared `darwin/` implementation.

Native macOS requires AppKit support; Mac Catalyst support alone is insufficient.

## Implementation progress (2026-10-19)

- [x] Add native macOS 12 to the existing SPM product, retaining iOS/Catalyst 14.
- [x] Introduce public platform view/image/color aliases and AppKit image helpers.
- [x] Adapt OSMView layout/input and keep camera callbacks on the main actor.
- [x] Adapt marker, POI, road, shape, and location types without exposing MapCore.
- [x] Share MSDF decoding with ImageIO and runtime SDF generation with CoreText.
- [x] Guard heading APIs and macOS authorization status; isolate location cleanup.
- [x] Make the native example use OSMView and framework-bundled assets, with public manager demos.
- [x] Update source documentation, host entitlements, and unreleased changelog.
- [x] Cancel superseded style downloads and retain the working base layer on download/construction failure.
- [x] Native arm64 Release example compilation passed on Xcode 26.5 / Swift 6.3.2, macOS 26.5.
- [x] Five SPM platform tests passed on macOS, including AppKit symbol RGBA8 upload format, layout/release, bundled assets, alpha, and Retina rotation. The lifecycle test used the shader library from the native Xcode build.
- [x] Build and sign the iOS example for Dali’s real iPhone; install and launch through its network hostname after cable disconnection. Startup logs confirm all three bundled MSDF font styles loaded; user confirmed map/labels and pan/zoom work on the phone.
- [x] Catalyst arm64 Release framework build passed after fixing stale font-provider paths and the omitted OSMViewProtocols.swift source in the standalone project.
- [ ] iOS Simulator compile remains for CI; real-device validation was prioritized at the user’s request.
- [ ] Run the prepared source-only Apple platform CI; CocoaPods workflows remain archived.
- [x] User confirmed the native vector map, labels, markers, blue road, green circle, and pan/zoom work.
- [x] In-app smoke run passed tile switches, camera position/zoom queries, camera commands with hit testing disabled, and release/recreation of the displayed OSMView.
- [x] User confirmed corrected native raster rendering. The example URL previously appended `.png` twice and now generates valid single-extension tile URLs.
- [ ] Check location permissions and multiple simultaneous maps manually.
- [ ] Validate Intel/AMD rendering and moving between Retina/non-Retina displays.
- [ ] Review and tag a new framework release, then port the separate Flutter plugin.

The port requires **Swift 6.2+** for actor-isolated teardown; CI is configured
for Xcode 26.3. The published `0.9.0` tag is unchanged and does not include this
port. The first native run exposed an AppKit symbol pixel format rejected by MetalKit. The framework now normalizes those images to RGBA8; its regression test passes and the rebuilt native app stays running. The user confirmed its vector map, labels, overlays, and pan/zoom work.

## Baseline before implementation

Verified against this repository on 2026-10-19:

- `Package.swift` declares iOS 14 and Mac Catalyst 14, but no macOS target.
- MapCore is pinned to `https://github.com/liodali/maps-core.git`,
  version `4.0.1-spm.2`; Polyline starts at `5.1.0`.
- `OSMView` inherits from `UIView` and implements `layoutSubviews()`.
- Marker, POI, location, road, and shape APIs use UIKit image/color types.
- Both MSDF and runtime SDF atlas providers contain UIKit dependencies.
- The native macOS example imports MapCore directly. It demonstrates the engine,
  rather than macOS compatibility of the `OSMFlutterFramework` wrapper.
- The package test target is currently commented out.

## 1. Confirm dependencies and deployment targets

- Verify the pinned MapCore and Polyline revisions build for native macOS,
  including MapCore's transitive packages and resource handling.
- Select the minimum macOS version from the actual dependency/API requirements;
  do not infer it from the existing iOS or Catalyst minimum.
- Add `.macOS(...)` to `Package.swift`, keeping iOS and Catalyst declarations.
- Preserve the package, product, and module names `OSMFlutterFramework`.
- Keep the manifest and example Xcode projects on the same MapCore URL/version.
- Keep resources bundled through SPM and resolve framework assets with
  `Bundle.module` where applicable.

## 2. Introduce a small Apple platform compatibility layer

Suggested structure within the existing SPM target:

```text
Sources/OSMFlutterFramework/
├── Platform/
│   ├── ApplePlatformTypes.swift
│   ├── AppleImageUtilities.swift
│   └── AppleFontUtilities.swift
├── OSMView.swift
├── OSMViewProtocols.swift
├── models/
├── providers/
└── Resources/
```

- Use conditional AppKit/UIKit imports and platform declarations.
- Consider public `OSMPlatformView`, `OSMPlatformImage`, and `OSMPlatformColor`
  aliases mapping to NSView/NSImage/NSColor or UIView/UIImage/UIColor.
- Preserve existing iOS call sites: aliases must resolve to the same UIKit types.
- Use `#if os(macOS)` for native AppKit code; keep Catalyst on the UIKit path.
- Encapsulate image decoding, pixel extraction, rotation, tint, symbol creation,
  and scale handling in helpers. Aliases alone do not adapt those APIs.
- Use CoreGraphics/CoreText for shared operations where practical.
- Keep MapCore implementation details out of the public API.
- Keep SwiftUI screens, controls, and overlays in the example applications.

The framework stays in `Sources/OSMFlutterFramework`; a `darwin/` directory is
needed in the consuming Flutter plugin, not inside this Swift package.

## 3. Adapt OSMView and view lifecycle

Files: `OSMView.swift`, `OSMViewProtocols.swift`.

- Make OSMView inherit from the platform view alias or use guarded platform shells
  around shared map setup and manager ownership.
- Implement AppKit `layout()` alongside UIKit `layoutSubviews()`.
- Size the embedded map using container bounds; verify nonzero origins,
  resizing, Retina scale, and moving between displays.
- Audit initialization, coder initializers, event handling, rotation enablement,
  touch disabling, tracking, and MapCore lifecycle differences.
- Reuse MapCore's platform input support where available; verify mouse clicks,
  dragging, wheel/trackpad zoom, and gesture callbacks.
- Verify map teardown releases listeners, rendering resources, and location work.
- Keep UI/rendering access on the appropriate actor/thread and preserve shared
  commands, tile configuration, camera behavior, and delegate contracts.

## 4. Adapt managers, images, and colors

Files:

- `models/OSMMarker.swift`
- `models/MarkerManager.swift`
- `models/PoisManager.swift`
- `models/LocationManager.swift`
- `models/RoadManager.swift`
- `models/ShapeManager.swift`
- `models/extensions.swift`

Tasks:

- Replace exposed UIImage/UIColor requirements with compatible platform types.
- Implement AppKit equivalents for default marker and direction icons.
- Adapt image rotation and texture creation; preserve alpha, orientation,
  anchor position, and logical size versus pixel size.
- Normalize color conversion for AppKit color spaces before producing MapCore
  colors; verify road borders and shape fills.
- Preserve existing iOS signatures at the source level and existing manager
  behavior, including POI groups, marker callbacks, and road selection.

## 5. Port font and atlas loading

Files: `SystemFontLoader.swift`, `providers/MSDFAtlasProvider.swift`,
`providers/RuntimeSDFAtlasProvider.swift`, and related provider contracts.

- Audit the full loader path for UIKit assumptions, including PNG decoding,
  UIFont descriptors, glyph drawing, and atlas debug output.
- Share atlas parsing, caches, metrics, and CoreText/CoreGraphics operations.
- Provide AppKit font/image adapters where native types are required.
- Reuse the macOS example's working font-loading approach where appropriate;
  ensure the framework can render labels without example-only implementation.
- Verify bundled fonts, fallback glyphs, atlas alpha, and vector labels on macOS.

## 6. Adapt location behavior

File: `models/LocationManager.swift`.

- Audit authorization calls/status handling and API availability on macOS.
- Guard unsupported heading operations and define behavior when heading is absent.
- Keep location updates useful without a compass; avoid assuming mobile hardware.
- Handle denied/unavailable location without preventing map initialization.
- Document host application requirements for location usage descriptions and
  sandbox location entitlement, plus network entitlement for sandboxed map apps.
- Keep application permissions and entitlements in the host, not package resources.

## 7. Validate the wrapper through examples and checks

- Update `example/MapCoreMacOSExample/` to instantiate OSMView through
  OSMFlutterFramework and exercise its public managers. Move any direct-MapCore
  diagnostics to a separate example path if still useful.
- Build the native macOS framework and example for supported architectures.
- Build the existing iOS example for simulator/device and check Catalyst.
- Add focused tests for shared logic affected by the port, such as image/color
  conversion and coordinate/size handling; enable a suitable SPM test target.
- Verify raster and vector tiles, labels, tile switching, pan/zoom/rotation,
  bounds, markers and POIs, roads and taps, shapes, location, and static mode.
- Verify resizing, Retina rendering, multiple maps, and repeated create/dispose.
- Add CI compile coverage for native macOS and iOS, and document tested Xcode,
  Swift, OS, and architecture requirements.

## 8. Release and integrate with Flutter

Framework release:

- Update README and changelog with macOS support, minimum OS, supported features,
  host permissions, and any platform limitations.
- Review API compatibility and choose an appropriate new version.
- Tag the verified framework revision; the Flutter plugin should pin that release.

Follow-up in the separate `flutter_osm_plugin` repository:

- Move the native Swift package into `darwin/flutter_osm_plugin/`.
- Set `sharedDarwinSource: true` for iOS and macOS in `pubspec.yaml`.
- Use one Package.swift with both supported OS targets and the new framework pin.
- Add conditional Flutter/FlutterMacOS registration and view factories.
- Use AppKitView on Dart's macOS path and preserve UiKitView for iOS.
- Audit Apple initialization, marker serialization, scaling, and platform checks.
- Preserve existing channel behavior and resolve the frozen CocoaPods path during
  the directory migration.
- Add a macOS Flutter example and verify both Apple platforms end to end.

## Completion criteria

Native macOS applications can import OSMFlutterFramework and use OSMView,
its managers, fonts, and resources without importing MapCore directly or copying
example-only helpers. Existing iOS and Catalyst integrations continue to build
and behave correctly. The released framework can then be embedded by the shared
Flutter Darwin implementation.
