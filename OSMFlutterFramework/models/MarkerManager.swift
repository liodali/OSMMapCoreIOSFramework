//
//  MarkerManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 01.12.23.
//

import Foundation
import MapKit
@_implementationOnly import MapCore

public protocol MapMarkerHandler {
    func onTap(location:CLLocationCoordinate2D)
}

public class MarkerManager {
    let map: MCMapView
    var markers: [Marker] = []
    private let markerHandler:IconLayerHander
    private let iconLayerInterface:MCIconLayerInterface? =  MCIconLayerInterface.create()
    init(map: MCMapView) {
        self.map = map
        markerHandler = IconLayerHander(nil)
        iconLayerInterface?.setLayerClickable(true)
        iconLayerInterface?.setCallbackHandler(markerHandler)
    }
    
    func updateHandler(locationHandlerDelegate:MapMarkerHandler?){
        if let nhandler = locationHandlerDelegate {
            markerHandler.setHandler(markerHandler: nhandler)
        }else {
            markerHandler.removeHandler()
        }
    }
    
    public func addMarker(marker:Marker){
        var nMarker = marker

        let icon = marker.createMapIcon()
        iconLayerInterface?.add(icon)
        nMarker.setLayer(iconLayerInterface: iconLayerInterface!)
        //iconLayer?.setCallbackHandler(handler)
        map.add(layer: iconLayerInterface?.asLayerInterface())
        markers.append(nMarker)
    }
    public func updateMarker(oldlocation:CLLocationCoordinate2D,
                             newlocation:CLLocationCoordinate2D,
                             icon:UIImage?,
                             iconSize:MarkerIconSize? = nil,
                             angle:Float? = nil,
                             anchor:MarkerAnchor? = nil,
                             scaleType:MarkerScaleType? = nil){
        
        let index = markers.firstIndex { marker in
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
    public func updatrMarkerIcon(location:CLLocationCoordinate2D,
                             icon:UIImage?,
                             iconSize:MarkerIconSize? = nil){
        
        let index = markers.firstIndex { marker in
            marker.location == location
        }
        
        if index != nil  {
            var marker = markers[index!]
            let config = marker.markerConfiguration.copyWith(icon: icon,iconSize: iconSize)
            marker.updateIconMarker(configuration: config)
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
        iconLayerInterface?.asLayerInterface()?.hide()
        markerHandler.skipHandler = true
    }
    public func showAll(){
        iconLayerInterface?.asLayerInterface()?.show()
        markerHandler.skipHandler = false
    }
    public func lockHandler(){
        markerHandler.skipHandler = !markerHandler.skipHandler
    }
}
class IconLayerHander:MCIconLayerCallbackInterface {
    private var markerHandler: MapMarkerHandler?
    var skipHandler: Bool = false
    init(_ markerHandler: MapMarkerHandler? = nil) {
        self.markerHandler = markerHandler
    }
    func onClickConfirmed(_ icons: [MCIconInfoInterface]) -> Bool {
        if let handler = markerHandler, !skipHandler {
            if icons.count == 0 {
                handler.onTap(location: icons.first!.getCoordinate().toCLLocation2D())
            }else {
                icons.forEach { icon in
                    handler.onTap(location: icon.getCoordinate().toCLLocation2D())
                }
            }
        }
        return true
    }
    func setHandler(markerHandler: MapMarkerHandler){
        self.markerHandler = markerHandler
    }
    func removeHandler(){
        self.markerHandler = nil
    }
}
