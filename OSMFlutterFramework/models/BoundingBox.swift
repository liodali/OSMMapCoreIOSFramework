//
//  BoundingBox.swift
//  OSMMapCoreIOS
//
//  Created by Dali Hamza on 22.11.23.
//

import Foundation
import MapKit
@_implementationOnly import MapCore


public class BoundingBox: Equatable {
   
    public let north:Double
    public let west:Double
    public let east:Double
    public let south:Double
    
    public  init(north: Double = 85.0, west: Double = -180.0, east: Double = 180.0, south: Double = -85.0) {
        self.north = north
        self.west = west
        self.east = east
        self.south = south
    }
    public  init(boundingBoxs: [Double]) {
        self.north = boundingBoxs[0]
        self.west = boundingBoxs[3]
        self.east = boundingBoxs[1]
        self.south = boundingBoxs[2]
    }
    
    public static func == (lhs: BoundingBox, rhs: BoundingBox) -> Bool {
        lhs.north == rhs.north && lhs.south == rhs.south && lhs.east == rhs.east && lhs.west == rhs.west
    }
    
    func centerLatitude()-> Double {
        (north + south) / 2.0
    }
    func centerLongitude()-> Double {
      var lon =  (west + east) / 2.0
        if east < west {
            lon += 180.0
        }
        return min(max(lon,-180.0), 180.0)
    }
    
    public func center() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude(), longitude: centerLongitude())
    }
   
}
extension BoundingBox {
    public func isWorld() -> Bool {
        north == 85.0 && west ==  -180.0 && east == 180.0 && south == -85.0
    }
    public func toLLocations()-> (topLeft: CLLocationCoordinate2D,bottomRight:CLLocationCoordinate2D){
        return (topLeft: CLLocationCoordinate2D(latitude:north,longitude:east),
                bottomRight: CLLocationCoordinate2D(latitude:south,longitude:west))
    }
    public func toBoundingEpsg3857() -> BoundingBox {
         if isWorld() {
             return BoundingBox(north: -20037508.34,west: 20037508.34,
                                east: -20037508.34, south: 20037508.34)
         }
        let locationTopLeft = CLLocationCoordinate2D(latitude: north, longitude: east)
        let nlocationTopLeft = locationTopLeft.toMCCoordEpsg3857()
        let locationBottomRight = CLLocationCoordinate2D(latitude: south, longitude: west)
        let nlocationBottomRight = locationBottomRight.toMCCoordEpsg3857()
            
        let nBoundingBox =  BoundingBox(north: nlocationTopLeft.x,west: nlocationTopLeft.y,
                                        east: nlocationBottomRight.y, south: nlocationBottomRight.x)
        return nBoundingBox
    }
     func toMCRectCoord() -> MCRectCoord {
        let identifer = MCCoordinateSystemIdentifiers.epsg3857()
        if isWorld() {
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
        let boundingEspg3857 = toBoundingEpsg3857()
        let topLeft = MCCoord(systemIdentifier: identifer,
                              x: boundingEspg3857.north,
                              y: boundingEspg3857.west, z: 10.0)
       let bottomRight = MCCoord(systemIdentifier: identifer,
                                x: boundingEspg3857.south,
                                y: boundingEspg3857.east, z: 10.0)
    
        return MCRectCoord(
            topLeft: topLeft,
            bottomRight: bottomRight)
    }
    public func toMap() -> [String:Double] {
        ["north":north,"south":south,"east":east,"west":west]
    }
}
