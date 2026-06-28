// swift-tools-version:6.1
import PackageDescription

let package = Package(

  name: "OSMFlutterFramework",

  platforms: [.iOS(.v14), .macCatalyst(.v14)],

  products: [
    .library(name: "OSMFlutterFramework", targets: ["OSMFlutterFramework"])
  ],
  dependencies: [
    .package(url: "https://github.com/UbiqueInnovation/djinni.git", from: "1.0.9"),
    .package(url: "https://github.com/openmobilemaps/maps-core.git", from: "3.7.1"),
    .package(url: "https://github.com/raphaelmor/Polyline.git", from: "5.1.0"),
  ],
  targets: [
    .target(
      name: "OSMFlutterFramework",
      dependencies: [
        .product(name: "DjinniSupport", package: "djinni"),
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
    )

    /*,
    .testTarget(
      name: "OSMFlutterFrameworkTests",
      dependencies: ["OSMFlutterFramework"]
    )*/
  ]
)
