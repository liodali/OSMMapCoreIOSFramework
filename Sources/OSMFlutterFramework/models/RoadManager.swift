//
//  RoadManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 12.12.23.
//

import Foundation
@_implementationOnly import MapCore
import MapKit
@_implementationOnly import Polyline

public protocol PoylineHandler {
    func onTap(roadId:String)
}
public enum LineCapType {
    case BUTT
    case ROUND
    case SQUARE
    func getValue()->MCLineCapType{
          switch self {
            case .BUTT:
                MCLineCapType.BUTT
            case .ROUND:
                MCLineCapType.ROUND
                
            case .SQUARE:
                MCLineCapType.SQUARE

            }
    }
}
public enum PolylineType {
    case LINE
    case DOT
    
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
    private let lineBorderLayer = MCLineLayerInterface.create()
    init(map:MCMapView){
        self.mapView = map
        polylineLayerHandler = LineLayerHander()
    }
    
    func initRoadManager(above:MCLayerInterface?){
        self.mapView.insert(layer: lineBorderLayer?.asLayerInterface(), above: above)
        self.mapView.insert(layer: lineLayer?.asLayerInterface(), above: lineBorderLayer?.asLayerInterface())
        lineLayer?.setLayerClickable(true)
        lineLayer?.setCallbackHandler(polylineLayerHandler)
        lineBorderLayer?.setLayerClickable(false)
        lineBorderLayer?.setCallbackHandler(nil)
    }
    
    public func addRoad(id:String,polylines:[CLLocationCoordinate2D],configuration:RoadConfiguration){
       
        let coords = polylines.toMCCoords()
        if configuration.borderWidth != nil && configuration.borderWidth! > 0 && configuration.borderColor != nil
            && configuration.borderColor != configuration.color {
            let poylineBorder = MCLineFactory.createLine("\(id)-border",
                                                   coordinates: coords,
                                                   style: MCLineStyle(
                                                    color: MCColorStateList(normal: configuration.borderColor!.mapCoreColor,
                                                       highlighted: configuration.borderColor!.mapCoreColor),
                                                    gapColor: MCColorStateList(normal: configuration.borderColor!.mapCoreColor,
                                                    highlighted: configuration.borderColor!.mapCoreColor),
                                                    opacity: configuration.opacity,
                                                    blur: 0,
                                                    widthType: .SCREEN_PIXEL,
                                                    width: configuration.width + configuration.borderWidth!,
                                                    dashArray: [1,1],
                                                    lineCap: configuration.lineCap,
                                                    offset:0.0,
                                                    dotted: configuration.polylineType.isDOT(),
                                                    dottedSkew: Float(1)
                                        )
            )
           lineBorderLayer?.add(poylineBorder)
        }
        
        let poyline = MCLineFactory.createLine(id,
                            coordinates: coords,
                            style: MCLineStyle(
                            color: MCColorStateList(normal: configuration.color.mapCoreColor,
                               highlighted: configuration.color.mapCoreColor),
                             gapColor: MCColorStateList(normal: configuration.color.mapCoreColor,
                             highlighted: configuration.color.mapCoreColor),
                             opacity: configuration.opacity,
                             blur: 0,
                             widthType: .SCREEN_PIXEL,
                             width: configuration.width,
                             dashArray: [-1,-1],
                             lineCap: configuration.lineCap,
                             offset:-1.0,
                             dotted: configuration.polylineType.isDOT(),
                             dottedSkew: Float(1)
                    )
                )
        lineLayer?.add(poyline)
        roads.append(Road(id: id, lineLayer: poyline))
    
    }
    
    public func addRoad(id:String,polylines:String,configuration:RoadConfiguration){
        let polyline = Polyline.init(encodedPolyline: polylines)
        let coords = polyline.coordinates!.toMCCoords()
        if configuration.borderWidth != nil && configuration.borderWidth! > 0 && configuration.borderColor != nil
            && configuration.borderColor != configuration.color {
            let poylineBorder = MCLineFactory.createLine("\(id)-border",
                                                   coordinates: coords,
                                                   style: MCLineStyle(
                                                    color: MCColorStateList(normal: configuration.borderColor!.mapCoreColor,
                                                       highlighted: configuration.borderColor!.mapCoreColor),
                                                    gapColor: MCColorStateList(normal: configuration.borderColor!.mapCoreColor,
                                                    highlighted: configuration.borderColor!.mapCoreColor),
                                                    opacity: configuration.opacity,
                                                    blur: 0,
                                                    widthType: .SCREEN_PIXEL,
                                                    width: configuration.width + configuration.borderWidth!,
                                                    dashArray: [-1,-1],
                                                    lineCap: configuration.lineCap,
                                                    offset:-1.0,
                                                    dotted: configuration.polylineType.isDOT(),
                                                    dottedSkew: Float(1)
                                        )
            )
           lineBorderLayer?.add(poylineBorder)
        }
        
        let poyline = MCLineFactory.createLine(id,
                                               coordinates: coords,
                                               style: MCLineStyle(
                                                color: MCColorStateList(normal: configuration.color.mapCoreColor,
                                                   highlighted: configuration.color.mapCoreColor),
                                                gapColor: MCColorStateList(normal: configuration.color.mapCoreColor,
                                                highlighted: configuration.color.mapCoreColor),
                                                opacity: configuration.opacity,
                                                blur: 0,
                                                widthType: .SCREEN_PIXEL,
                                                width: configuration.width,
                                                dashArray: [-1,-1],
                                                lineCap: configuration.lineCap,
                                                offset:-1.0,
                                                dotted: configuration.polylineType.isDOT(),
                                                dottedSkew: Float(1)
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
            if lineBorderLayer != nil && !lineBorderLayer!.getLines().isEmpty {
              let lineBorder = lineBorderLayer?.getLines().first { borderLine in
                    borderLine.getIdentifier() == "\(id)-border"
                }
                lineBorderLayer?.remove(lineBorder)
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
        lineBorderLayer?.asLayerInterface()?.hide()
        lineHandler.skipHandler = true
    }
    public func showAll(){
       lineLayer?.asLayerInterface()?.show()
       lineBorderLayer?.asLayerInterface()?.show()
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
    let borderWidth:Float?
    let opacity:Float
    let lineCap:MCLineCapType
    let polylineType:PolylineType
                public init(width: Float, color: UIColor,borderWidth:Float? = nil, borderColor: UIColor? = nil,
                            opacity:Float = 1.0,lineCap:LineCapType = LineCapType.ROUND,polylineType:PolylineType = PolylineType.LINE) {
        self.width = width
        self.color = color
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.opacity = opacity
        self.polylineType = polylineType
        self.lineCap = lineCap.getValue()
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
