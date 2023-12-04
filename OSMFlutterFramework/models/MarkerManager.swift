//
//  MarkerManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 01.12.23.
//

import Foundation
import MapKit
@_implementationOnly import MapCore

protocol LocationHandler {
    func onTap(location:CLLocationCoordinate2D)
}

public class MarkerManager {
    let map: MCMapView
    var markers: [(location: CLLocationCoordinate2D,layer: MCIconLayerInterface)] = []
    var pois: (id: String,layer: MCIconLayerInterface)? = nil
    init(map: MCMapView) {
        self.map = map
    }
    
    
    
    public func addMarker(location:CLLocationCoordinate2D, icon:UIImage){
        let mccoord = location.toMCCoordEpsg3857()
        let iconLayer = MCIconLayerInterface.create()
        iconLayer?.setLayerClickable(true)
        let texture = try! TextureHolder(icon.cgImage!)
        let icon = MCIconFactory.createIcon("",
                                 coordinate: mccoord,
                                 texture: texture,
                                 iconSize: .init(x: Float(texture.getImageWidth()), y: Float(texture.getImageHeight())),
                                            scale: MCIconType.FIXED)
        
        iconLayer?.add(icon)
        iconLayer?.setCallbackHandler (IconLayerHander())
        //iconLayer?.setCallbackHandler(handler)
        map.add(layer: iconLayer?.asLayerInterface())
    }
   
   public func addMarkerWithAnchor(location:CLLocationCoordinate2D, icon:UIImage,anchor:(x:Int,y:Int)){
        let mccoord = location.toMCCoordEpsg3857()
        let iconLayer = MCIconLayerInterface.create()
        iconLayer?.setLayerClickable(true)
        let texture = try! TextureHolder(icon.cgImage!)
        let icon = MCIconFactory.createIcon(location.id(),
                                 coordinate: mccoord,
                                 texture: texture,
                                 iconSize: .init(x: Float(texture.getImageWidth()), y: Float(texture.getImageHeight())),
                                            scale: MCIconType.FIXED)
        
        iconLayer?.add(icon)
        iconLayer?.setCallbackHandler(IconLayerHander())
        //iconLayer?.setCallbackHandler(handler)
        map.add(layer: iconLayer?.asLayerInterface())
    }
    public func updateMarker(oldlocation:CLLocationCoordinate2D,newlocation:CLLocationCoordinate2D,icon:UIImage?){
      let marker = markers.first { marker in
          marker.location == oldlocation
        }
        removeMarker(location: oldlocation)
        var texture = marker!.layer.getIcons().first?.getTexture()
        if icon != nil {
            texture = try! TextureHolder(icon!.cgImage!)
        }
        innerAddMarker(location: newlocation, iconTexture: texture as! TextureHolder)
    }
    public func updateMarkerWithAnchor(oldlocation:CLLocationCoordinate2D,newlocation:CLLocationCoordinate2D,icon:UIImage?,anchor:(x:Int,y:Int)){
      let marker = markers.first { marker in
          marker.location == oldlocation
        }
        removeMarker(location: oldlocation)
        var texture = marker!.layer.getIcons().first?.getTexture()
        if icon != nil {
            texture = try! TextureHolder(icon!.cgImage!)
        }
        innerAddMarkerWithAnchor(location: newlocation,iconTexture: texture! as! TextureHolder,anchor: anchor)
    }
    public func removeMarker(location:CLLocationCoordinate2D){
      let marker = markers.first { marker in
          marker.location == location
        }
        map.remove(layer: marker?.layer.asLayerInterface())
    }
    func innerAddMarker(location:CLLocationCoordinate2D, iconTexture:TextureHolder){
        let mccoord = location.toMCCoordEpsg3857()
        let iconLayer = MCIconLayerInterface.create()
        iconLayer?.setLayerClickable(true)

        let icon = MCIconFactory.createIcon(location.id(),
                                 coordinate: mccoord,
                                 texture: iconTexture,
                                 iconSize: .init(x: Float(iconTexture.getImageWidth()), y: Float(iconTexture.getImageHeight())),
                                            scale: MCIconType.FIXED)
        
        iconLayer?.add(icon)
        iconLayer?.setCallbackHandler (IconLayerHander())
        //iconLayer?.setCallbackHandler(handler)
        map.add(layer: iconLayer?.asLayerInterface())
    }
    func innerAddMarkerWithAnchor(location:CLLocationCoordinate2D, iconTexture:TextureHolder,anchor:(x:Int,y:Int)){
        let mccoord = location.toMCCoordEpsg3857()
        let iconLayer = MCIconLayerInterface.create()
        iconLayer?.setLayerClickable(true)

        let icon = MCIconFactory.createIcon(withAnchor: location.id(),
                                 coordinate: mccoord,
                                 texture: iconTexture,
                                 iconSize: .init(x: Float(iconTexture.getImageWidth()), y: Float(iconTexture.getImageHeight())),
                                            scale: MCIconType.FIXED,iconAnchor:MCVec2F(x: Float(anchor.x), y: Float(anchor.y)))
        
        iconLayer?.add(icon)
        iconLayer?.setCallbackHandler (IconLayerHander())
        //iconLayer?.setCallbackHandler(handler)
        map.add(layer: iconLayer?.asLayerInterface())
    }
}
class IconLayerHander:MCIconLayerCallbackInterface {
    let markerHandler: LocationHandler?
    init(_ markerHandler: LocationHandler? = nil) {
        self.markerHandler = markerHandler
    }
    func onClickConfirmed(_ icons: [MCIconInfoInterface]) -> Bool {
        if let handler = markerHandler {
            handler.onTap(location: icons.first!.getCoordinate().toCLLocation2D())
        }
        return true
    }
    
    
}
