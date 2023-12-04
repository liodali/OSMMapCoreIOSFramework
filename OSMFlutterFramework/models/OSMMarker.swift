//
//  OSMMarker.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 04.12.23.
//

import Foundation
import MapKit
@_implementationOnly import MapCore
public struct Marker : Equatable{

    let id:String
    private(set) var location:CLLocationCoordinate2D
    private(set) var icon:UIImage
    private(set) var angle:Float
    private(set) var anchor:(x:Int,y:Int)?
    
    private(set) var iconLayerInterface:MCIconLayerInterface? = nil
    init(location: CLLocationCoordinate2D,icon:UIImage, angle: Float = 0, anchor: (x: Int, y: Int)?) {
        self.id = location.id()
        self.location = location
        self.icon = icon
        self.angle = angle
        self.anchor = anchor
    }
    
    public static func == (lhs: Marker, rhs: Marker) -> Bool {
        lhs.location == rhs.location
    }
}
public struct MarkerConfiguration{

    let angle:Float?
    let icon:UIImage?
    let anchor:(x:Int,y:Int)?
    
    private var iconLayerInterface:MCIconLayerInterface? = nil
    init(icon:UIImage?,angle: Float?, anchor: (x: Int, y: Int)?) {
        self.icon = icon
        self.angle = angle
        self.anchor = anchor
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
        if let icon = configuration?.icon {
            self.icon = icon
        }
        if let angle = configuration?.angle {
            self.angle = angle
        }
        if let anchor = configuration?.anchor {
            self.anchor = anchor
        }
        self.location = newLocation
        let nIconLayerInterface = createMapIcon()
        let iconInterface = self.iconLayerInterface?.getIcons().first
        self.iconLayerInterface?.remove(iconInterface)
        self.iconLayerInterface?.add(nIconLayerInterface)
        
    }
    mutating func updateIconMarker(configuration: MarkerConfiguration) {
        if let icon = configuration.icon {
            self.icon = icon
        }
        if let angle = configuration.angle {
            self.angle = angle
        }
        if let anchor = configuration.anchor {
            self.anchor = anchor
        }
        let nIconLayerInterface = createMapIcon()
        let iconInterface = self.iconLayerInterface?.getIcons().first
        self.iconLayerInterface?.remove(iconInterface)
        self.iconLayerInterface?.add(nIconLayerInterface)
    }
    
    func createMapIcon()-> MCIconInfoInterface? {
        let texture = icon.toTexture(angle: angle)
        let location = self.location.toMCCoordEpsg3857()
        if anchor != nil {
           return MCIconFactory.createIcon(withAnchor: id,
                                           coordinate: location,
                                    texture: texture,
                                     iconSize: .init(x: Float(texture.getImageWidth()), y: Float(texture.getImageHeight())),
                                           scale: MCIconType.FIXED, iconAnchor: MCVec2F(x: Float(anchor!.x), y: Float(anchor!.y)))
        }
        return  MCIconFactory.createIcon(id,
                                 coordinate: location,
                                 texture: texture,
                                 iconSize: .init(x: Float(texture.getImageWidth()), y: Float(texture.getImageHeight())),
                                         scale: MCIconType.FIXED)
    }
}
