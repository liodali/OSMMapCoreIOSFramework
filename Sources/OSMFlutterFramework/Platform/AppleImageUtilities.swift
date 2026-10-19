import Foundation
import CoreGraphics
import ImageIO
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum AppleImageUtilities {
    static func decodeCGImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func cgImage(_ image: OSMPlatformImage) -> CGImage? {
        #if os(macOS)
        var rect = CGRect(origin: .zero, size: image.size)
        guard let source = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        // AppKit symbols can use grayscale or extended-range pixel formats that
        // MetalKit cannot upload directly. Preserve their pixels and alpha in RGBA8.
        if source.bitsPerComponent == 8, source.colorSpace?.model == .rgb,
           source.alphaInfo == .premultipliedLast {
            return source
        }
        guard let context = CGContext(data: nil, width: source.width, height: source.height,
            bitsPerComponent: 8, bytesPerRow: source.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        return context.makeImage()
        #else
        return image.cgImage
        #endif
    }

    static func transparentPixel() -> CGImage {
        CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                  bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }

    static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    static func symbol(named name: String, tint: OSMPlatformColor) -> OSMPlatformImage {
        #if os(macOS)
        let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage(size: NSSize(width: 24, height: 24))
        guard let source = cgImage(symbol),
              let context = CGContext(data: nil, width: source.width, height: source.height,
                  bitsPerComponent: 8, bytesPerRow: source.width * 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let color = tint.usingColorSpace(.deviceRGB)?.cgColor else { return symbol }
        let rect = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        context.clip(to: rect, mask: source)
        context.setFillColor(color)
        context.fill(rect)
        guard let image = context.makeImage() else { return symbol }
        return NSImage(cgImage: image, size: symbol.size)
        #else
        return (UIImage(systemName: name) ?? UIImage()).withTintColor(tint)
        #endif
    }
}

#if os(macOS)
extension NSImage {
    func rotate(radians: Float) -> NSImage? {
        guard let source = AppleImageUtilities.cgImage(self), size.width > 0, size.height > 0 else { return nil }
        let rotated = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
        let logicalSize = CGSize(width: ceil(abs(rotated.width)), height: ceil(abs(rotated.height)))
        let scale = max(CGFloat(source.width) / size.width, CGFloat(source.height) / size.height)
        let width = max(1, Int(ceil(logicalSize.width * scale)))
        let height = max(1, Int(ceil(logicalSize.height * scale)))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: logicalSize.width / 2, y: logicalSize.height / 2)
        context.rotate(by: -CGFloat(radians))
        context.draw(source, in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        guard let image = context.makeImage() else { return nil }
        return NSImage(cgImage: image, size: logicalSize)
    }
}
#endif
