// swift-tools-version:5.9
import PackageDescription


let package = Package(
  
  name: "OSMFlutterFramework",
  
  platforms: [.iOS(.v13)],
  
  products: [
    .library(name: "OSMFlutterFramework", targets: ["OSMFlutterFramework"])
  ],
  dependencies: [
    .package(url: "https://github.com/openmobilemaps/maps-core.git", from: "2.4.0"),
  ],
  targets: [
    .target(name: "OSMFlutterFramework"),
    .testTarget(
      name: "OSMFlutterFrameworkTests",
      dependencies: ["OSMFlutterFramework"]
    )
  ]
)
