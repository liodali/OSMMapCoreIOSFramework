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
   
    
     override init(map: MCMapView) {
        super.init(map: map)
    }
    
    public func drawRectShape(center:CLLocationCoordinate2D,radius:Double,configuration:ShapeConfiguration){
        
    }
    
    public func drawCircleShape(center:CLLocationCoordinate2D,radius:Double,configuration:ShapeConfiguration){
        
    }
    
    public func deleteShape(center:CLLocationCoordinate2D){
        
    }
    
    public  func hideAll() {
        <#code#>
    }
    
    public  func hide(location: CLLocationCoordinate2D) {
        <#code#>
    }
    
    public  func show(location: CLLocationCoordinate2D) {
        <#code#>
    }
    
    public  func showAll() {
        <#code#>
    }
    
    
}
public struct ShapeConfiguration {
    let filledColor:UIColor
    let borderColor:UIColor
    let borderWidth:Double
    public init(filledColor: UIColor, borderColor: UIColor, borderWidth: Double) {
        self.filledColor = filledColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
}
