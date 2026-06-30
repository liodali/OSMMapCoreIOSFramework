//
//  SystemFontLoader.swift
//  OSMFlutterFramework
//
//  Copyright © 2026 Dali Hamza. All rights reserved.
//

import Foundation

#if compiler(>=5.10)
    /* private */ internal import MapCore
#else
    @_implementationOnly import MapCore
#endif

class SystemFontLoader: NSObject, @unchecked Sendable, MCFontLoaderInterface {
    private let providers: [FontAtlasProvider]
    private let cache = NSCache<NSString, FontAtlas>()
    private let cacheLock = NSLock()

    init(providers: [FontAtlasProvider]) {
        self.providers = providers
        super.init()
        cache.countLimit = 8
    }

    override convenience init() {
        self.init(providers: [MSDFAtlasProvider()])
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

        // Try each provider with the exact font name.
        for provider in providers {
            if let atlas = provider.loadAtlas(forName: name) {
                print("SystemFontLoader: loaded '\(name)' via \(type(of: provider))")
                return cacheAndReturn(atlas, forKey: name)
            }
        }

        // Fallback: map unknown font names to the closest Noto Sans variant.
        let fallbackName = Self.notoSansFallbackName(for: name)
        if fallbackName != name {
            for provider in providers {
                if let atlas = provider.loadAtlas(forName: fallbackName) {
                    print(
                        "SystemFontLoader: using Noto Sans fallback '\(fallbackName)' for '\(name)'"
                    )
                    return cacheAndReturn(atlas, forKey: name)
                }
            }
        }

        return MCFontLoaderResult(imageData: nil, fontData: nil, status: .ERROR_OTHER)
    }

    private func cacheAndReturn(_ atlas: FontAtlas, forKey name: String) -> MCFontLoaderResult {
        cacheLock.lock()
        cache.setObject(atlas, forKey: name as NSString)
        cacheLock.unlock()
        return MCFontLoaderResult(
            imageData: atlas.texture, fontData: atlas.fontData, status: .OK)
    }

    private static func notoSansFallbackName(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("bold") {
            return "Noto Sans Bold"
        } else if lowercased.contains("italic") {
            return "Noto Sans Italic"
        } else {
            return "Noto Sans Regular"
        }
    }
}
