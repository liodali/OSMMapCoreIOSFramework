//
//  OSMViewProtocols.swift
//  OSMMapCoreIOS
//
//  Created by Dali Hamza on 02.07.26.
//

import Foundation
import MapKit

// MARK: - Vector Tile Management (internal)

/// Manages vector tile fetching, style JSON processing, and base layer setup.
@MainActor protocol VectorTileManageable: AnyObject {
    func setupBaseLayer(tile: CustomTiles?)
    func finishLayerSwap()
    func fetchAndCreateVectorLayer(styleUrl: String)
    func extractQueryParams(from urlString: String) -> [String: String]?
    func sanitizeStyleJson(_ json: String) -> String
    func createVectorLayer(
        styleJsonUrl: String?, styleJson: String?, sourceUrlParams: [String: String]?
    )
}

// MARK: - Camera Management (public)

/// Camera operations: zoom, pan, rotation, bounds, and center queries.
@MainActor public protocol MapCameraManageable {
    func zoom() -> Int
    func zoomIn(step: Int?, animated: Bool)
    func zoomOut(step: Int?, animated: Bool)
    func setZoom(zoom: Int, animated: Bool)
    func moveTo(location: CLLocationCoordinate2D, zoom: Int?, animated: Bool)
    func moveToByBoundingBox(bounds: BoundingBox, animated: Bool)
    func center() -> CLLocationCoordinate2D
    func getBoundingBox() -> BoundingBox
    func setBoundingBox(bounds: BoundingBox)
    func enableRotation(enable: Bool)
    func setRotation(angle: Double, animated: Bool)
    func stopCamera()
}

// MARK: - Tile Configuration (public)

/// Runtime tile layer swapping.
@MainActor public protocol MapTileManageable {
    func setCustomTile(tile: CustomTiles)
}

// MARK: - Layer Visibility (public)

/// Show/hide all overlay layers (roads, markers, POIs).
@MainActor public protocol MapLayerVisibilityManageable {
    func hideAllLayers()
    func showAllLayers()
}

// MARK: - Touch Management (public)

/// Enable or disable user touch interaction on the map.
@MainActor public protocol MapTouchManageable {
    func disableTouch()
    func enableTouch()
}

// MARK: - Map Initialization (public)

/// Post-init map setup, e.g. moving to the initial location.
@MainActor public protocol MapInitializable {
    func initialisationMapWithInitLocation()
}

// MARK: - Location Delegate (public)

/// Setting external CLLocationManager delegates for custom location behavior.
@MainActor public protocol MapLocationDelegateManageable {
    func setLocationManagerDelegate(locationDelegate: CLLocationManagerDelegate?)
}
