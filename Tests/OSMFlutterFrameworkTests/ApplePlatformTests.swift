import XCTest
import CoreGraphics
import Metal
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import OSMFlutterFramework

final class ApplePlatformTests: XCTestCase {
    func testPNGDecodingPreservesAlphaAndDimensions() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 4, height: 2, bitsPerComponent: 8,
            bytesPerRow: 16, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        let image = try XCTUnwrap(context.makeImage())
        let data = try XCTUnwrap(AppleImageUtilities.pngData(image))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        let decoded = try XCTUnwrap(AppleImageUtilities.decodeCGImage(at: url))
        XCTAssertEqual(decoded.width, 4)
        XCTAssertEqual(decoded.height, 2)
        let output = try XCTUnwrap(CGContext(data: nil, width: 4, height: 2, bitsPerComponent: 8,
            bytesPerRow: 16, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        output.draw(decoded, in: CGRect(x: 0, y: 0, width: 4, height: 2))
        let pixels = try XCTUnwrap(output.data).assumingMemoryBound(to: UInt8.self)
        XCTAssertEqual(Int(pixels[3]), 128, accuracy: 1)
        XCTAssertEqual(pixels[15], 0)
    }

    func testBundledAtlasResourcesAreInFrameworkBundle() {
        for variant in ["Regular", "Bold", "Italic"] {
            XCTAssertNotNil(FontResourceBundle.bundle.url(forResource: "NotoSans-\(variant)", withExtension: "json"))
            XCTAssertNotNil(FontResourceBundle.bundle.url(forResource: "Noto_Sans_\(variant)", withExtension: "png"))
        }
    }

    #if os(macOS)
    func testAppKitSymbolsUseMetalCompatibleRGBA8() async throws {
        try await MainActor.run {
            let symbol = try XCTUnwrap(NSImage(systemSymbolName: "mappin.circle.fill", accessibilityDescription: nil))
            let pixels = try XCTUnwrap(AppleImageUtilities.cgImage(symbol))
            XCTAssertEqual(pixels.bitsPerComponent, 8)
            XCTAssertEqual(pixels.bitsPerPixel, 32)
            XCTAssertEqual(pixels.colorSpace?.model, .rgb)
            XCTAssertEqual(pixels.alphaInfo, .premultipliedLast)
        }
    }

    func testRotationPreservesLogicalAndRetinaSizes() async throws {
        try await MainActor.run {
            let context = try XCTUnwrap(CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8,
                bytesPerRow: 160, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
            let image = NSImage(cgImage: try XCTUnwrap(context.makeImage()), size: NSSize(width: 20, height: 10))
            let rotated = try XCTUnwrap(image.rotate(radians: .pi / 2))
            XCTAssertEqual(rotated.size.width, 10, accuracy: 1)
            XCTAssertEqual(rotated.size.height, 20, accuracy: 1)
            let pixels = try XCTUnwrap(AppleImageUtilities.cgImage(rotated))
            XCTAssertEqual(pixels.width, 20, accuracy: 2)
            XCTAssertEqual(pixels.height, 40, accuracy: 2)
        }
    }

    func testMapLayoutUsesBoundsAndViewCanBeReleased() async throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "MapCore requires Metal")
        // swift test copies .metal sources; Xcode compiles the engine's metallib.
        // Avoid invoking MapCore's fatal initializer when that library is absent.
        let products = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        let libraries = ["MapCore_MapCore.bundle/default.metallib",
                         "MapCore_MapCore.bundle/Contents/Resources/default.metallib"]
        try XCTSkipUnless(libraries.contains {
            FileManager.default.fileExists(atPath: products.appendingPathComponent($0).path)
        }, "Run map lifecycle checks with Xcode-compiled Metal resources")
        await MainActor.run {
            weak var released: OSMView?
            autoreleasepool {
                let map = OSMView(rect: CGRect(x: 73, y: 31, width: 320, height: 240), location: nil,
                                  zoomConfig: ZoomConfiguration(initZoom: 12))
                released = map
                map.layout()
                XCTAssertEqual(map.subviews.first?.frame, map.bounds)
                map.setFrameSize(NSSize(width: 640, height: 480))
                map.layout()
                XCTAssertEqual(map.subviews.first?.frame, map.bounds)
            }
            XCTAssertNil(released, "Camera listeners must not retain the wrapper")
        }
    }
    #endif
}
