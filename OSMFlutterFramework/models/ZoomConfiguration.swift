//
//  zoomModel.swift
//  OSMMapCoreIOS
//
//  Created by Dali Hamza on 22.11.23.
//

import Foundation

public struct ZoomConfiguration {
    public  let initZoom:Int
    public  let minZoom:Int
    public  let maxZoom:Int
    public  let step:Int
    public init(initZoom:Int = 0,minZoom:Int = 0,maxZoom:Int = 19,step:Int = 1) {
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
}
