//
//  MSDFAtlasProvider.swift
//  OSMFlutterFramework
//
//  Copyright © 2026 Dali Hamza. All rights reserved.
//

import Foundation
import UIKit

#if compiler(>=5.10)
    /* private */ internal import MapCore
#else
    @_implementationOnly import MapCore
#endif

/// Loads pre-generated MSDF font atlases (BMFont JSON + PNG) from the resource bundle.
/// No dependency on CoreText, UIFont, or runtime SDF generation.
class MSDFAtlasProvider: FontAtlasProvider {

    private let psMapping: [String: String] = [
        "Noto Sans Regular": "NotoSans-Regular",
        "Noto Sans Italic": "NotoSans-Italic",
        "Noto Sans Bold": "NotoSans-Bold",
    ]

    init() {}

    func loadAtlas(forName name: String) -> FontAtlas? {
        let candidates = [
            name.replacingOccurrences(of: " ", with: "_"),
            psMapping[name],
        ].compactMap { $0 }

        var jsonURL: URL?
        var pngURL: URL?
        for candidate in candidates {
            if jsonURL == nil {
                jsonURL = FontResourceBundle.bundle.url(forResource: candidate, withExtension: "json")
            }
            if pngURL == nil {
                pngURL = FontResourceBundle.bundle.url(forResource: candidate, withExtension: "png")
            }
        }

        guard let jsonURL = jsonURL, let pngURL = pngURL else {
            return nil
        }

        guard let jsonData = try? Data(contentsOf: jsonURL),
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: AnyObject]
        else {
            print("MSDFAtlasProvider: failed to parse JSON for \(name)")
            return nil
        }

        guard let infoJson = json["info"] as? [String: AnyObject],
            let commonJson = json["common"] as? [String: AnyObject],
            let distanceFieldJson = json["distanceField"] as? [String: AnyObject],
            let charsJson = json["chars"] as? [NSDictionary]
        else {
            print("MSDFAtlasProvider: invalid BMFont JSON structure for \(name)")
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

        guard let image = UIImage(contentsOfFile: pngURL.path),
            let cgImage = image.cgImage,
            let textureHolder = try? TextureHolder(cgImage)
        else {
            print("MSDFAtlasProvider: failed to load atlas PNG for \(name)")
            return nil
        }

        let fontData = MCFontData(info: fontInfo, glyphs: glyphs)
        print(
            "MSDFAtlasProvider: loaded MSDF atlas for \(name) (\(glyphs.count) glyphs, \(Int(imageSize))x\(Int(imageSize)))"
        )
        return FontAtlas(texture: textureHolder, fontData: fontData)
    }
}
