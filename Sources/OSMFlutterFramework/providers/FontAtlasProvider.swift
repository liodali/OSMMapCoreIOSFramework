//
//  FontAtlasProvider.swift
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

protocol FontAtlasProvider {
    func loadAtlas(forName name: String) -> FontAtlas?
}

class FontAtlas {
    let texture: TextureHolder
    let fontData: MCFontData
    init(texture: TextureHolder, fontData: MCFontData) {
        self.texture = texture
        self.fontData = fontData
    }
}

enum FontResourceBundle {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
            return Bundle.module
        #else
            return Bundle(for: FontAtlas.self)
        #endif
    }
}
