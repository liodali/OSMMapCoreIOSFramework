//
//  zoomModel.swift
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

public struct ZoomConfiguration {
    public  let initZoom:Int
    public  let minZoom:Int
    public  let maxZoom:Int
    public  let step:Int
    public init(initZoom:Int = 0,minZoom:Int = 0,maxZoom:Int = 19,step:Int = 1) {
        assert(maxZoom <= 19,"maximum zoom should not be greater than 19")
        self.initZoom = initZoom
        self.minZoom  = minZoom
        self.maxZoom  = maxZoom
        self.step  = step
    }
    public init(_ map:[String:Int]) {
        self.initZoom = map["initZoom"] ?? 2
        self.minZoom  = map["minZoom"] ?? 2
        self.maxZoom  = map["maxZoom"] ?? 19
        self.step  = map["stepZoom"] ?? 1
    }
    func toMCTileZoomConfiguration(mcTilesZooms:[MCTiled2dMapZoomLevelInfo])->MCTileZoomConfiguration{
      return  MCTileZoomConfiguration(initZoom: mcTilesZooms[initZoom], minZoom: mcTilesZooms[minZoom], maxZoom: mcTilesZooms[maxZoom-1])
    }
    
}
struct MCTileZoomConfiguration {
    public let initZoom:MCTiled2dMapZoomLevelInfo
    public let minZoom:MCTiled2dMapZoomLevelInfo
    public let maxZoom:MCTiled2dMapZoomLevelInfo
    public init(initZoom:MCTiled2dMapZoomLevelInfo,
                minZoom:MCTiled2dMapZoomLevelInfo ,
                maxZoom:MCTiled2dMapZoomLevelInfo) {
        self.initZoom = initZoom
        self.minZoom  = minZoom
        self.maxZoom  = maxZoom
    }
   
}

