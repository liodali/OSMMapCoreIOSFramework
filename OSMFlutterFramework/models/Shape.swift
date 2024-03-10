//
//  Shape.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 13.01.24.
//

import Foundation
import MapKit
@_implementationOnly import MapCore


public protocol PShape {
    var center: CLLocationCoordinate2D { get }
    var distanceInMeter: Double { get  }
    var style:ShapeStyleConfiguration { get  }
}
protocol Shape:PShape {
    func createShape(id:String,hasBorder:Bool) -> MCPolygonInfo
    func createBorderShape(id:String)->MCLineInfoInterface?
}
public class CircleOSM:Shape{
    public var center: CLLocationCoordinate2D
    public var distanceInMeter: Double
    public var style: ShapeStyleConfiguration
    public init(center: CLLocationCoordinate2D, distanceInMeter: Double,style: ShapeStyleConfiguration) {
        self.center = center
        self.distanceInMeter = distanceInMeter
        self.style = style
    }
    func createShape(id:String,hasBorder:Bool = false)->MCPolygonInfo{
        let polyCoords = toCoordShape(
            lengthInMeters: distanceInMeter
        ).toMCPolygonCoord()
      
        return  MCPolygonInfo(identifier: id,
                         coordinates: polyCoords,
                         color:  style.filledColor.mapCoreColor,
                         highlight:  style.filledColor.mapCoreColor
         )
    }

}
extension CircleOSM {
    func toCoordShape(lengthInMeters:Double) -> [CLLocationCoordinate2D] {
        var points = [CLLocationCoordinate2D]()
        let angles =  Array(stride(from: 6, to: 366, by: 6))
        for _angle in angles {
            let onCircle = center.destinationPoint(distanceInMeter: lengthInMeters, bearingInDegree: Double(_angle))
            points.append(onCircle)
        }
        return points
    }
    func createBorderShape(id:String)->MCLineInfoInterface?{
        var borders = toCoordShape(
            lengthInMeters:  distanceInMeter + (style.borderWidth / 2)
        )
        borders.append(borders.first!)
        let bordersMCCoords = borders.map { coord in
            coord.toMCCoordEpsg3857()
        }
        return MCLineFactory.createLine("\(id)-border",
                                        coordinates: bordersMCCoords,
                                        style: MCLineStyle(
                                            color: MCColorStateList(normal: style.borderColor.mapCoreColor,
                                            highlighted: style.borderColor.mapCoreColor),
                                            gapColor: MCColorStateList(normal: style.borderColor.mapCoreColor,
                                            highlighted: style.borderColor.mapCoreColor),
                                            opacity: 1.0,
                                            blur: 0,
                                            widthType: .SCREEN_PIXEL,
                                           width:  Float(style.borderWidth),
                                            dashArray: [1,1],
                                            lineCap: MCLineCapType.ROUND,
                                            offset: Float(0),
                                            dotted: false,
                                            dottedSkew: Float(0)
                                        )
                )
    }
}
/**
  * This class used to configure Rect shape and draw MCPolygonInfo In MapCore
    using [createShape] method that called in ShapeManager
 */
public class RectShapeOSM:Shape {
    public  var center: CLLocationCoordinate2D
    public  var distanceInMeter: Double
    public  var style: ShapeStyleConfiguration
    public init(center: CLLocationCoordinate2D, distanceInMeter: Double,style: ShapeStyleConfiguration) {
        self.center = center
        self.distanceInMeter = distanceInMeter
        self.style = style
    }
    public  init(boundingBpox: BoundingBox,style: ShapeStyleConfiguration) {
        self.center = boundingBpox.center()
        self.distanceInMeter = center.distance(other: boundingBpox.toLLocations().topLeft)
        self.style = style
    }
    
    func createShape(id:String,hasBorder:Bool = false)->MCPolygonInfo{
      
        let polyCoords = toCoordShape(
            lengthInMeters: distanceInMeter,
            widthInMeters: distanceInMeter
        ).toMCPolygonCoord()
 
        return  MCPolygonInfo(identifier: id,
                         coordinates: polyCoords,
                              color: style.filledColor.mapCoreColor,
                              highlight: style.filledColor.mapCoreColor)
    }
    func createBorderShape(id:String)->MCLineInfoInterface?{
        var borders = toCoordShape(
            lengthInMeters:  distanceInMeter + (style.borderWidth / 2),
            widthInMeters:  distanceInMeter + (style.borderWidth / 2)
        )
        borders.append(borders.first!)
        let bordersMCCoords = borders.map { coord in
            coord.toMCCoordEpsg3857()
        }
        return MCLineFactory.createLine("\(id)-border",
                                        coordinates: bordersMCCoords,
                                        style: MCLineStyle(
                                            color: MCColorStateList(normal: style.borderColor.mapCoreColor,
                                            highlighted: style.borderColor.mapCoreColor),
                                            gapColor: MCColorStateList(normal: style.borderColor.mapCoreColor,
                                            highlighted: style.borderColor.mapCoreColor),
                                            opacity: 1.0,
                                            blur: 0,
                                            widthType: .SCREEN_PIXEL,
                                            width:  Float(style.borderWidth),
                                            dashArray: [1,1],
                                            lineCap: MCLineCapType.ROUND,
                                            offset: Float(0),
                                            dotted: false,
                                            dottedSkew: Float(0)
                                        )
                )
    }
}
extension RectShapeOSM {
    func toCoordShape(lengthInMeters: Double, widthInMeters: Double) -> [CLLocationCoordinate2D] {
       var points = [CLLocationCoordinate2D]()
       let east = center.destinationPoint(distanceInMeter: lengthInMeters, bearingInDegree: 90.0)
        let south = center.destinationPoint(distanceInMeter: widthInMeters, bearingInDegree: 180.0)
        let westLon = center.longitude * 2 - east.longitude
        let northLat = center.latitude * 2 - south.latitude
        points.append(CLLocationCoordinate2D(latitude: south.latitude, longitude: east.longitude))
        points.append(CLLocationCoordinate2D(latitude: south.latitude, longitude: westLon))
        points.append(CLLocationCoordinate2D(latitude: northLat, longitude: westLon))
        points.append(CLLocationCoordinate2D(latitude: northLat, longitude: east.longitude))
       return points
   }
    
    
}
extension Array where Element==CLLocationCoordinate2D {
    func toMCPolygonCoord()->MCPolygonCoord{
        let coords = self.map { cllocation in
            cllocation.toMCCoordEpsg3857()
        }
        return MCPolygonCoord(positions: coords, holes: [])
       
    }
}
