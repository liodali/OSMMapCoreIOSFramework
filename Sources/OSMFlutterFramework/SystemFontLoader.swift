//
//  SystemFontLoader.swift
//  OSMFlutterFramework
//
//  Copyright © 2026 Dali Hamza. All rights reserved.
//

import CoreText
import Foundation
import UIKit

#if compiler(>=5.10)
    /* private */ internal import MapCore
#else
    @_implementationOnly import MapCore
#endif

class SystemFontLoader: NSObject, @unchecked Sendable, MCFontLoaderInterface {
    private let fontMappings: [String: UIFont]
    private let charset: String
    private let atlasSize: CGSize
    private let fontSize: CGFloat
    private let padding: CGFloat
    private let distanceRange: CGFloat
    private let cache = NSCache<NSString, FontAtlas>()
    private let cacheLock = NSLock()

    init(
        fontMappings: [String: UIFont],
        charset: String,
        atlasSize: CGSize = CGSize(width: 2048, height: 2048),
        fontSize: CGFloat = 64,
        padding: CGFloat = 2,
        distanceRange: CGFloat = 8
    ) {
        self.fontMappings = fontMappings
        self.charset = charset
        self.atlasSize = atlasSize
        self.fontSize = fontSize
        self.padding = padding
        self.distanceRange = distanceRange
        super.init()
        cache.countLimit = 8
    }

    convenience init(
        defaultMappings: Bool = true,
        extraMappings: [String: UIFont] = [:],
        charset: String = SystemFontLoader.defaultCharset
    ) {
        var mappings: [String: UIFont] = [:]
        if defaultMappings {
            mappings = SystemFontLoader.defaultFontMappings
        }
        for (key, value) in extraMappings {
            mappings[key] = value
        }
        self.init(fontMappings: mappings, charset: charset)
    }

    func load(_ font: MCFont) -> MCFontLoaderResult {
        let name = font.name
        print("SystemFontLoader.load: \(name)")
        cacheLock.lock()
        if let cached = cache.object(forKey: name as NSString) {
            cacheLock.unlock()
            return MCFontLoaderResult(
                imageData: cached.texture, fontData: cached.fontData, status: .OK)
        }
        cacheLock.unlock()

        let uiFont =
            fontMappings[name] ?? SystemFontLoader.uiFont(forStyleName: name, size: fontSize)
        guard let atlas = generateAtlas(font: uiFont, name: name) else {
            return MCFontLoaderResult(imageData: nil, fontData: nil, status: .ERROR_OTHER)
        }

        cacheLock.lock()
        cache.setObject(atlas, forKey: name as NSString)
        cacheLock.unlock()

        return MCFontLoaderResult(imageData: atlas.texture, fontData: atlas.fontData, status: .OK)
    }

    static let defaultFontMappings: [String: UIFont] = [
        "Noto Sans Regular": UIFont.systemFont(ofSize: 64),
        "Noto Sans Bold": UIFont.boldSystemFont(ofSize: 64),
        "Noto Sans Italic": UIFont.italicSystemFont(ofSize: 64),
        "Open Sans Regular": UIFont.systemFont(ofSize: 64),
        "Open Sans Bold": UIFont.boldSystemFont(ofSize: 64),
        "Open Sans Italic": UIFont.italicSystemFont(ofSize: 64),
        "Arial Unicode MS Regular": UIFont.systemFont(ofSize: 64),
        "Roboto Regular": UIFont.systemFont(ofSize: 64),
        "Roboto Bold": UIFont.boldSystemFont(ofSize: 64),
        "Roboto Italic": UIFont.italicSystemFont(ofSize: 64),
    ]

    static let defaultCharset: String = {
        let latin = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        let digits = "0123456789"
        let punctuation = " .,;:!?-_/'\"()[]{}&@#$%*+=<>~`"
        let latin1 = String(
            (0x00C0...0x00FF).compactMap { UnicodeScalar($0) }.map { Character($0) })
        let latinExtendedA = String(
            (0x0100...0x017F).compactMap { UnicodeScalar($0) }.map { Character($0) })
        let latinExtendedB = String(
            (0x0180...0x024F).compactMap { UnicodeScalar($0) }.map { Character($0) })
        return latin + digits + punctuation + latin1 + latinExtendedA + latinExtendedB
    }()

    private static func uiFont(forStyleName name: String, size: CGFloat) -> UIFont {
        let lowercased = name.lowercased()
        let weight: UIFont.Weight
        if lowercased.contains("bold") {
            weight = .bold
        } else if lowercased.contains("semibold") || lowercased.contains("medium") {
            weight = .semibold
        } else if lowercased.contains("light") || lowercased.contains("thin") {
            weight = .light
        } else {
            weight = .regular
        }
        let traits: UIFontDescriptor.SymbolicTraits
        if lowercased.contains("italic") {
            traits = .traitItalic
        } else {
            traits = []
        }
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .addingAttributes([
                .traits: [
                    UIFontDescriptor.TraitKey.weight: weight,
                    UIFontDescriptor.TraitKey.symbolic: traits.rawValue,
                ]
            ])
        return UIFont(descriptor: descriptor, size: size)
    }

    private struct GlyphEntry {
        let charCode: String
        let glyph: CGGlyph
        let bounds: CGRect
        let advance: CGSize
        let imageSize: CGSize
        var atlasX: CGFloat = 0
        var atlasY: CGFloat = 0
    }

    private class FontAtlas {
        let texture: TextureHolder
        let fontData: MCFontData
        init(texture: TextureHolder, fontData: MCFontData) {
            self.texture = texture
            self.fontData = fontData
        }
    }

    private func generateAtlas(font: UIFont, name: String) -> FontAtlas? {
        let ctFont = CTFontCreateWithFontDescriptor(font.fontDescriptor, fontSize, nil)
        var entries: [GlyphEntry] = []
        var spaceEntry: GlyphEntry?
        let charCodes = Array(charset)
        for char in charCodes {
            let string = String(char)
            var glyph: CGGlyph = 0
            let scalar = char.unicodeScalars.first?.value ?? 0
            if !CTFontGetGlyphsForCharacters(ctFont, [UniChar(scalar)], &glyph, 1) {
                continue
            }
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &advance, 1)
            var bounds = CGRect.zero
            CTFontGetBoundingRectsForGlyphs(ctFont, .horizontal, &glyph, &bounds, 1)
            let imageSize = CGSize(
                width: max(1, ceil(bounds.width)) + distanceRange * 2 + padding * 2,
                height: max(1, ceil(abs(bounds.height))) + distanceRange * 2 + padding * 2
            )
            let entry = GlyphEntry(
                charCode: string,
                glyph: glyph,
                bounds: bounds,
                advance: advance,
                imageSize: imageSize
            )
            if string == " " {
                spaceEntry = entry
            } else {
                entries.append(entry)
            }
        }

        if let space = spaceEntry {
            entries.append(space)
        }

        guard !entries.isEmpty else { return nil }

        let sortedEntries = entries.sorted { $0.imageSize.height > $1.imageSize.height }
        var packed: [GlyphEntry] = []
        var shelves: [(x: CGFloat, y: CGFloat, height: CGFloat, remainingWidth: CGFloat)] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxRowHeight: CGFloat = 0

        for var entry in sortedEntries {
            var placed = false
            for i in 0..<shelves.count {
                if shelves[i].height >= entry.imageSize.height
                    && shelves[i].remainingWidth >= entry.imageSize.width
                {
                    entry.atlasX = shelves[i].x
                    entry.atlasY = shelves[i].y
                    shelves[i].x += entry.imageSize.width
                    shelves[i].remainingWidth -= entry.imageSize.width
                    placed = true
                    break
                }
            }
            if !placed {
                if currentX + entry.imageSize.width > atlasSize.width {
                    currentY += maxRowHeight
                    currentX = 0
                    maxRowHeight = 0
                }
                if currentY + entry.imageSize.height > atlasSize.height {
                    return nil
                }
                entry.atlasX = currentX
                entry.atlasY = currentY
                shelves.append(
                    (
                        x: currentX, y: currentY, height: entry.imageSize.height,
                        remainingWidth: atlasSize.width - currentX
                    ))
                currentX += entry.imageSize.width
                maxRowHeight = max(maxRowHeight, entry.imageSize.height)
            }
            packed.append(entry)
        }

        let atlasWidth = Int(atlasSize.width)
        let atlasHeight = Int(atlasSize.height)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let rgbBitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            .init(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
        guard
            let atlasContext = CGContext(
                data: nil,
                width: atlasWidth,
                height: atlasHeight,
                bitsPerComponent: 8,
                bytesPerRow: atlasWidth * 4,
                space: rgbColorSpace,
                bitmapInfo: rgbBitmapInfo.rawValue
            )
        else {
            return nil
        }

        atlasContext.setFillColor(UIColor.clear.cgColor)
        atlasContext.fill(CGRect(origin: .zero, size: atlasSize))

        for entry in packed {
            guard let glyphImage = createSDFGlyphImage(ctFont: ctFont, entry: entry) else {
                continue
            }
            let bottomUpY = atlasSize.height - entry.atlasY - entry.imageSize.height
            let drawRect = CGRect(
                x: entry.atlasX,
                y: bottomUpY,
                width: entry.imageSize.width,
                height: entry.imageSize.height)
            atlasContext.draw(glyphImage, in: drawRect)
        }

        guard let atlasCGImage = atlasContext.makeImage() else {
            return nil
        }

        // Debug: save atlas image to Documents directory
        let uiImage = UIImage(cgImage: atlasCGImage)
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = docs.appendingPathComponent(
                "font_atlas_\(name.replacingOccurrences(of: " ", with: "_")).png")
            if let pngData = uiImage.pngData() {
                try? pngData.write(to: url)
                print("DEBUG: Atlas saved to \(url.path)")
            }
        }

        let textureHolder: TextureHolder
        do {
            textureHolder = try TextureHolder(atlasCGImage)
        } catch {
            return nil
        }

        let lineHeight = Double(font.lineHeight / fontSize)
        let base = Double(font.ascender / fontSize)
        let bitmapSize = MCVec2D(x: Double(atlasSize.width), y: Double(atlasSize.height))
        let info = MCFontWrapper(
            name: name,
            lineHeight: lineHeight,
            base: base,
            bitmapSize: bitmapSize,
            size: Double(fontSize),
            distanceRange: Double(distanceRange)
        )

        // Create a lookup map from charCode to packed entry
        var packedMap: [String: GlyphEntry] = [:]
        for entry in packed {
            packedMap[entry.charCode] = entry
        }

        // Build glyphs array in the original charset order (entries order), not packed order
        var glyphs: [MCFontGlyph] = []
        for entry in entries {
            guard let packedEntry = packedMap[entry.charCode] else { continue }

            let s0 = Double(packedEntry.atlasX / atlasSize.width)
            let s1 = Double((packedEntry.atlasX + packedEntry.imageSize.width) / atlasSize.width)
            let t0 = Double(packedEntry.atlasY / atlasSize.height)
            let t1 = Double((packedEntry.atlasY + packedEntry.imageSize.height) / atlasSize.height)
            let uv = MCQuad2dD(
                topLeft: MCVec2D(x: s0, y: t1),
                topRight: MCVec2D(x: s1, y: t1),
                bottomRight: MCVec2D(x: s1, y: t0),
                bottomLeft: MCVec2D(x: s0, y: t0)
            )
            let advance = MCVec2D(
                x: Double(packedEntry.advance.width / fontSize),
                y: 0.0)
            let size = MCVec2D(
                x: Double(packedEntry.imageSize.width / fontSize),
                y: Double(packedEntry.imageSize.height / fontSize))
            let bearing = MCVec2D(
                x: Double((packedEntry.bounds.origin.x - distanceRange - padding) / fontSize),
                y: Double((distanceRange + padding - packedEntry.bounds.origin.y) / fontSize))

            let glyph = MCFontGlyph(
                charCode: packedEntry.charCode,
                advance: advance,
                boundingBoxSize: size,
                bearing: bearing,
                uv: uv
            )
            glyphs.append(glyph)
        }

        let fontData = MCFontData(info: info, glyphs: glyphs)
        return FontAtlas(texture: textureHolder, fontData: fontData)
    }

    private func createSDFGlyphImage(ctFont: CTFont, entry: GlyphEntry) -> CGImage? {
        let width = Int(entry.imageSize.width)
        let height = Int(entry.imageSize.height)
        guard width > 0, height > 0 else { return nil }

        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        let grayBitmapInfo = CGImageAlphaInfo.none.rawValue
        var grayPixels = [UInt8](repeating: 0, count: width * height)
        guard
            let grayContext = CGContext(
                data: &grayPixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: grayColorSpace,
                bitmapInfo: grayBitmapInfo
            )
        else { return nil }

        grayContext.setFillColor(UIColor.black.cgColor)
        grayContext.fill(CGRect(origin: .zero, size: entry.imageSize))
        grayContext.setFillColor(UIColor.white.cgColor)

        let drawX = distanceRange + padding - entry.bounds.origin.x
        let drawY = distanceRange + padding - entry.bounds.origin.y
        grayContext.saveGState()
        grayContext.translateBy(x: drawX, y: drawY)
        if let path = CTFontCreatePathForGlyph(ctFont, entry.glyph, nil) {
            grayContext.addPath(path)
            grayContext.fillPath()
        }
        grayContext.restoreGState()

        var mask = [[Bool]](repeating: [Bool](repeating: false, count: width), count: height)
        for y in 0..<height {
            for x in 0..<width {
                mask[y][x] = grayPixels[y * width + x] > 127
            }
        }

        // Debug: save raw glyph mask for letter 'A'
        if entry.charCode == "A" {
            var debugRGBA = [UInt8](repeating: 0, count: width * height * 4)
            for y in 0..<height {
                for x in 0..<width {
                    let v = grayPixels[y * width + x]
                    let idx = (y * width + x) * 4
                    debugRGBA[idx] = v
                    debugRGBA[idx + 1] = v
                    debugRGBA[idx + 2] = v
                    debugRGBA[idx + 3] = 255
                }
            }
            let cs = CGColorSpaceCreateDeviceRGB()
            let bi = CGBitmapInfo.byteOrder32Big.union(
                .init(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
            if let ctx = CGContext(
                data: &debugRGBA, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: cs, bitmapInfo: bi.rawValue),
                let img = ctx.makeImage()
            {
                if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                    .first
                {
                    let url = docs.appendingPathComponent("debug_glyph_A_raw.png")
                    try? UIImage(cgImage: img).pngData()?.write(to: url)
                    print("DEBUG: Raw glyph A saved to \(url.path) (\(width)x\(height))")
                }
            }
        }

        let distToOutside = computeDistanceField(mask: mask, target: false)
        let distToInside = computeDistanceField(mask: mask, target: true)
        var sdf = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let dist = mask[y][x] ? distToOutside[y][x] : distToInside[y][x]
                let value = 0.5 + (mask[y][x] ? dist : -dist) / (2.0 * Double(distanceRange))
                let clamped = min(1.0, max(0.0, value))
                sdf[y * width + x] = UInt8(clamped * 255.0)
            }
        }

        // Debug: save SDF for letter 'A'
        if entry.charCode == "A" {
            var debugRGBA = [UInt8](repeating: 0, count: width * height * 4)
            for i in 0..<(width * height) {
                let v = sdf[i]
                let idx = i * 4
                debugRGBA[idx] = v
                debugRGBA[idx + 1] = v
                debugRGBA[idx + 2] = v
                debugRGBA[idx + 3] = 255
            }
            let cs = CGColorSpaceCreateDeviceRGB()
            let bi = CGBitmapInfo.byteOrder32Big.union(
                .init(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
            if let ctx = CGContext(
                data: &debugRGBA, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: cs, bitmapInfo: bi.rawValue),
                let img = ctx.makeImage()
            {
                if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                    .first
                {
                    let url = docs.appendingPathComponent("debug_glyph_A_sdf.png")
                    try? UIImage(cgImage: img).pngData()?.write(to: url)
                    print("DEBUG: SDF glyph A saved to \(url.path)")
                }
            }
        }

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            let v = sdf[i]
            let base = i * 4
            rgba[base] = v
            rgba[base + 1] = v
            rgba[base + 2] = v
            rgba[base + 3] = 255
        }

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let rgbBitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            .init(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
        guard
            let rgbaContext = CGContext(
                data: &rgba,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: rgbColorSpace,
                bitmapInfo: rgbBitmapInfo
            )
        else { return nil }

        return rgbaContext.makeImage()
    }

    private func computeDistanceField(mask: [[Bool]], target: Bool) -> [[Double]] {
        let width = mask[0].count
        let height = mask.count
        let INF = Double(width * width + height * height) + 1.0
        var dist = [[Double]](repeating: [Double](repeating: INF, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] == target {
                    dist[y][x] = 0
                }
            }
        }

        for y in 1..<height {
            for x in 0..<width {
                var d = dist[y][x]
                let diag = 1.41421356
                if x > 0 { d = min(d, dist[y - 1][x - 1] + diag) }
                d = min(d, dist[y - 1][x] + 1.0)
                if x < width - 1 { d = min(d, dist[y - 1][x + 1] + diag) }
                if x > 0 { d = min(d, dist[y][x - 1] + 1.0) }
                dist[y][x] = d
            }
        }

        for y in (0..<(height - 1)).reversed() {
            for x in (0..<width).reversed() {
                var d = dist[y][x]
                let diag = 1.41421356
                if x < width - 1 { d = min(d, dist[y + 1][x + 1] + diag) }
                d = min(d, dist[y + 1][x] + 1.0)
                if x > 0 { d = min(d, dist[y + 1][x - 1] + diag) }
                if x < width - 1 { d = min(d, dist[y][x + 1] + 1.0) }
                dist[y][x] = d
            }
        }

        return dist
    }
}
