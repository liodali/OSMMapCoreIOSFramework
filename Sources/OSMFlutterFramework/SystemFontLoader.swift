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

    private static var bundle: Bundle {
        #if SWIFT_PACKAGE
            return Bundle.module
        #else
            return Bundle(for: SystemFontLoader.self)
        #endif
    }

    init(
        fontMappings: [String: UIFont],
        charset: String,
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

        // First, try to load pre-generated MSDF atlas + JSON from the bundle.
        if let atlas = loadBundledMSDFAtlas(name: name) {
            print("SystemFontLoader: using pre-generated MSDF atlas for \(name)")
            cacheLock.lock()
            cache.setObject(atlas, forKey: name as NSString)
            cacheLock.unlock()
            return MCFontLoaderResult(
                imageData: atlas.texture, fontData: atlas.fontData, status: .OK)
        }

        // Fall back to runtime SDF generation.
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

    // MARK: - Pre-generated MSDF atlas loading (BMFont JSON + PNG)

    /// Attempts to load a pre-generated MSDF font atlas (PNG) and glyph data (JSON)
    /// from the Swift package resource bundle. The JSON format matches the output
    /// of msdf-bmfont and the format expected by MCFontLoader.
    private func loadBundledMSDFAtlas(name: String) -> FontAtlas? {
        // Try multiple naming conventions for the atlas files.
        let psMapping: [String: String] = [
            "Noto Sans Regular": "NotoSans-Regular",
            "Noto Sans Italic": "NotoSans-Italic",
            "Noto Sans Bold": "NotoSans-Bold",
        ]
        let candidates = [
            name.replacingOccurrences(of: " ", with: "_"),  // Noto_Sans_Regular
            psMapping[name],  // NotoSans-Regular
        ].compactMap { $0 }

        var jsonURL: URL?
        var pngURL: URL?
        for candidate in candidates {
            if jsonURL == nil {
                jsonURL = Self.bundle.url(forResource: candidate, withExtension: "json")
            }
            if pngURL == nil {
                pngURL = Self.bundle.url(forResource: candidate, withExtension: "png")
            }
        }

        guard let jsonURL = jsonURL, let pngURL = pngURL else {
            return nil
        }

        // Load and parse the JSON.
        guard let jsonData = try? Data(contentsOf: jsonURL),
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: AnyObject]
        else {
            print("SystemFontLoader: failed to parse JSON for \(name)")
            return nil
        }

        guard let infoJson = json["info"] as? [String: AnyObject],
            let commonJson = json["common"] as? [String: AnyObject],
            let distanceFieldJson = json["distanceField"] as? [String: AnyObject],
            let charsJson = json["chars"] as? [NSDictionary]
        else {
            print("SystemFontLoader: invalid BMFont JSON structure for \(name)")
            return nil
        }

        let size = (infoJson["size"] as? NSNumber)?.doubleValue ?? 0
        let imageSize = (commonJson["scaleW"] as? NSNumber)?.doubleValue ?? 0
        guard size > 0, imageSize > 0 else { return nil }

        let fontInfo = MCFontWrapper(
            name: name,
            lineHeight: ((commonJson["lineHeight"] as? NSNumber)?.doubleValue ?? 0) / size,
            base: ((commonJson["base"] as? NSNumber)?.doubleValue ?? 0) / size,
            bitmapSize: MCVec2D(x: imageSize, y: imageSize),
            size: size,
            distanceRange: (distanceFieldJson["distanceRange"] as? NSNumber)?.doubleValue ?? 0
        )

        var glyphs: [MCFontGlyph] = []
        for g in charsJson {
            var glyph: [String: AnyObject] = [:]
            for a in g { glyph[a.key as! String] = a.value as AnyObject }

            let character = (glyph["char"] as? String) ?? ""
            var s0 = (glyph["x"] as? NSNumber)?.doubleValue ?? 0
            var s1 = s0 + ((glyph["width"] as? NSNumber)?.doubleValue ?? 0)
            var t0 = (glyph["y"] as? NSNumber)?.doubleValue ?? 0
            var t1 = t0 + ((glyph["height"] as? NSNumber)?.doubleValue ?? 0)

            s0 /= imageSize
            s1 /= imageSize
            t0 /= imageSize
            t1 /= imageSize

            // BMFont convention: yoffset is from top, bearing.y is negated.
            let xoffset = (glyph["xoffset"] as? NSNumber)?.doubleValue ?? 0
            let yoffset = (glyph["yoffset"] as? NSNumber)?.doubleValue ?? 0
            let bearing = MCVec2D(x: xoffset / size, y: -yoffset / size)

            let uv = MCQuad2dD(
                topLeft: MCVec2D(x: s0, y: t1),
                topRight: MCVec2D(x: s1, y: t1),
                bottomRight: MCVec2D(x: s1, y: t0),
                bottomLeft: MCVec2D(x: s0, y: t0)
            )

            let advanceVal = (glyph["xadvance"] as? NSNumber)?.doubleValue ?? 0
            let widthVal = (glyph["width"] as? NSNumber)?.doubleValue ?? 0
            let heightVal = (glyph["height"] as? NSNumber)?.doubleValue ?? 0
            let glyphEntry = MCFontGlyph(
                charCode: character,
                advance: MCVec2D(x: advanceVal / size, y: 0.0),
                boundingBoxSize: MCVec2D(
                    x: widthVal / size,
                    y: heightVal / size
                ),
                bearing: bearing,
                uv: uv
            )
            glyphs.append(glyphEntry)
        }

        // Load the PNG atlas image.
        guard let image = UIImage(contentsOfFile: pngURL.path),
            let cgImage = image.cgImage,
            let textureHolder = try? TextureHolder(cgImage)
        else {
            print("SystemFontLoader: failed to load atlas PNG for \(name)")
            return nil
        }

        let fontData = MCFontData(info: fontInfo, glyphs: glyphs)
        print(
            "SystemFontLoader: loaded MSDF atlas for \(name) (\(glyphs.count) glyphs, \(Int(imageSize))x\(Int(imageSize)))"
        )
        return FontAtlas(texture: textureHolder, fontData: fontData)
    }

    static let defaultFontMappings: [String: UIFont] = [
        "Open Sans Regular": UIFont.systemFont(ofSize: 64),
        "Open Sans Bold": UIFont.boldSystemFont(ofSize: 64),
        "Open Sans Italic": UIFont.italicSystemFont(ofSize: 64),
        "Arial Unicode MS Regular": UIFont.systemFont(ofSize: 64),
        "Roboto Regular": UIFont.systemFont(ofSize: 64),
        "Roboto Bold": UIFont.boldSystemFont(ofSize: 64),
        "Roboto Italic": UIFont.italicSystemFont(ofSize: 64),
    ]

    private static nonisolated(unsafe) var registeredBundledFonts = Set<String>()
    private static nonisolated(unsafe) let bundledFontLock = NSLock()

    private static func loadBundledFont(ttfName: String, size: CGFloat) -> UIFont? {
        bundledFontLock.lock()
        let alreadyRegistered = registeredBundledFonts.contains(ttfName)
        if !alreadyRegistered {
            registeredBundledFonts.insert(ttfName)
        }
        bundledFontLock.unlock()
        guard
            let url = bundle.url(
                forResource: ttfName, withExtension: "ttf", subdirectory: nil)
        else {
            print("SystemFontLoader: \(ttfName).ttf not found in resource bundle")
            return nil
        }
        if !alreadyRegistered {
            var error: Unmanaged<CFError>?
            guard
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            else {
                if let error = error?.takeRetainedValue() {
                    print("SystemFontLoader: failed to register \(ttfName): \(error)")
                }
                return nil
            }
        }
        guard
            let dataProvider = CGDataProvider(url: url as CFURL),
            let cgFont = CGFont(dataProvider)
        else {
            print("SystemFontLoader: could not create CGFont from \(ttfName)")
            return nil
        }
        let psName = cgFont.postScriptName as? String ?? ttfName
        let ctFont = CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
        let descriptor = CTFontCopyFontDescriptor(ctFont)
        let uiFont = UIFont(descriptor: descriptor, size: size)
        print(
            "SystemFontLoader: loaded bundled \(ttfName) -> family=\(uiFont.familyName ?? "?") ps=\(psName) name=\(uiFont.fontName)"
        )
        return uiFont
    }

    static let defaultCharset: String = {
        let ascii = String(
            (0x21...0x7E).compactMap { UnicodeScalar($0) }.map { Character($0) })
        let latin1 = String(
            (0x00A1...0x00FF).compactMap { UnicodeScalar($0) }.map { Character($0) })
        // Greek letters visible in the reference atlas.
        let greek =
            "\u{03B1}\u{03B2}\u{0393}\u{03C0}\u{03A3}\u{03C3}\u{03BC}\u{03C4}\u{03A6}\u{0398}\u{03A9}\u{03B4}\u{03C6}\u{03B5}"
        // Symbols in the reference atlas that are outside Latin-1.
        let symbols = "\u{2022}\u{221E}\u{207F}"
        return ascii + latin1 + greek + symbols
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

        // Try to load the requested font from the bundled TTF resources.
        let ttfMapping: [String: String] = [
            "Noto Sans Regular": "NotoSans-Regular",
            "Noto Sans Italic": "NotoSans-Italic",
            "Noto Sans Bold": "NotoSans-Bold",
        ]
        for (styleName, ttfName) in ttfMapping {
            if lowercased == styleName.lowercased() {
                if let font = Self.loadBundledFont(ttfName: ttfName, size: size) {
                    return font
                }
                break
            }
        }

        // Try to load the requested font by its PostScript name.
        let postscriptNames = [
            "NotoSans-Regular", "NotoSans-RegularItalic", "NotoSans-Regular-Bold",
            "Noto Sans Regular", "NotoSans", "NotoSans-Regular",
        ]
        for psName in postscriptNames {
            if let font = UIFont(name: psName, size: size) {
                return font
            }
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

        // Match UIKit: origin top-left, y increasing downward. The Metal texture loader
        // preserves the CGImage row order, so drawing the glyph image upside-down here
        // lets the 2D text shader (which flips v) render the glyph right-side up.
        atlasContext.translateBy(x: 0, y: atlasSize.height)
        atlasContext.scaleBy(x: 1.0, y: -1.0)

        atlasContext.setFillColor(UIColor.black.cgColor)
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

        // Debug: save atlas image to Documents directory.
        // The raw PNG follows the Quartz/Metal row order used by the texture loader.
        let uiImage = UIImage(cgImage: atlasCGImage)
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = docs.appendingPathComponent(
                "font_atlas_\(name.replacingOccurrences(of: " ", with: "_")).png")
            if let pngData = uiImage.pngData() {
                try? pngData.write(to: url)
                print("DEBUG: Atlas saved to \(url.path)")
            }

            // Compare generated atlas against a reference atlas if present.
            if let correctImage = {
                let correctURL = docs.appendingPathComponent(
                    "font_atlas_\(name.replacingOccurrences(of: " ", with: "_"))_correct.png"
                )
                return FileManager.default.fileExists(atPath: correctURL.path)
                    ? UIImage(contentsOfFile: correctURL.path)?.cgImage
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

                // Compare against vertically flipped reference to detect orientation.
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
