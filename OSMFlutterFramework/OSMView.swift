//
//  OSMView.swift
//  OSMMapCoreIOS
//
//  Created by Dali Hamza on 21.11.23.
//

import Foundation
import MapKit
@_implementationOnly import MapCore

public protocol OnMapGesture {
    func onSingleTap(location:CLLocationCoordinate2D)
    func onLongTap(location:CLLocationCoordinate2D)
}
public protocol OnMapMoved {
    func onMove(center:CLLocationCoordinate2D,bounds:BoundingBox)
}
protocol OnMapChanged {
    func onChanged()
}
private class RasterCallbackInterface : MCTiled2dMapRasterLayerCallbackInterface{
    var onMapGesture:OnMapGesture?
    init(onMapGesture: OnMapGesture? = nil) {
        self.onMapGesture = onMapGesture
    }
    func onClickConfirmed(_ coord: MCCoord) -> Bool {
        if onMapGesture != nil {
            onMapGesture!.onSingleTap(location: coord.toCLLocation2D())
        }
        return true
    }
    
    func onLongPress(_ coord: MCCoord) -> Bool {
        if onMapGesture != nil {
            onMapGesture!.onLongTap(location: coord.toCLLocation2D())
        }
        return true
    }
    
    
}
public class OSMView: UIViewController,OnMapChanged {
    
    
    
    
    private  let initLocation:CLLocationCoordinate2D?
    private  let zoomConfiguration:ZoomConfiguration
    private  let mapConfig = MCMapConfig(mapCoordinateSystem: MCCoordinateSystemFactory.getEpsg3857System())

    private  let mapView:MCMapView
     
    private lazy var osmTiledConfiguration = OSMTiledLayerConfig(onChanged: self)
    private lazy var rasterLayer = MCTiled2dMapRasterLayerInterface.create(osmTiledConfiguration,
                                                                    loaders: [MCTextureLoader()])
    private let identifier = MCCoordinateSystemIdentifiers.epsg4326()

    private let markerManager:MarkerManager
    private let roadManager:RoadManager
    
    private let rasterCallback: RasterCallbackInterface = RasterCallbackInterface()
    private var mapGesture: OnMapGesture?
    public var onMapGesture: OnMapGesture? {
       didSet(mapGesture){
            self.mapGesture = mapGesture
            rasterCallback.onMapGesture = mapGesture
        }
    }
    public var onMapMove: OnMapMoved? {
       didSet(onMove){
            self.onMapMove = onMove
        }
    }
    
    
    public init(rect:CGRect,location: CLLocationCoordinate2D?,zoomConfig:ZoomConfiguration) {
        self.initLocation = location
        self.zoomConfiguration = zoomConfig
        self.mapView = MCMapView(mapConfig: mapConfig)
        self.markerManager =  MarkerManager(map: mapView)
        self.roadManager =  RoadManager(map: mapView)
        super.init(nibName: nil, bundle: nil)
        rasterLayer?.setMinZoomLevelIdentifier(zoomConfiguration.minZoom as NSNumber)
        rasterLayer?.setMaxZoomLevelIdentifier(zoomConfiguration.maxZoom as NSNumber)
        view.frame = rect
        self.mapView.backgroundColor = .gray.withAlphaComponent(CGFloat(200))
    }
    public override func loadView() {
        view = self.mapView
    }
    func onChanged() {
        if onMapMove != nil {
            let center = center()
            let boundingBox = getBoundingBox()
            onMapMove?.onMove(center: center, bounds: boundingBox)
        }
    }
    
    /*
     public override func viewDidAppear(_ animated: Bool) {
        if initLocation != nil {
            moveTo(location: initLocation!, zoom: zoomConfiguration.initZoom, animated: false)
        }
    }*/
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func getZoomFromZoomIdentifier(zoom:Int) -> Double {
        if zoom < zoomConfiguration.minZoom && zoom > zoomConfiguration.maxZoom {
            return 139770566.007
        }
       return osmTiledConfiguration.getZoomLevelInfos().first { level in
            level.zoomLevelIdentifier == zoom
            
        }?.zoom ?? 139770566.007
    }
    func getZoomIdentifierFromZoom(zoom:Double) -> Int32 {

       return osmTiledConfiguration.getZoomLevelInfos().first { level in
           level.zoom == zoom
       }?.zoomLevelIdentifier ?? Int32(zoomConfiguration.maxZoom)
    }
    
}

extension OSMView {
    
    /**
     Responsible set area Limit for camera of MapView
     */
    public func initOSMMap(tile:CustomTiles?) {
        self.rasterLayer?.setCallbackHandler(rasterCallback)
        if(tile != nil){
            osmTiledConfiguration.setTileURL(tileURL: tile!.toString())
        }
        self.mapView.insert(layer: rasterLayer?.asLayerInterface(), at: 0)
        self.mapView.camera.setZoom(getZoomFromZoomIdentifier(zoom: zoomConfiguration.initZoom), animated: false)
        self.roadManager.initRoadManager()
    }
    /**
     Responsible to manage Marker for OSMView where you can add/remove/update markers
     */
    public func getMarkerManager() -> MarkerManager {
        self.markerManager
    }
    /**
     Responsible to manage Roads for OSMView where you can add/remove/update poylines
     */
    public func getRoadManager() -> RoadManager {
        self.roadManager
    }
    /**
     Responsible set area Limit for camera of MapView
     */
    public func setBoundingBox(bounds:BoundingBox) {
        self.mapView.camera.setBounds(bounds.toMCRectCoord())
    }
    
    /**
     Responsible to move the camera to [location] with zoom,animation
     */
    public func moveTo(location: CLLocationCoordinate2D,zoom:Int?,animated:Bool){
        var innerZoom =  mapView.camera.getZoom()
        if let izoom = zoom {
            innerZoom = getZoomFromZoomIdentifier(zoom: izoom)
        }
        self.mapView.camera.setZoom(innerZoom, animated: false)
        self.mapView.camera.move(toCenterPositionZoom: location.mcCoord,zoom:innerZoom, animated: animated)
    }
    /**
     Responsible to move the camera to [location] with zoom,animation
     */
    public func setCustomTile(tile:CustomTiles){
        self.osmTiledConfiguration.setTileURL(tileURL: tile.toString())
    }
   
    /**
     this responsible to manage Marker for OSMView where you can add/remove/update markers
     */
    public func zoom()-> Int32 {
        let zoom =  self.mapView.camera.getZoom()
        return getZoomIdentifierFromZoom(zoom: zoom)
    }
    public func zoomIn(step:Int?) {
        let currentZoom = zoom()
        if( currentZoom == zoomConfiguration.maxZoom){
            return
        }
        let stepZoom = step ?? zoomConfiguration.step
        let nextZoom = if Int(currentZoom) + stepZoom > zoomConfiguration.maxZoom {
            zoomConfiguration.maxZoom
        }else{
            Int(currentZoom) + stepZoom
        }
        self.mapView.camera.setZoom(getZoomFromZoomIdentifier(zoom: nextZoom), animated: true)
    }
    public func zoomOut(step:Int?) {
        let currentZoom = zoom()
        if( currentZoom == zoomConfiguration.minZoom){
            return
        }
        let stepZoom = step ?? zoomConfiguration.step
        let nextZoom = if Int(currentZoom) - stepZoom < zoomConfiguration.minZoom {
            zoomConfiguration.minZoom
        }else{
            Int(currentZoom) - stepZoom
        }
        self.mapView.camera.setZoom(getZoomFromZoomIdentifier(zoom: nextZoom), animated: true)
    }
    public func setZoom(zoom:Int) {
        if zoom >= zoomConfiguration.minZoom || zoom <= zoomConfiguration.maxZoom {
            self.mapView.camera.setZoom(getZoomFromZoomIdentifier(zoom: zoom), animated: true)
        }

    }
    public func getBoundingBox()->BoundingBox {
        self.mapView.camera.getBounds().toBoundingBox()
    }
    public func enableRotation(enable:Bool) {
        self.mapView.camera.setRotationEnabled(enable)
    }
    public func setRotation(angle:Double) {
        self.mapView.camera.setRotation(Float(angle), animated: true)
    }
    public func center()->CLLocationCoordinate2D {
        self.mapView.camera.getCenterPosition().toCLLocation2D()
    }
}
