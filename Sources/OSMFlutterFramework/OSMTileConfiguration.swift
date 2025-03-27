//
//  OSMTileConfiguration.swift
//  OSMMapCoreIOS
//
//  Created by Dali Hamza on 22.11.23.
//

import Foundation
#if compiler(>=5.10)
/* private */ internal import MapCore
#else
@_implementationOnly import MapCore
#endif

public struct OSMMapConfiguration {
    let zoomLevelScaleFactor:Double
    let numDrawPreviousLayers:Int
    let adaptScaleToScreen:Bool
    public init(zoomLevelScaleFactor: Double = 0.65, numDrawPreviousLayers: Int = 1, adaptScaleToScreen: Bool = true) {
        self.zoomLevelScaleFactor = zoomLevelScaleFactor
        self.numDrawPreviousLayers = numDrawPreviousLayers
        self.adaptScaleToScreen = adaptScaleToScreen
    }
}
class OSMTiledLayerConfig: MCTiled2dMapLayerConfig {
    func getVirtualZoomLevelInfos() -> [MCTiled2dMapZoomLevelInfo] {
        return []
    }
    
   
    private var tile:String
    let configuration:OSMMapConfiguration
     
    init(tileURL:String="https://a.tile.openstreetmap.de/{z}/{x}/{y}.png",configuration:OSMMapConfiguration = OSMMapConfiguration()) {
        tile = tileURL
        self.configuration = configuration
    }
    
    public func setTileURL(tileURL:String){
        tile = tileURL
    }
    
    /*func getCoordinateSystemIdentifier() -> String {
        MCCoordinateSystemIdentifiers.epsg3857()
    }*/
    
    func getTileUrl(_ x: Int32, y: Int32, t: Int32, zoom: Int32) -> String {
        let nTile = tile.replacingOccurrences(of: "{z}", with: "\(zoom)")
            .replacingOccurrences(of: "{y}", with: "\(y)")
            .replacingOccurrences(of: "{x}", with: "\(x)")
        print("url: \(nTile)")
        return nTile
    }
    
    func getVectorSettings() -> MCTiled2dMapVectorSettings? {
        nil
    }
    
    func getExtent() -> [NSNumber]? {
        []
    }
    func getCoordinateSystemIdentifier() -> Int32 {
        MCCoordinateSystemIdentifiers.epsg3857()
    }
    
   
    
  
    // Defines both an additional scale factor for the tiles (and if they are scaled
    // to match the target devices screen density), how many layers above the ideal
    // one should be loaded an displayed as well, as well as if the layer is drawn,
    // when the zoom is smaller/larger than the valid range
    func getZoomInfo() -> MCTiled2dMapZoomInfo {
        MCTiled2dMapZoomInfo(zoomLevelScaleFactor: Float(configuration.zoomLevelScaleFactor),
                             numDrawPreviousLayers: Int32(configuration.numDrawPreviousLayers), numDrawPreviousOrLaterTLayers: Int32(configuration.numDrawPreviousLayers),
                             adaptScaleToScreen: configuration.adaptScaleToScreen,
                           maskTile: true,
                           underzoom: true,
                           overzoom: true
      )
    }



    func getBounds() -> MCRectCoord? {
        // Defines the bounds of the layer
        let identifer = MCCoordinateSystemIdentifiers.epsg3857()
        let topLeft = MCCoord(systemIdentifier: identifer,
                                       x: -20037508.34,
                                       y: 20037508.34, z: 0.0)
        let bottomRight = MCCoord(systemIdentifier: identifer,
                                           x: 20037508.34,
                                           y: -20037508.34, z: 0.0)
        return MCRectCoord(
                   topLeft: topLeft,
                   bottomRight: bottomRight)
        
    }

    // The Layername
    func getLayerName() -> String {
        "OSM Layer"
    }

    // List of valid zoom-levels and their target zoom-value, the tile size in
    // the layers coordinate system, the number of tiles on that level and the
    // zoom identifier used for the tile-url (see getTileUrl above) 21536.731457737689
    func getZoomLevelInfos() -> [MCTiled2dMapZoomLevelInfo] {
        let zoomLevels:[MCTiled2dMapZoomLevelInfo] =  [
            .init(zoom: 559082264.029, tileWidthLayerSystemUnits: 40_075_016, numTilesX: 1, numTilesY: 1, numTilesT: 1, zoomLevelIdentifier: 0, bounds: getBounds()!),
            .init(zoom: 279541132.015, tileWidthLayerSystemUnits: 20_037_508, numTilesX: 2, numTilesY: 2, numTilesT: 1, zoomLevelIdentifier: 1, bounds: getBounds()!),
            .init(zoom: 139770566.007, tileWidthLayerSystemUnits: 10_018_754, numTilesX: 4, numTilesY: 4, numTilesT: 1, zoomLevelIdentifier: 2, bounds: getBounds()!),
            .init(zoom: 69885283.0036, tileWidthLayerSystemUnits: 5_009_377.1, numTilesX: 8, numTilesY: 8, numTilesT: 1, zoomLevelIdentifier: 3, bounds: getBounds()!),
            .init(zoom: 34942641.5018, tileWidthLayerSystemUnits: 2_504_688.5, numTilesX: 16, numTilesY: 16, numTilesT: 1, zoomLevelIdentifier: 4, bounds: getBounds()!),
            .init(zoom: 17471320.7509, tileWidthLayerSystemUnits: 1_252_344.3, numTilesX: 32, numTilesY: 32, numTilesT: 1, zoomLevelIdentifier: 5, bounds: getBounds()!),
            .init(zoom: 8735660.37545, tileWidthLayerSystemUnits: 626_172.1, numTilesX: 64, numTilesY: 64, numTilesT: 1, zoomLevelIdentifier: 6, bounds: getBounds()!),
            .init(zoom: 4367830.18773, tileWidthLayerSystemUnits: 313_086.1, numTilesX: 128, numTilesY: 128, numTilesT: 1, zoomLevelIdentifier: 7, bounds: getBounds()!),
            .init(zoom: 2183915.09386, tileWidthLayerSystemUnits: 156_543, numTilesX: 256, numTilesY: 256, numTilesT: 1, zoomLevelIdentifier: 8, bounds: getBounds()!),
            .init(zoom: 1091957.54693, tileWidthLayerSystemUnits: 78271.5, numTilesX: 512, numTilesY: 512, numTilesT: 1, zoomLevelIdentifier: 9, bounds: getBounds()!),
            .init(zoom: 545978.773466, tileWidthLayerSystemUnits: 39135.8, numTilesX: 1024, numTilesY: 1024, numTilesT: 1, zoomLevelIdentifier: 10, bounds: getBounds()!),
            .init(zoom: 272989.386733, tileWidthLayerSystemUnits: 19567.9, numTilesX: 2048, numTilesY: 2048, numTilesT: 1, zoomLevelIdentifier: 11, bounds: getBounds()!),
            .init(zoom: 136494.693366, tileWidthLayerSystemUnits: 9783.94, numTilesX: 4096, numTilesY: 4096, numTilesT: 1, zoomLevelIdentifier: 12, bounds: getBounds()!),
            .init(zoom: 68247.3466832, tileWidthLayerSystemUnits: 4891.97, numTilesX: 8192, numTilesY: 8192, numTilesT: 1, zoomLevelIdentifier: 13, bounds: getBounds()!),
            .init(zoom: 34123.6733416, tileWidthLayerSystemUnits: 2445.98, numTilesX: 16384, numTilesY: 16384, numTilesT: 1, zoomLevelIdentifier: 14, bounds: getBounds()!),
            .init(zoom: 17061.8366708, tileWidthLayerSystemUnits: 1222.99, numTilesX: 32768, numTilesY: 32768, numTilesT: 1, zoomLevelIdentifier: 15, bounds: getBounds()!),
            .init(zoom: 8530.91833540, tileWidthLayerSystemUnits: 611.496, numTilesX: 65536, numTilesY: 65536, numTilesT: 1, zoomLevelIdentifier: 16, bounds: getBounds()!),
            .init(zoom: 4265.45916770, tileWidthLayerSystemUnits: 305.748, numTilesX: 131_072, numTilesY: 131_072, numTilesT: 1, zoomLevelIdentifier: 17, bounds: getBounds()!),
            .init(zoom: 2132.72958385, tileWidthLayerSystemUnits: 152.874, numTilesX: 262_144, numTilesY: 262_144, numTilesT: 1, zoomLevelIdentifier: 18, bounds: getBounds()!),
            .init(zoom: 1066.36479193, tileWidthLayerSystemUnits: 76.437, numTilesX: 524_288, numTilesY: 524_288, numTilesT: 1, zoomLevelIdentifier: 19, bounds: getBounds()!),
            /*.init(zoom: 533.18239597, tileWidthLayerSystemUnits: 38.2185, numTilesX: 1_048_576, numTilesY: 1_048_576, numTilesT: 1, zoomLevelIdentifier: 20, bounds: getBounds()!),*/
        ]
        
        return Array(zoomLevels[0..<20])
    }
}
extension OSMTiledLayerConfig {
    func getZoomIdentifierFromZoom(zoom:Double) -> Int? {
        print(zoom)
       var listZooms = getZoomLevelInfos()
        listZooms.sort { lvl1,lvl2 in
            lvl1.zoomLevelIdentifier < lvl2.zoomLevelIdentifier
        }
        let listdentifierZoom = listZooms
            .filter { level in
                return zoom >= level.zoom
        }.map { level in
                level.zoomLevelIdentifier
            }
        
        let identifierZoom = listdentifierZoom.min()
        if identifierZoom != nil {
            return Int(identifierZoom!)
        }
        return nil // Int32(zoomConfiguration.maxZoom)
        
    }
}
