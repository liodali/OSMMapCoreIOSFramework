//
//  ShapeManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 02.01.24.
//

import Foundation
@_implementationOnly import MapCore
import MapKit

public class ShapeManager:BaseManager,Manager {
   
    final let polygonLayer:MCPolygonLayerInterface? = MCPolygonLayerInterface.create()
    private let shapeBorderLayer = MCLineLayerInterface.create()
    override init(map: MCMapView) {
        super.init(map: map)
    }
    func initShapeManager(){
        self.map.insert(layer: shapeBorderLayer?.asLayerInterface(), at: 1)
        self.map.insert(layer: polygonLayer?.asLayerInterface(), at: 2)
        polygonLayer?.setLayerClickable(false)
        shapeBorderLayer?.setLayerClickable(false)
    }
    public func drawShape(key:String,shape:PShape){
          if  shape.style.borderWidth > 0 {
              let polygonBorder =  (shape as! Shape).createBorderShape(id: key)
              shapeBorderLayer?.add(polygonBorder)
        }
        let polygon = (shape as! Shape).createShape(id: key, hasBorder:false)
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
    
    public  func hideAll() {
        polygonLayer?.asLayerInterface()?.hide()
    }
    
    public  func hide(location: CLLocationCoordinate2D) {
        
    }
    
    public  func show(location: CLLocationCoordinate2D) {
        polygonLayer?.asLayerInterface()?.show()
    }
    
    public  func showAll() {
        
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
