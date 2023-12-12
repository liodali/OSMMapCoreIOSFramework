//
//  OSMMarker.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 04.12.23.
//

import Foundation
import MapKit
@_implementationOnly import MapCore


public typealias MarkerIconSize = (x:Int,y:Int)

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
    private(set) var iconLayerInterface:MCIconLayerInterface? = nil
    public init(location: CLLocationCoordinate2D,markerConfiguration:MarkerConfiguration) {
        self.id = location.id()
        self.location = location
        self.markerConfiguration = markerConfiguration
    }
    
    public static func == (lhs: Marker, rhs: Marker) -> Bool {
        lhs.location == rhs.location
    }
}
public struct MarkerConfiguration{

    let angle:Float?
    let icon:UIImage
    let iconSize:MarkerIconSize?
    let anchor:(x:Int,y:Int)?
    let scaleType:MarkerScaleType
    init(icon:UIImage,iconSize:MarkerIconSize? = nil,angle: Float?, anchor: (x: Int, y: Int)?,scaleType:MarkerScaleType = MarkerScaleType.Scale) {
        self.icon = icon
        self.angle = angle
        self.anchor = anchor
        self.iconSize = iconSize
        self.scaleType = scaleType
    }
    func copyWith(icon:UIImage?,iconSize:MarkerIconSize? = nil,angle: Float?, anchor: (x: Int, y: Int)?,scaleType:MarkerScaleType? = nil)-> MarkerConfiguration {
        MarkerConfiguration(icon: icon ?? self.icon,iconSize: iconSize ?? self.iconSize,
                            angle: angle ?? self.angle, anchor: anchor ?? self.anchor,scaleType: scaleType ?? self.scaleType)
    }
}
extension Marker {
    mutating func setLayer(iconLayerInterface:MCIconLayerInterface) {
        self.iconLayerInterface = iconLayerInterface
    }
    mutating func updateLayerMarker(iconLayerInterface:MCIconLayerInterface) {
        self.iconLayerInterface = iconLayerInterface
    }
    mutating func updateMarker(newLocation:CLLocationCoordinate2D,configuration: MarkerConfiguration?) {
        if let config = configuration {
            self.markerConfiguration = config
        }
        self.location = newLocation
        let nIconLayerInterface = createMapIcon(sizeIcon: configuration?.iconSize)
        let iconInterface = self.iconLayerInterface?.getIcons().first
        self.iconLayerInterface?.remove(iconInterface)
        self.iconLayerInterface?.add(nIconLayerInterface)
        
    }
    mutating func updateIconMarker(configuration: MarkerConfiguration) {
        self.markerConfiguration = configuration
        let nIconLayerInterface = createMapIcon()
        let iconInterface = self.iconLayerInterface?.getIcons().first
        self.iconLayerInterface?.remove(iconInterface)
        self.iconLayerInterface?.add(nIconLayerInterface)
    }
    
    func createMapIcon(sizeIcon:(x:Int,y:Int)? = nil)-> MCIconInfoInterface? {
        let texture = markerConfiguration.icon.toTexture(angle: markerConfiguration.angle!)
        let iconSize = MCVec2F(x:Float(sizeIcon?.x ?? Int(texture.getImageWidth())),y:Float(sizeIcon?.y ?? Int(texture.getImageHeight())))
        let location = self.location.toMCCoordEpsg3857()
        if markerConfiguration.anchor != nil {
           return MCIconFactory.createIcon(withAnchor: id,
                                     coordinate: location,
                                     texture: texture,
                                     iconSize: iconSize,
                                           scale: MCIconType.SCALE_INVARIANT,
                                           iconAnchor: MCVec2F(x: Float(markerConfiguration.anchor!.x), y: Float(markerConfiguration.anchor!.y)))
        }
        return  MCIconFactory.createIcon(id,
                                 coordinate: location,
                                 texture: texture,
                                 iconSize: iconSize,
                                         scale: MCIconType.FIXED)
    }
}
