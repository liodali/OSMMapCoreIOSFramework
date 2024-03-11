//
//  PoisManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 13.12.23.
//

import Foundation
@_implementationOnly import MapCore
import MapKit
public class PoisManager {
    
    let map: MCMapView
    var pois: [String:Poi] = [:]
    
    private let markerHandler:IconLayerHander
    init(map: MCMapView) {
        self.map = map
        markerHandler = IconLayerHander(nil)
    }
    func updateHandler(locationHandlerDelegate:MapMarkerHandler?){
        if let nhandler = locationHandlerDelegate {
            markerHandler.setHandler(markerHandler: nhandler)
        }else {
            markerHandler.removeHandler()
        }
    }
    public func setOrCreateIconPoi(id:String,icon:UIImage,iconSize:MarkerIconSize?){
        if pois[id] != nil {
            pois[id]?.setIconMarker(icon: icon,size: iconSize)
        }else{
            pois[id] = Poi(id: id, icon: icon,iconSize: iconSize, markerPois: [],handler: markerHandler)
            self.map.add(layer: pois[id]?.mcIconLayer?.asLayerInterface())
        }
    }
    public func setMarkersPoi(id:String,markers:[MarkerIconPoi]){
        if pois[id] != nil {
            pois[id]?.setMarkers(markerPois: markers)
        }
    }
    public func clearMarkersPoi(id:String,markers:[MarkerIconPoi]){
        if pois[id] != nil {
            pois[id]?.setMarkers(markerPois: markers)
        }
    }
    public func hildeAll(){
        pois.forEach { id,poi in
            poi.mcIconLayer?.asLayerInterface()?.hide()
        }
        markerHandler.skipHandler = true
    }
    public func showAll(){
        pois.forEach { id,poi in
            poi.mcIconLayer?.asLayerInterface()?.show()
        }
        markerHandler.skipHandler = false
    }
    public func lockHandler(){
        markerHandler.skipHandler = !markerHandler.skipHandler
    }
    
}
struct Poi {
    let id:String
    var markerPois:[MarkerIconPoi] = []
    let mcIconLayer:MCIconLayerInterface?
    let markerIcon:(icon:UIImage,size:MarkerIconSize?)
    public init(id:String,icon:UIImage,iconSize:MarkerIconSize?,markerPois: [MarkerIconPoi],handler:IconLayerHander) {
        self.id = id
        self.markerIcon = (icon,iconSize)
        self.markerPois = markerPois
        self.mcIconLayer = MCIconLayerInterface.create()
        self.mcIconLayer?.setLayerClickable(true)
        self.mcIconLayer?.setCallbackHandler(handler)
    }
    
     mutating func setMarkers(markerPois: [MarkerIconPoi]) {
        mcIconLayer?.clear()
        self.markerPois.removeAll()
         let nMarkersPoi =  markerPois.map({
             let config = $0.configuration.copyWith(icon: markerIcon.icon,iconSize: markerIcon.size, angle: nil, anchor: nil)
             return MarkerIconPoi(configuration: config,location: $0.location)
         })
        self.markerPois.append(contentsOf: nMarkersPoi)
        let icons = self.markerPois.map { $0.icon! }
        mcIconLayer?.setIcons(icons)
        mcIconLayer?.invalidate()
    }
    mutating func clearMarkers() {
       mcIconLayer?.clear()
       self.markerPois.removeAll()
       mcIconLayer?.invalidate()
   }
     mutating func setIconMarker(icon: UIImage,size:MarkerIconSize?) {
        mcIconLayer?.clear()
        self.markerPois.enumerated().forEach { index,poi in
            let config = poi.configuration.copyWith(icon: icon,iconSize: size, angle: nil, anchor: nil)
            self.markerPois[index].updateIcon(configuration: config)
            mcIconLayer?.add(self.markerPois[index].icon)
        }
        mcIconLayer?.invalidate()
    }
}
public struct MarkerIconPoi {
    var configuration: MarkerConfiguration
    private(set)var icon:MCIconInfoInterface?
    let location:CLLocationCoordinate2D
    init(configuration: MarkerConfiguration, location: CLLocationCoordinate2D) {
        self.configuration = configuration
        self.location = location
        self.icon = self.createMapIcon()
    }
    public init( location: CLLocationCoordinate2D,angle: Float?, anchor: MarkerAnchor?) {
        self.configuration = MarkerConfiguration(icon: UIImage(), iconSize: nil, angle: angle, anchor: anchor)
        self.location = location
    }
    func createMapIcon()-> MCIconInfoInterface? {
        let texture = configuration.icon.toTexture(angle: configuration.angle ?? 0)
        let iconSize = if let iconSize = configuration.iconSize {
            MCVec2F(x:Float(iconSize.x),y:Float(iconSize.y))
        }else {
            MCVec2F(x: Float(texture.getImageWidth()), y: Float(texture.getImageHeight()))
        }
        let mcCoord  = self.location.mcCoord //.toMCCoordEpsg3857()
        if configuration.anchor != nil {
            return MCIconFactory.createIcon(withAnchor: location.id(),
                                     coordinate: mcCoord,
                                     texture: texture,
                                     iconSize: iconSize,
                                            scale: configuration.scaleType.getValue(), blendMode: .NORMAL,
                                           iconAnchor: MCVec2F(x: Float(configuration.anchor!.x), y: Float(configuration.anchor!.y)))
        }
        return  MCIconFactory.createIcon(location.id(),
                                 coordinate: mcCoord,
                                 texture: texture,
                                 iconSize: iconSize,
                                         scale: configuration.scaleType.getValue(), blendMode: .NORMAL)
    }
    mutating func updateIcon(configuration: MarkerConfiguration){
        self.configuration = configuration
        self.icon = self.createMapIcon()
    }
}
