//
//  RuntimeSDFAtlasProvider.swift
//  OSMFlutterFramework
//
//  Copyright © 2026 Dali Hamza. All rights reserved.
//

import CoreText
import Foundation
import ImageIO

#if compiler(>=5.10)
    /* private */ internal import MapCore
#else
    @_implementationOnly import MapCore
#endif

/// Generates SDF font atlases at runtime from CTFont glyphs.
/// Self-contained — no dependency on MSDFAtlasProvider.
/// Requires bundled TTF files or system fonts to resolve font names.
class RuntimeSDFAtlasProvider: FontAtlasProvider {

    private let fontMappings: [String: CTFont]
    private let charset: String
    private let atlasSize: CGSize
    private let fontSize: CGFloat
    private let padding: CGFloat
    private let distanceRange: CGFloat

    init(
        fontMappings: [String: CTFont] = [:],
        charset: String = RuntimeSDFAtlasProvider.defaultCharset,
        atlasSize: CGSize = CGSize(width: 1024, height: 1024),
        fontSize: CGFloat = 28,
        padding: CGFloat = 2,
        distanceRange: CGFloat = 4
    ) {
        self.fontMappings = fontMappings
        self.charset = charset
        self.atlasSize = atlasSize
        self.fontSize = fontSize
        self.padding = padding
        self.distanceRange = distanceRange
    }

    func loadAtlas(forName name: String) -> FontAtlas? {
        let font = fontMappings[name] ?? Self.resolveFont(forStyleName: name, size: fontSize)
        return generateAtlas(font: font, name: name)
    }

    // MARK: - Font resolution

    private static func loadBundledFont(ttfName: String, size: CGFloat) -> CTFont? {
        guard let url = FontResourceBundle.bundle.url(forResource: ttfName, withExtension: "ttf"),
              let provider = CGDataProvider(url: url as CFURL), let font = CGFont(provider) else { return nil }
        return CTFontCreateWithGraphicsFont(font, size, nil, nil)
    }

    static let defaultCharset: String = {
        let ascii = String(
            (0x21...0x7E).compactMap { UnicodeScalar($0) }.map { Character($0) })
        let latin1 = String(
            (0x00A1...0x00FF).compactMap { UnicodeScalar($0) }.map { Character($0) })
        let greek =
            "\u{03B1}\u{03B2}\u{0393}\u{03C0}\u{03A3}\u{03C3}\u{03BC}\u{03C4}\u{03A6}\u{0398}\u{03A9}\u{03B4}\u{03C6}\u{03B5}"
        let symbols = "\u{2022}\u{221E}\u{207F}"
        return ascii + latin1 + greek + symbols
    }()

    private static func resolveFont(forStyleName name: String, size: CGFloat) -> CTFont {
        let lowercased = name.lowercased()
        let variant = lowercased.contains("bold") ? "Bold" : (lowercased.contains("italic") ? "Italic" : "Regular")
        if let font = loadBundledFont(ttfName: "NotoSans-\(variant)", size: size) { return font }
        return CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    // MARK: - SDF atlas generation

    private struct GlyphEntry {
        let charCode: String
        let glyph: CGGlyph
        let bounds: CGRect
        let advance: CGSize
        let imageSize: CGSize
        var atlasX: CGFloat = 0
        var atlasY: CGFloat = 0
    }

    private func generateAtlas(font: CTFont, name: String) -> FontAtlas? {
        let ctFont = font
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

        atlasContext.translateBy(x: 0, y: atlasSize.height)
        atlasContext.scaleBy(x: 1.0, y: -1.0)

        atlasContext.setFillColor(CGColor(gray: 0, alpha: 1))
        atlasContext.fill(CGRect(origin: .zero, size: atlasSize))

        for entry in packed {
            guard let glyphImage = createSDFGlyphImage(ctFont: ctFont, entry: entry) else {
                continue
            }
            let drawRect = CGRect(
                x: entry.atlasX,
                y: entry.atlasY,
                width: entry.imageSize.width,
                height: entry.imageSize.height)
            atlasContext.draw(glyphImage, in: drawRect)
        }

        guard let atlasCGImage = atlasContext.makeImage() else {
            return nil
        }

        let atlasPNG = AppleImageUtilities.pngData(atlasCGImage)
        if ProcessInfo.processInfo.arguments.contains("--osm-font-debug"),
           let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = docs.appendingPathComponent(
                "font_atlas_\(name.replacingOccurrences(of: " ", with: "_")).png")
            if let pngData = atlasPNG {
                try? pngData.write(to: url)
                print("DEBUG: Atlas saved to \(url.path)")
            }

            if let correctImage = {
                let correctURL = docs.appendingPathComponent(
                    "font_atlas_\(name.replacingOccurrences(of: " ", with: "_"))_correct.png"
                )
                return FileManager.default.fileExists(atPath: correctURL.path)
                    ? AppleImageUtilities.decodeCGImage(at: correctURL)
                    : nil
            }() {
                let comparison = compareAtlases(
                    generated: atlasCGImage,
                    reference: correctImage,
                    name: name)
                print("DEBUG: Atlas comparison for \(name): \(comparison)")
            }
        }

        let textureHolder: TextureHolder
        do {
            textureHolder = try TextureHolder(atlasCGImage)
        } catch {
            return nil
        }

        let lineHeight = Double((CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)) / fontSize)
        let base = Double(CTFontGetAscent(font) / fontSize)
        let bitmapSize = MCVec2D(x: Double(atlasSize.width), y: Double(atlasSize.height))
        let info = MCFontWrapper(
            name: name,
            lineHeight: lineHeight,
            base: base,
            bitmapSize: bitmapSize,
            size: Double(fontSize),
            distanceRange: Double(distanceRange)
        )

        var packedMap: [String: GlyphEntry] = [:]
        for entry in packed {
            packedMap[entry.charCode] = entry
        }

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
                y: Double((packedEntry.bounds.origin.y - distanceRange - padding) / fontSize))

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

        grayContext.setFillColor(CGColor(gray: 0, alpha: 1))
        grayContext.fill(CGRect(origin: .zero, size: entry.imageSize))
        grayContext.setFillColor(CGColor(gray: 1, alpha: 1))

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

        if entry.charCode == "A" && ProcessInfo.processInfo.arguments.contains("--osm-font-debug") {
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
                    try? AppleImageUtilities.pngData(img)?.write(to: url)
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

    private func compareAtlases(generated: CGImage, reference: CGImage, name: String) -> String {
        let w = min(generated.width, reference.width)
        let h = min(generated.height, reference.height)
        let sizeInfo =
            "generated(\(generated.width)x\(generated.height)) vs ref(\(reference.width)x\(reference.height))"
        guard w > 0, h > 0 else { return "size mismatch \(sizeInfo)" }

        let bytesPerPixel = 4
        let bytesPerRow = w * bytesPerPixel
        var diffCount = 0
        var totalDiff: Double = 0
        var flippedDiffCount = 0
        var flippedTotalDiff: Double = 0

        guard let genData = generated.dataProvider?.data as Data?,
            let refData = reference.dataProvider?.data as Data?,
            genData.count >= h * bytesPerRow,
            refData.count >= h * bytesPerRow
        else { return "could not read pixel data" }

        let genBytes = [UInt8](genData)
        let refBytes = [UInt8](refData)

        for y in 0..<h {
            for x in 0..<w {
                let idx = y * bytesPerRow + x * bytesPerPixel
                let a = abs(Int(genBytes[idx]) - Int(refBytes[idx]))
                let r = abs(Int(genBytes[idx + 1]) - Int(refBytes[idx + 1]))
                let g = abs(Int(genBytes[idx + 2]) - Int(refBytes[idx + 2]))
                let b = abs(Int(genBytes[idx + 3]) - Int(refBytes[idx + 3]))
                let channelDiff = a + r + g + b
                if channelDiff > 4 {
                    diffCount += 1
                }
                totalDiff += Double(channelDiff)

                let flippedY = h - 1 - y
                let fIdx = flippedY * bytesPerRow + x * bytesPerPixel
                let fa = abs(Int(genBytes[idx]) - Int(refBytes[fIdx]))
                let fr = abs(Int(genBytes[idx + 1]) - Int(refBytes[fIdx + 1]))
                let fg = abs(Int(genBytes[idx + 2]) - Int(refBytes[fIdx + 2]))
                let fb = abs(Int(genBytes[idx + 3]) - Int(refBytes[fIdx + 3]))
                let fChannelDiff = fa + fr + fg + fb
                if fChannelDiff > 4 {
                    flippedDiffCount += 1
                }
                flippedTotalDiff += Double(fChannelDiff)
            }
        }

        let totalPixels = w * h
        let avgDiff = totalDiff / Double(totalPixels * 4)
        let flippedAvgDiff = flippedTotalDiff / Double(totalPixels * 4)
        let orientation = avgDiff < flippedAvgDiff ? "upright" : "flipped"
        return
            "\(sizeInfo) diffPixels=\(diffCount)/\(totalPixels) avgDiff=\(String(format: "%.2f", avgDiff)) vs flipped avgDiff=\(String(format: "%.2f", flippedAvgDiff)) likelyOrientation=\(orientation)"
    }
}
