//
//  BaseManager.swift
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

public protocol Manager {
    func hideAll()
    func hide(location:CLLocationCoordinate2D)
    func show(location:CLLocationCoordinate2D)
    func showAll()
}
public class BaseManager {
    let map: MCMapView
    final let iconLayer: MCIconLayerInterface?  = MCIconLayerInterface.create()
    
    init(map: MCMapView) {
        self.map = map
    }
}
