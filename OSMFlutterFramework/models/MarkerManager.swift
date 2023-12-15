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
    private let markerHandler:IconLayerHander
    init(map: MCMapView) {
        self.map = map
        markerHandler = IconLayerHander(nil)
    }
    
    func updateHandler(locationHandlerDelegate:LocationHandler?){
        if let nhandler = locationHandlerDelegate {
            markerHandler.setHandler(markerHandler: nhandler)
        }else {
            markerHandler.removeHandler()
        }
    }
    
    public func addMarker(marker:Marker){
        var nMarker = marker
        let iconLayer = MCIconLayerInterface.create()
        iconLayer?.setLayerClickable(true)
        let mccoord = marker.location.toMCCoordEpsg3857()
        let icon = marker.createMapIcon()
        iconLayer?.add(icon)
        iconLayer?.setCallbackHandler(markerHandler)
        nMarker.setLayer(iconLayerInterface: iconLayer!)
        //iconLayer?.setCallbackHandler(handler)
        map.add(layer: iconLayer?.asLayerInterface())
        markers.append(nMarker)
    }
    public func updateMarker(oldlocation:CLLocationCoordinate2D,newlocation:CLLocationCoordinate2D,
                             icon:UIImage?,iconSize:MarkerIconSize? = nil,
                             angle:Float? = nil,anchor:(x:Int,y:Int)? = nil,
                             scaleType:MarkerScaleType? = nil){
        
        var index = markers.firstIndex { marker in
            marker.location == oldlocation
        }
        
        if index != nil  {
            var marker = markers[index!]
            let config = marker.markerConfiguration.copyWith(icon: icon,iconSize: iconSize, angle: angle, anchor: anchor,scaleType: scaleType)
            marker.updateMarker(newLocation: newlocation, configuration: config)
            markers[index!] = marker
            self.map.invalidate()
        }
        
        
    }
    public func removeMarker(location:CLLocationCoordinate2D){
      let index = markers.firstIndex { marker in
          marker.location == location
      }
        if index != nil {
            map.remove(layer: markers[index!].iconLayerInterface?.asLayerInterface())
            markers.remove(at: index!)
        }
        
    }
    public func getAllMarkers()->[CLLocationCoordinate2D]{
        markers.map { marker in
            marker.location
        }
    }
    public func hildeAll(){
        markers.forEach { marker in
            marker.iconLayerInterface?.asLayerInterface()?.hide()
        }
        markerHandler.skipHandler = true
    }
    public func showAll(){
        markers.forEach { marker in
            marker.iconLayerInterface?.asLayerInterface()?.show()
        }
        markerHandler.skipHandler = false
    }
    public func lockHandler(){
        markerHandler.skipHandler = !markerHandler.skipHandler
    }
}
class IconLayerHander:MCIconLayerCallbackInterface {
    private var markerHandler: LocationHandler?
    var skipHandler: Bool = false
    init(_ markerHandler: LocationHandler? = nil) {
        self.markerHandler = markerHandler
    }
    func onClickConfirmed(_ icons: [MCIconInfoInterface]) -> Bool {
        if let handler = markerHandler, !skipHandler {
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
