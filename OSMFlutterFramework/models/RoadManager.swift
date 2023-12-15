//
//  RoadManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 12.12.23.
//

import Foundation
@_implementationOnly import MapCore
import MapKit
public protocol PoylineHandler {
    func onTap(roadId:String)
}

public class RoadManager {
    
    private let mapView:MCMapView
    let lineHandler = LineLayerHander()
    var polylineHandlerDelegate:PoylineHandler?  {
        didSet{
            if let nhandler = polylineHandlerDelegate {
                polylineLayerHandler.setHandler(poylineHandler: nhandler)
            }else {
                polylineLayerHandler.removeHandler()
            }
         
      }
    }
    private let polylineLayerHandler:LineLayerHander
    private var roads:[Road] = []
    private let lineLayer = MCLineLayerInterface.create()
    init(map:MCMapView){
        self.mapView = map
        polylineLayerHandler = LineLayerHander()
    }
    
    func initRoadManager(){
        self.mapView.insert(layer: lineLayer?.asLayerInterface(), at: 1)
        lineLayer?.setLayerClickable(true)
        lineLayer?.setCallbackHandler(polylineLayerHandler)
    }
    
    public func addRoad(id:String,polylines:[CLLocationCoordinate2D],configuration:RoadConfiguration){
       
        let coords = polylines.map { location in
            location.toMCCoord()
        }
        let poyline = MCLineFactory.createLine(id,
                                               coordinates: coords,
                                               style: MCLineStyle(
                                                   color: MCColorStateList(normal: configuration.color.mapCoreColor,
                                                   highlighted: (configuration.borderColor ?? configuration.color).mapCoreColor),
                                                   gapColor: MCColorStateList(normal: (configuration.color).mapCoreColor,
                                                   highlighted: (configuration.borderColor ?? configuration.color).mapCoreColor),
                                                   opacity: 1.0,
                                                   blur: 0,
                                                   widthType: .SCREEN_PIXEL,
                                                   width: configuration.width,
                                                   dashArray: [1,1],
                                                   lineCap: .ROUND
                                               )
                           )
        lineLayer?.add(poyline)
        roads.append(Road(id: id, lineLayer: poyline))
    
    }
    public func removeRoad(id:String){
        let road = getRoad(id:id)
        if road != nil {
            lineLayer?.remove(road?.lineLayer)
            roads.removeAll { road in
                road.id == id
            }
        }
    }
    public func removeAllRoads(){
        lineLayer?.clear()
        roads.removeAll()
    }
    func getRoad(id:String)->Road?{
        return roads.first { road in
            road.id == id
        }
    }
    public func hildeAll(){
        lineLayer?.asLayerInterface()?.hide()
        lineHandler.skipHandler = true
    }
    public func showAll(){
       lineLayer?.asLayerInterface()?.show()
       lineHandler.skipHandler = false
    }
    public func lockHandler(){
       lineHandler.skipHandler = !lineHandler.skipHandler
    }
}
struct Road {
    let id:String
    let lineLayer:MCLineInfoInterface?
    init(id: String, lineLayer: MCLineInfoInterface?) {
        self.id = id
        self.lineLayer = lineLayer
    }
}
public struct RoadConfiguration {
    let width:Float
    let color:UIColor
    let borderColor:UIColor?
    public init(width: Float, color: UIColor, borderColor: UIColor?) {
        self.width = width
        self.color = color
        self.borderColor = borderColor
    }
}
class LineLayerHander:MCLineLayerCallbackInterface {
    private var poylineHandler: PoylineHandler?
    var skipHandler: Bool = false
    init(_ poylineHandler: PoylineHandler? = nil) {
        self.poylineHandler = poylineHandler
    }
    func onLineClickConfirmed(_ line: MCLineInfoInterface?) {
        if let polyline = line, !skipHandler {
            let id =  polyline.getIdentifier()
            poylineHandler?.onTap(roadId: id)
        }
    }
    func setHandler(poylineHandler: PoylineHandler){
        self.poylineHandler = poylineHandler
    }
    func removeHandler(){
        self.poylineHandler = nil
    }
}
