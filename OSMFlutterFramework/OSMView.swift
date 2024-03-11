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
    func onMove(center:CLLocationCoordinate2D,bounds:BoundingBox,zoom:Double)
    func onRotate(angle:Double)
    func onMapInteraction()
}
protocol OnMapChanged {
    func onBoundsChanged(bounds:BoundingBox,zoom:Double)
    func onRotationChanged(angle:Double)
    func onMapInteraction()
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
private class MapCameraListener:MCMapCamera2dListenerInterface {
    private(set) var mapChanged:OnMapChanged?
    private var lastBounding:MCRectCoord? = nil
    init(mapChanged: OnMapChanged?) {
        self.mapChanged = mapChanged
    }
    func setMapChanged(mapChanged: OnMapChanged?){
        self.mapChanged = mapChanged
    }
    public func onVisibleBoundsChanged(_ visibleBounds: MCRectCoord, zoom: Double) {
        if lastBounding == nil || !(lastBounding == visibleBounds) {
            let bounds = visibleBounds.toBoundingBox()
            mapChanged?.onBoundsChanged(bounds: bounds, zoom: zoom)
            lastBounding = visibleBounds
        }
    }
    
    public func onRotationChanged(_ angle: Float) {
        mapChanged?.onRotationChanged(angle: Double(angle))
    }
    
    public func onMapInteraction() {
        mapChanged?.onMapInteraction()
    }
}
public class OSMView: UIViewController,OnMapChanged {
    
    
   

    private  let initLocation:CLLocationCoordinate2D?
    private  let zoomConfiguration:ZoomConfiguration
    private  let mapConfig = MCMapConfig(mapCoordinateSystem: MCCoordinateSystemFactory.getEpsg3857System())

    private  let mapView:MCMapView
    private  let mapTileConfiguration:OSMMapConfiguration
    private var osmTiledConfiguration:OSMTiledLayerConfig!
    private var rasterLayer:MCTiled2dMapRasterLayerInterface!
    private let identifier = MCCoordinateSystemIdentifiers.epsg4326()

    public let markerManager:MarkerManager
    public let roadManager:RoadManager
    public let poisManager:PoisManager
    public let locationManager:LocationManager
    public let shapeManager:ShapeManager
    private let rasterCallback: RasterCallbackInterface = RasterCallbackInterface()
    private let mapCameraListener:MapCameraListener = MapCameraListener(mapChanged: nil)
    public var onMapGestureDelegate: OnMapGesture? {
       didSet{
            rasterCallback.onMapGesture = onMapGestureDelegate
        }
    }
    public var onMapMove: OnMapMoved?
    
   
   public var mapHandlerDelegate:MapMarkerHandler?  {
        didSet{
            markerManager.updateHandler(locationHandlerDelegate: mapHandlerDelegate)
            poisManager.updateHandler(locationHandlerDelegate: mapHandlerDelegate)
      }
    }
    
    public var userLocationDelegate:OSMUserLocationHandler?  {
        didSet {
            locationManager.userLocationHandler = userLocationDelegate
        }
    }
    public var roadTapHandlerDelegate:PoylineHandler?  {
        didSet {
            roadManager.polylineHandlerDelegate = roadTapHandlerDelegate
        }
    }
    
    
    
    public init(rect:CGRect,location: CLLocationCoordinate2D?,zoomConfig:ZoomConfiguration,mapTileConfiguration:OSMMapConfiguration = OSMMapConfiguration()) {
        self.initLocation = location
        self.zoomConfiguration = zoomConfig
        self.mapTileConfiguration = mapTileConfiguration
       
        self.mapView = MCMapView(mapConfig: mapConfig)
        self.markerManager =  MarkerManager(map: mapView)
        self.roadManager =  RoadManager(map: mapView)
        self.poisManager =  PoisManager(map: mapView)
        self.shapeManager = ShapeManager(map: mapView)
        self.locationManager =  LocationManager(map: mapView, userLocationIcons: nil)
        super.init(nibName: nil, bundle: nil)
        self.mapCameraListener.setMapChanged(mapChanged: self)
        self.osmTiledConfiguration = OSMTiledLayerConfig(configuration: self.mapTileConfiguration)
        self.rasterLayer = MCTiled2dMapRasterLayerInterface.create(osmTiledConfiguration,
                                                                        loaders: [MCTextureLoader()])
        rasterLayer?.setMinZoomLevelIdentifier(zoomConfiguration.minZoom as NSNumber)
        rasterLayer?.setMaxZoomLevelIdentifier(zoomConfiguration.maxZoom as NSNumber)
        view.frame = rect
        self.mapView.backgroundColor = .gray.withAlphaComponent(CGFloat(200))
        self.mapView.camera.addListener(mapCameraListener)
    }
    public override func loadView() {
        view = self.mapView
    }
  
    func onBoundsChanged(bounds: BoundingBox, zoom: Double) {
        let center = center()
        onMapMove?.onMove(center: center, bounds: bounds,zoom: zoom)
        
    }
    
    func onRotationChanged(angle: Double) {
        onMapMove?.onRotate(angle: angle)
    }
    func onMapInteraction() {
        onMapMove?.onMapInteraction()
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
        if zoom < zoomConfiguration.minZoom {
            return OSMTiledLayerConfig.zoomIdentifierLevel[zoomConfiguration.minZoom]!
        } else if zoom > zoomConfiguration.maxZoom {
            return  OSMTiledLayerConfig.zoomIdentifierLevel[zoomConfiguration.maxZoom]!
        }
       return OSMTiledLayerConfig.zoomIdentifierLevel[zoom] ?? 139770566.007
    }
    
    
    
  
    
}

extension OSMView {
    
    /**
     Responsible init OSMMap,its mandetory to call this method to initialize properly the map
     */
    public func initOSMMap(tile:CustomTiles? = nil) {
        self.rasterLayer?.setCallbackHandler(rasterCallback)
        if(tile != nil){
            osmTiledConfiguration.setTileURL(tileURL: tile!.toString())
        }
        self.mapView.insert(layer: rasterLayer?.asLayerInterface(), at: 0)
        self.mapView.camera.setZoom(getZoomFromZoomIdentifier(zoom: zoomConfiguration.initZoom), animated: false)
        self.roadManager.initRoadManager()
        self.markerManager.initMarkerManager()
        self.shapeManager.initShapeManager()
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
    public func moveToByBoundingBox(bounds: BoundingBox,animated:Bool){
        let mcRectCoord = bounds.toMCRectCoord()
        self.mapView.camera.move(toBoundingBox: mcRectCoord, paddingPc: Float(0.1), animated: animated, minZoom: nil, maxZoom: nil)
    }
    /**
     Responsible  change Tiles of the map
     */
    public func setCustomTile(tile:CustomTiles){
        self.osmTiledConfiguration.setTileURL(tileURL: tile.toString())
        let nRaster = MCTiled2dMapRasterLayerInterface.create(osmTiledConfiguration,
                                                              loaders: [MCTextureLoader()])
        nRaster?.setCallbackHandler(rasterCallback)
        self.mapView.insert(layer: nRaster?.asLayerInterface(), at: 0)
        self.mapView.remove(layer: self.rasterLayer?.asLayerInterface())
        self.rasterLayer = nRaster
        self.mapView.invalidate()
    }
   
    /**
     this responsible to manage Marker for OSMView where you can add/remove/update markers
     */
    public func zoom()-> Int32 {
        let zoom =  self.mapView.camera.getZoom()
        return osmTiledConfiguration.getZoomIdentifierFromZoom(zoom: zoom) ?? Int32(zoomConfiguration.maxZoom)
    }
    public func zoomIn(step:Int?,animated:Bool = true) {
        let currentZoom = zoom()
        if( currentZoom == zoomConfiguration.maxZoom){
            return
        }
        let stepZoom = step ?? zoomConfiguration.step
        let nextZoom = if Int(currentZoom) + stepZoom > zoomConfiguration.maxZoom {
            getZoomFromZoomIdentifier(zoom: zoomConfiguration.maxZoom)
        }else{
            getZoomFromZoomIdentifier(zoom: Int(currentZoom) + stepZoom)
        }
        self.mapView.camera.setZoom(nextZoom, animated: animated)
    }
    public func zoomOut(step:Int?,animated:Bool = true) {
        let currentZoom = zoom()
        if( currentZoom == zoomConfiguration.minZoom){
            return
        }
        let stepZoom = step ?? zoomConfiguration.step
       
        let nextZoom:Double = if Int(currentZoom) + stepZoom > zoomConfiguration.maxZoom {
            getZoomFromZoomIdentifier(zoom: zoomConfiguration.maxZoom)
        }else{
            getZoomFromZoomIdentifier(zoom: Int(currentZoom) - stepZoom)
        }
        self.mapView.camera.setZoom(nextZoom, animated: animated)
    }
    public func setZoom(zoom:Int,animated:Bool = true) {
        if zoom >= zoomConfiguration.minZoom && zoom <= zoomConfiguration.maxZoom {
            let nzoomLevel = getZoomFromZoomIdentifier(zoom: zoom)
            self.mapView.camera.setZoom(nzoomLevel, animated: animated)
        }
    }
    public func getBoundingBox()->BoundingBox {
        self.mapView.camera.getBounds().toBoundingBox()
    }
    public func enableRotation(enable:Bool) {
        self.mapView.camera.setRotationEnabled(enable)
    }
    public func setRotation(angle:Double,animated:Bool = true) {
        self.mapView.camera.setRotation(Float(angle), animated: animated)
    }
    public func center()->CLLocationCoordinate2D {
        self.mapView.camera.getCenterPosition().toCLLocation2D()
    }
    public func stopCamera() {
        self.mapView.camera.freeze(true)
        Task {
            try await Task.sleep(nanoseconds: 150_000_000)
            self.mapView.camera.freeze(false)
        }
    }
    public func hideAllLayers() {
        self.roadManager.hildeAll()
        self.markerManager.hildeAll()
        self.poisManager.hildeAll()
    }
    public func showAllLayers() {
        self.roadManager.showAll()
        self.markerManager.showAll()
        self.poisManager.showAll()
    }
}
