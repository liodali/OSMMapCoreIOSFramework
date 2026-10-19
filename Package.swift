// swift-tools-version:6.2
import PackageDescription

let package = Package(

  name: "OSMFlutterFramework",

  platforms: [.iOS(.v14), .macCatalyst(.v14), .macOS(.v12)],

  products: [
    .library(name: "OSMFlutterFramework", targets: ["OSMFlutterFramework"])
  ],
  dependencies: [
    // MapCore 4.0.0 with stable remote djinni resolution (upstream issue #929)
    // and an AppKit fallback for indexed PNG tiles.
    .package(url: "https://github.com/liodali/maps-core.git", exact: "4.0.1-spm.2"),
    .package(url: "https://github.com/raphaelmor/Polyline.git", from: "5.1.0"),
  ],
  targets: [
    .target(
      name: "OSMFlutterFramework",
      dependencies: [
        .product(name: "MapCore", package: "maps-core"),
        .product(name: "Polyline", package: "Polyline"),
      ],
      path: "Sources/OSMFlutterFramework",
      resources: [
        .process("Resources")
      ],
      //(name: "enable-experimental-features", value: "true")
      // swiftSettings: [
      //     .unsafeFlags(["-enable-experimental-feature", "AccessLevelOnImport"])
      // ]
    ),
    .testTarget(
      name: "OSMFlutterFrameworkTests",
      dependencies: ["OSMFlutterFramework"],
      path: "Tests/OSMFlutterFrameworkTests"
    )
  ]
)
