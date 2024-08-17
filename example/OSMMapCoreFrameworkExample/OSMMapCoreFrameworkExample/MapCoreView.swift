//
//  MapCoreView.swift
//  MapOSMSwift
//
//  Created by Dali Hamza on 21.11.23.
//

import Foundation
import SwiftUI
import CoreLocation
import OSMFlutterFramework
import osrm_swift
import Polyline
struct OSMMapView: UIViewControllerRepresentable {
    typealias UIViewControllerType = InnerOSMMapView
    
    let width,height:Int
    
    init(width:Int = 200 ,height:Int = 200){
        self.width = width
        self.height = height
    }
    func makeUIViewController(context: Context) -> InnerOSMMapView {
        // Return MyView instance.
        let view = InnerOSMMapView(rect: .init(origin: .zero, size: CGSize(width: width, height:height)))

        // Do some configurations here if needed.
        return view
    }
    
    func updateUIViewController(_ uiViewController: InnerOSMMapView, context: Context) {
        
    }
    
    
}
public func -(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude - rhs.latitude <= 0.0000001 && lhs.longitude - rhs.longitude <= 0.0000001
}
struct MapCoreOSM:View {
    let width,height:Int
    
    public init(width:Int = 200 ,height:Int = 200){
        self.width = width
        self.height = height
    }
    var body: some View {
        OSMMapView(width: width,height: height)
    }
}
class InnerOSMMapView: UIViewController, OnMapGesture,OSMUserLocationHandler,PoylineHandler,MapMarkerHandler {
    var location:CLLocationCoordinate2D? = nil
    func onTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [unowned self] in
            do {
                let isEq = try self.location!.isEqual(rhs:location)
                if self.location != nil && isEq {
                    self.map.markerManager.removeMarker(location: self.location!)
                    self.location = nil
                }
            }catch {
                
            }
            
        }
    }
    
  
    func onTap(roadId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [unowned self] in
            map.roadManager.removeRoad(id: roadId)
           }
    }
    
    
    func locationChanged(userLocation: CLLocationCoordinate2D,heading:Double) {
        print("\(userLocation),\(heading)")
        self.map.moveTo(location: userLocation, zoom: nil, animated: true)
    }
    
    func handlePermission(state: OSMFlutterFramework.LocationPermission) {
        print("\(state)")
    }
    
    func onSingleTap(location: CLLocationCoordinate2D) {
        if(geos.count < 2){
            let image = UIImage(systemName: "mappin")
           // if self.location == nil {
              let marker = Marker(location: location,
                                   markerConfiguration: MarkerConfiguration(icon: image!,
                                                                            iconSize: (x:Int(56.0 * UIScreen.main.nativeScale),y:Int(56.0 * UIScreen.main.nativeScale)),
                                                                            angle: nil,
                                                                            anchor: (0.5,1))// (0.5,0.5))
               )
                self.map.markerManager.addMarker(marker: marker)
           // }else {
                //self.map.markerManager.updateMarker(oldlocation: self.location!, newlocation: location, icon: nil)
               
           // }
           // self.map.markerManager.addMarker(marker: marker)
            self.location = location

            geos.append(location)
        }
       
        if(geos.count >= 2 && alert == nil){
            Task.detached { @MainActor in
                self.alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
                let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
                loadingIndicator.hidesWhenStopped = true
                loadingIndicator.style = UIActivityIndicatorView.Style.gray
                loadingIndicator.startAnimating();
                self.alert!.view.addSubview(loadingIndicator)
                self.present(self.alert!, animated: true, completion: nil)
            }
           
            DispatchQueue.global().async {
                Task {
                    let result = await self.osrmManager.getRoadAsync(wayPoints: self.geos, configuration: InputRoadConfiguration())
                    if result != nil {
                        let polyline = Polyline(encodedPolyline: result!.mRouteHigh)
                        Task.detached { @MainActor in
                            self.map.roadManager.addRoad(id: "1", polylines: polyline.coordinates!, configuration: RoadConfiguration(width: 5.0, color: UIColor.red))
                        }
                    }
                    Task.detached { @MainActor in
                        self.dismiss(animated: false, completion: nil)
                        self.geos.removeAll()
                        self.alert = nil
                    }
                   
                }
              
            }
        }
    }
    
    func onLongTap(location: CLLocationCoordinate2D) {
        self.map.markerManager.removeMarker(location: location)
    }
    
    let map:OSMView
    let osrmManager:OSRMManager
    var alert:UIAlertController? = nil
    var geos:[CLLocationCoordinate2D] = []
    var initMap:Bool = false
    let rect:CGRect
    var viewStack:UIStackView = UIStackView(frame: CGRect(origin: CGPoint(x: 72, y: 350), size: CGSize(width: 48, height: 128)))
    var viewStack2:UIStackView = UIStackView(frame: CGRect(origin: CGPoint(x: 350, y: 350), size: CGSize(width: 48, height: 128)))
    let buttonZoomIn = UIButton(type: .system)
    let buttonZoomOut = UIButton(type: .system)
    let buttonUserLocation = UIButton(type: .system)
    let buttonRemove = UIButton(type: .system)
    let zoomConf = ZoomConfiguration(initZoom: 16,minZoom: 1,maxZoom: 19)
    let initLoc = CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324)
    var zoomL = 16
    public init(rect:CGRect) {
         self.map = OSMView(rect:rect,
                            location: initLoc,
                            zoomConfig: zoomConf)
       
        //map.frame = rect//CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 300, height: 300))
        self.rect = rect
        self.osrmManager = try! OSRMManager()
        super.init(nibName: nil, bundle: nil)
        //map.frame = rect
        self.view.addSubview(self.map)
        self.view.addSubview(viewStack)
        self.view.addSubview(viewStack2)
        
        //map.didMove(toParent: self)
        
        
        buttonUserLocation.setImage((UIImage(systemName: ".location.slash") ?? UIImage()).withTintColor(.black), for: UIControl.State.normal)
        buttonUserLocation.frame = CGRect(origin: CGPoint(x:0,y: 0), size: CGSize(width: 32,height: 56))
        buttonUserLocation.backgroundColor = UIColor.gray
        buttonUserLocation.translatesAutoresizingMaskIntoConstraints = true
        buttonUserLocation.addAction(UIAction(title: "user", handler: { _ in
            self.map.locationManager.toggleTracking(configuration: TrackConfiguration(moveMap: false,controlUserMarker: false))
            if self.map.locationManager.isTrackingEnabled() {
                self.buttonUserLocation.setImage((UIImage(systemName: ".location") ?? UIImage()).withTintColor(.black), for: .normal)
            }else {
                self.buttonUserLocation.setImage((UIImage(systemName: ".location.slash") ?? UIImage() ).withTintColor(.black), for: .normal)
            }
        }), for: .touchUpInside)
        buttonRemove.setImage((UIImage(systemName: ".trash") ?? UIImage()).withTintColor(.black), for: UIControl.State.normal)
        buttonRemove.frame = CGRect(origin: CGPoint(x:32,y: 0), size: CGSize(width: 32,height: 56))
        buttonRemove.backgroundColor = UIColor.gray
        buttonRemove.translatesAutoresizingMaskIntoConstraints = true
        buttonRemove.addAction(UIAction(title: "remove location", handler: { _ in
            //self.map.markerManager.removeMarkers(locations: self.geos)
            for  geo in self.geos {
                self.map.markerManager.removeMarker(location: geo)
            }
        }), for: .touchUpInside)
        
        viewStack2.alignment = .fill
        viewStack2.distribution = .fillEqually
        viewStack2.spacing = 8.0
        viewStack2.axis = .vertical
        viewStack2.addArrangedSubview(buttonUserLocation)
        viewStack2.addArrangedSubview(buttonRemove)
        
        buttonZoomIn.setTitle("+", for: .normal)
        buttonZoomIn.setTitleColor(UIColor.white, for: .normal)
        buttonZoomIn.frame = CGRect(x:32,y: 0,width: 48,height: 56)
        buttonZoomIn.backgroundColor = UIColor.blue
        buttonZoomIn.translatesAutoresizingMaskIntoConstraints = false
        buttonZoomIn.addAction(UIAction(title: "+", handler: { _ in
            self.map.zoomIn(step: 1)
        }), for: .touchUpInside)
        buttonZoomOut.setTitle("-", for: .normal)
        //buttonZoomIn.frame = CGRect(x:0,y:64,width: 48,height: 56)
        buttonZoomOut.setTitleColor(UIColor.white, for: .normal)
        buttonZoomOut.backgroundColor = UIColor.blue
        buttonZoomOut.translatesAutoresizingMaskIntoConstraints = false
        buttonZoomOut.addAction(UIAction(title: "-", handler: { _ in
            self.map.zoomOut(step: 1)

        }), for: .touchUpInside)

        viewStack.alignment = .fill
        viewStack.distribution = .fillEqually
        viewStack.spacing = 8.0
        viewStack.axis = .vertical
        
        viewStack.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        viewStack.addArrangedSubview(buttonZoomIn)
        viewStack.addArrangedSubview(buttonZoomOut)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //view.addSubview(map.view)
        map.onMapGestureDelegate = self
        map.mapHandlerDelegate = self
       // map.disableTouch()
       
    }
    func disableAllGestures(for view: UIView) {
        if let gestureRecognizers = view.gestureRecognizers {
            for gesture in gestureRecognizers {
                gesture.isEnabled = false
            }
        }
        for sub in view.subviews {
            if let gestureRecognizers = sub.gestureRecognizers {
                for gesture in gestureRecognizers {
                    gesture.isEnabled = false
                }
            }
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        if !initMap {
            //map.initialisationMapWithInitLocation()
            //map.setZoom(zoom: 12)
            initMap = true
        }
        
        
        //map.moveTo(location: CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324), zoom: 12, animated: false)
        

        /*let roadConfig = RoadConfiguration(width:20.0,
                                           color: UIColor(hex: "#ff0000ff") ?? .green,
                                           borderWidth: 25,
                                           borderColor: .black,
                                           lineCap:LineCapType.ROUND)
        map.roadManager.addRoad(id: "road1", polylines: [
            CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324),
        CLLocationCoordinate2D(latitude: 47.4433594, longitude: 8.4680184),
        CLLocationCoordinate2D(latitude: 47.4317782, longitude: 8.4716146),
            CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324)
        ], configuration: roadConfig)*/
        map.roadTapHandlerDelegate = self
        map.userLocationDelegate = self
        /*DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [unowned self] in
            //map.locationManager.requestSingleLocation()
            map.setCustomTile(tile: CustomTiles(["urls":[["url":"https://a.tile-cyclosm.openstreetmap.fr/cyclosm/"]],
                                                 "tileExtension":".png","tileSize":256,"maxZoomLevel":19]))
        }
        let iconUserM = MarkerConfiguration(icon: UIImage(systemName: "location")!,
                                            iconSize: MarkerIconSize(x:48,y:48), angle: nil, anchor: nil)
        map.locationManager.setUserLocationIcons(
            userLocationIcons: UserLocationConfiguration(userIcon:iconUserM , directionIcon: iconUserM))
         */
        /*map.shapeManager.drawShape(key: "rect",
                                   shape: CircleOSM(center:CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324),
                                   distanceInMeter:500,
                                   style:ShapeStyleConfiguration(
                                    filledColor: UIColor.red.withAlphaComponent(CGFloat(0.5)),
                                        borderColor: UIColor.green.withAlphaComponent(CGFloat(1)),
                                        borderWidth: 20
                                     )
                                   )
                                 )*/
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [unowned self] in
            print("current zoom \(map.zoom())")
            self.map.setBoundingBox(bounds: BoundingBox(center: CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324), distanceKm: 0.1))
            
            let iconUserM = MarkerConfiguration(icon: UIImage(systemName: "location")!,
                                                iconSize: MarkerIconSize(x:48,y:48), angle: nil, anchor: nil)
            
            self.map.markerManager.addMarker(marker: Marker(location: CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324), markerConfiguration: iconUserM))
            //map.moveTo(location:  CLLocationCoordinate2D(latitude: 47.4317782, longitude: 8.4716146), zoom: zoomConf.initZoom, animated: true)
            //map.shapeManager.deleteShape(ckey: "rect")
            //map.locationManager.requestEnableLocation()
           /* map.locationManager.toggleTracking(configuration: TrackConfiguration(
                moveMap: false,controlUserMarker: false))*/
            //map.zoomIn(step: 5)
        }
        //map.locationManager.requestEnableLocation()
        //map.locationManager.toggleTracking()
    }
  
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

}
extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }else if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    a = 1.0

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}
