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
    public init(initZoom:Int = 0,minZoom:Int = 0,maxZoom:Int = 19) {
        self.initZoom = initZoom
        self.minZoom  = minZoom
        self.maxZoom  = maxZoom
    }
}
