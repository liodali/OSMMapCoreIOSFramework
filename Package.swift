// swift-tools-version:5.9
import PackageDescription


let package = Package(
  
  name: "OSMFlutterFramework",
  
  platforms: [.iOS(.v13),.macCatalyst(.v13), ],
  
  products: [
    .library(name: "OSMFlutterFramework", targets: ["OSMFlutterFramework"])
  ],
  dependencies: [
    .package(url: "https://github.com/openmobilemaps/maps-core.git", from: "2.4.0"),
    .package(url: "https://github.com/UbiqueInnovation/djinni.git", from: "1.0.7"),
    .package(url: "https://github.com/raphaelmor/Polyline.git", from: "5.1.0")
  ],
  targets: [
    .target(name: "OSMFlutterFramework",
            path: "Sources/OSMFlutterFramework",
            publicHeadersPath: "Sources/OSMFlutterFramework/",
            dependencies: [
                    "maps-core",
                    "djinni",
                    "Polyline"
                  ],
           ),
    .testTarget(
      name: "OSMFlutterFrameworkTests",
      dependencies: ["OSMFlutterFramework"]
    )
  ]
)
