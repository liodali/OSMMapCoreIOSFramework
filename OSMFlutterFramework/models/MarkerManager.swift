//
//  MarkerManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 01.12.23.
//

import Foundation
import MapKit
@_implementationOnly import MapCore

public protocol LocationHandler {
    func onTap(location:CLLocationCoordinate2D)
}

public class MarkerManager {
    let map: MCMapView
    var markers: [Marker] = []
    var pois: (id: String,angle:Float,layer: MCIconLayerInterface)? = nil
    public var locationHandlerDelegate:LocationHandler?  {
        didSet(handler){
            self.locationHandlerDelegate = handler
            if let nhandler = handler {
                markerHandler.setHandler(markerHandler: nhandler)
            }else {
                markerHandler.removeHandler()
            }
         
      }
    }
    
    private let markerHandler:IconLayerHander
    init(map: MCMapView) {
        self.map = map
        markerHandler = IconLayerHander(self.locationHandlerDelegate)
    }
    
    
    
    public func addMarker(marker:Marker){
        var nMarker = marker
        let iconLayer = MCIconLayerInterface.create()
        iconLayer?.setLayerClickable(true)
        let mccoord = marker.location.toMCCoordEpsg3857()
        let texture = marker.icon.toTexture(angle: marker.angle)
        let icon = marker.createMapIcon()
        iconLayer?.add(icon)
        iconLayer?.setCallbackHandler(markerHandler)
        nMarker.setLayer(iconLayerInterface: iconLayer!)
        //iconLayer?.setCallbackHandler(handler)
        map.add(layer: iconLayer?.asLayerInterface())
        markers.append(nMarker)
    }
    public func updateMarker(oldlocation:CLLocationCoordinate2D,newlocation:CLLocationCoordinate2D,
                             icon:UIImage?,angle:Float?,anchor:(x:Int,y:Int)?){
        var marker = markers.first { marker in
          marker.location == oldlocation
        }
        marker?.updateMarker(newLocation: newlocation, configuration: MarkerConfiguration(icon: icon, angle: angle, anchor: anchor))
    }
    public func removeMarker(location:CLLocationCoordinate2D){
      let marker = markers.first { marker in
          marker.location == location
        }
        map.remove(layer: marker?.iconLayerInterface?.asLayerInterface())
    }
}
class IconLayerHander:MCIconLayerCallbackInterface {
    private var markerHandler: LocationHandler?
    init(_ markerHandler: LocationHandler? = nil) {
        self.markerHandler = markerHandler
    }
    func onClickConfirmed(_ icons: [MCIconInfoInterface]) -> Bool {
        if let handler = markerHandler {
            handler.onTap(location: icons.first!.getCoordinate().toCLLocation2D())
        }
        return true
    }
    func setHandler(markerHandler: LocationHandler){
        self.markerHandler = markerHandler
    }
    func removeHandler(){
        self.markerHandler = nil
    }
}
