import Foundation
import MapCore

/// Uses the same bundled Noto Sans MSDF atlases as the iOS example.
final class NativeFontLoader: NSObject, MCFontLoaderInterface, @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: MCFontLoaderResult] = [:]

    func load(_ font: MCFont) -> MCFontLoaderResult {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[font.name] { return cached }

        let lowercased = font.name.lowercased()
        let variant = lowercased.contains("bold") ? "Bold" : (lowercased.contains("italic") ? "Italic" : "Regular")
        guard let jsonURL = Bundle.main.url(forResource: "NotoSans-\(variant)", withExtension: "json"),
              let pngURL = Bundle.main.url(forResource: "Noto_Sans_\(variant)", withExtension: "png"),
              let json = try? Data(contentsOf: jsonURL),
              let fontData = MCFontLoader.parseFontData(json, fontName: font.name),
              let png = try? Data(contentsOf: pngURL),
              let texture = try? TextureHolder(png) else {
            NSLog("Native vector font failed: %@", font.name)
            return MCFontLoaderResult(imageData: nil, fontData: nil, status: .ERROR_OTHER)
        }
        let result = MCFontLoaderResult(imageData: texture, fontData: fontData, status: .OK)
        cache[font.name] = result
        NSLog("Native vector font loaded: %@ via Noto Sans %@", font.name, variant)
        return result
    }
}
