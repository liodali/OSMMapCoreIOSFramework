//
//  OSMMarker.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 04.12.23.
//

import Foundation
import MapKit
//@_implementationOnly import MapCore
#if compiler(>=5.10)
/* private */ internal import MapCore
#else
@_implementationOnly import MapCore
#endif


public typealias MarkerIconSize = (x:Int, y:Int)
public typealias MarkerAnchor = (x:Double, y:Double)

public enum MarkerScaleType {
    case Scale
    case rotate
    case invariant
    case fixed
    func getValue() -> MCIconType {
           switch self {
               case .Scale:
                    return MCIconType.SCALE_INVARIANT
               case .rotate:
                    return MCIconType.ROTATION_INVARIANT
               case .invariant:
                    return MCIconType.INVARIANT
               case .fixed:
                    return MCIconType.FIXED
           }
       }
}
public struct Marker : Equatable{

    let id:String
    private(set) var location:CLLocationCoordinate2D
    private(set) var markerConfiguration:MarkerConfiguration
    private var mcIconIndex:Int? = nil
    private var mcIconInfoInterface:MCIconInfoInterface? = nil
    public init(location: CLLocationCoordinate2D,markerConfiguration:MarkerConfiguration) {
        self.id = location.id()
        self.location = location
        self.markerConfiguration = markerConfiguration
    }
    
    public static func == (lhs: Marker, rhs: Marker) -> Bool {
        lhs.location == rhs.location
    }
    func copy() -> Self {
            return Marker(location: self.location, markerConfiguration: self.markerConfiguration)
    }
}
/**
 this class used to configure Marker from icon,size icon,anchor, scaleType
 */
public struct MarkerConfiguration{

    let angle:Float?
    let icon:UIImage
    let iconSize:MarkerIconSize?
    let anchor:MarkerAnchor?
    let scaleType:MarkerScaleType
    public init(icon:UIImage,iconSize:MarkerIconSize?,angle: Float?, anchor: MarkerAnchor?,
                scaleType:MarkerScaleType = MarkerScaleType.Scale) {
        self.icon = icon
        self.angle = angle
        self.anchor = anchor
        self.iconSize = iconSize
        self.scaleType = scaleType
    }
    public func copyWith(icon:UIImage? = nil,
                  iconSize:MarkerIconSize? = nil,
                  angle: Float? = nil,
                  anchor: MarkerAnchor? = nil,
                  scaleType:MarkerScaleType? = nil) -> MarkerConfiguration {
        MarkerConfiguration(
            icon: icon ?? self.icon,
            iconSize: iconSize ?? self.iconSize,
            angle: angle ?? self.angle,
            anchor: anchor ?? self.anchor,
            scaleType: scaleType ?? self.scaleType)
    }
    func anchorToMCVec2F() -> MCVec2F {
        MCVec2F(
            x: Float(anchor?.x ?? 0),
            y: Float(anchor?.y ?? 0)
        )
    }
}
extension Marker {
    
    mutating func updateMarker(newLocation:CLLocationCoordinate2D?,configuration: MarkerConfiguration?) {
        if let config = configuration {
            self.markerConfiguration = config
        }
        if let nLocation = newLocation {
            self.location = nLocation
        }
       
    }
    func getIconInterface() -> MCIconInfoInterface? {
        self.mcIconInfoInterface
    }
    mutating func setIconInterface(iconInfoInterface:MCIconInfoInterface) {
        self.mcIconInfoInterface = iconInfoInterface
    }
    
    
    mutating func createMapIcon(mccoord:MCCoord? = nil)-> MCIconInfoInterface? {
        let texture = markerConfiguration.icon.toTexture(angle: markerConfiguration.angle ?? 0)
        let iconSize = if let iconSize = markerConfiguration.iconSize {
            MCVec2F(x:Float(iconSize.x),y:Float(iconSize.y))
        }else {
            MCVec2F(x: Float(texture.getImageWidth()), y: Float(texture.getImageHeight()))
        }
       // MCVec2F(x:Float(markerConfiguration.iconSize.x),y:Float(markerConfiguration.iconSize.y))
        let location = mccoord ?? self.location.mcCoord //.toMCCoordEpsg3857()
        mcIconInfoInterface = if markerConfiguration.anchor != nil {
            MCIconFactory.createIcon(
                withAnchor: id,
                coordinate: location,
                texture: texture,
                iconSize: iconSize,
                scale: markerConfiguration.scaleType.getValue(),
                blendMode: .NORMAL,
                iconAnchor: markerConfiguration.anchorToMCVec2F()
            )
        }else {
            MCIconFactory.createIcon(
                id,
                coordinate: location,
                texture: texture,
                iconSize: iconSize,
                scale: markerConfiguration.scaleType.getValue(),
                blendMode: .NORMAL
            )
        }
        return mcIconInfoInterface
    }
}
