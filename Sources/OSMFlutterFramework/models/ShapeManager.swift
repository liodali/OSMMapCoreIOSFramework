//
//  ShapeManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 02.01.24.
//

import Foundation
import MapKit
#if compiler(>=5.10)
/* private */ internal import MapCore
#else
@_implementationOnly import MapCore
#endif

public enum ShapeTypes {
    case Rect
    case Circle
}
public class ShapeManager:BaseManager,Manager {
   
    final let polygonLayer:MCPolygonLayerInterface? = MCPolygonLayerInterface.create()
    private let shapeBorderLayer = MCLineLayerInterface.create()
    private var shapes = [String:ShapeTypes]()
    override init(map: MCMapView) {
        super.init(map: map)
    }
    func initShapeManager(){
        self.map.add(layer: shapeBorderLayer?.asLayerInterface())
        //self.map.insert(layer: polygonLayer?.asLayerInterface(), at: 1)
        self.map.insert(layer: polygonLayer?.asLayerInterface(), above: shapeBorderLayer?.asLayerInterface())
        polygonLayer?.setLayerClickable(false)
        shapeBorderLayer?.setLayerClickable(false)
    }
    public func drawShape(key:String,shape:PShape){
          if  shape.style.borderWidth > 0 {
              let polygonBorder =  (shape as! Shape).createBorderShape(id: key)
              shapeBorderLayer?.add(polygonBorder)
        }
        let polygon = (shape as! Shape).createShape(id: key, hasBorder:false)
        if shape is RectShapeOSM {
            shapes.updateValue(ShapeTypes.Rect, forKey: key)
        }else {
            shapes.updateValue(ShapeTypes.Circle, forKey: key)

        }
        polygonLayer?.add(polygon)
    }
    
    public func deleteShape(ckey:String){
      let poly = polygonLayer?.getPolygons().first { polygon in
            polygon.identifier == ckey
        }
        if let shape = poly {
            let polyBorder = shapeBorderLayer?.getLines().first { polygon in
                  polygon.getIdentifier() == "\(ckey)-border"
            }
            polygonLayer?.remove(shape)
            if let shapeBorder = polyBorder {
                shapeBorderLayer?.remove(shapeBorder)
            }
        }
    }
    
    public func deleteAllShapes(){
        shapeBorderLayer?.clear()
        polygonLayer?.clear()
    }
    public func deleteAllCircles(){
        deleteAllCustom(shapeTypes: ShapeTypes.Circle)
    }
    public func deleteAllRect(){
        deleteAllCustom(shapeTypes: ShapeTypes.Rect)
    }
    func deleteAllCustom(shapeTypes:ShapeTypes){
        let shapes =  shapes.filter { shape in
            shape.value == shapeTypes
        }
        let shapesKeys = shapes.keys
        let lines = shapeBorderLayer?.getLines().filter { border in
            let key = border.getIdentifier()
            
            return  shapesKeys.first{ shK in
                key.contains(shK)
            } != nil //shapesKeys.contains(key)
        }
        lines?.forEach { lineBorder in
            shapeBorderLayer?.remove(lineBorder)
        }
        let polygons = polygonLayer?.getPolygons().filter { polygon in
            shapesKeys.contains(polygon.identifier)
        }
        polygons?.forEach { shape in
            polygonLayer?.remove(shape)
        }
        
    }
    public  func hideAll() {
        polygonLayer?.asLayerInterface()?.hide()
    }
    
    public  func hide(location: CLLocationCoordinate2D) {
        polygonLayer?.asLayerInterface()?.hide()
    }
    
    public  func show(location: CLLocationCoordinate2D) {
        polygonLayer?.asLayerInterface()?.show()
    }
    
    public  func showAll() {
        polygonLayer?.asLayerInterface()?.show()
    }
    
    
}
public struct ShapeStyleConfiguration {
    let filledColor:UIColor
    let borderColor:UIColor
    let borderWidth:Double
    public init(filledColor: UIColor, borderColor: UIColor, borderWidth: Double) {
        self.filledColor = filledColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
}
