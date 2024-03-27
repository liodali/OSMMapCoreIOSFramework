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
        let image = UIImage(systemName: "mappin")
        if self.location == nil {
          let marker = Marker(location: location,
                               markerConfiguration: MarkerConfiguration(icon: image!,
                                                                        iconSize: (x:Int(56.0 * UIScreen.main.nativeScale),y:Int(56.0 * UIScreen.main.nativeScale)),
                                                                        angle: nil,
                                                                        anchor: (0.5,1))// (0.5,0.5))
           )
            self.map.markerManager.addMarker(marker: marker)
        }else {
            self.map.markerManager.updateMarker(oldlocation: self.location!, newlocation: location, icon: nil)
        }
        self.location = location

         
    }
    
    func onLongTap(location: CLLocationCoordinate2D) {
        
    }
    
    let map:OSMView
    var initMap:Bool = false
    let rect:CGRect
    var viewStack:UIStackView? = nil
    let buttonZoomIn = UIButton()
    let buttonZoomOut = UIButton()
    public init(rect:CGRect) {
         self.map = OSMView(rect:rect,
                            location: CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324),
                            zoomConfig: ZoomConfiguration(initZoom: 12))
        //map.frame = rect//CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 300, height: 300))
        self.rect = rect
        super.init(nibName: nil, bundle: nil)
        viewStack = UIStackView(frame: CGRect(origin: CGPoint(x: 72, y: 300), size: CGSize(width: 48, height: 128)))
        self.view.addSubview(map.view)
        self.view.addSubview(viewStack!)
        map.didMove(toParent: self)
        
        
        buttonZoomIn.setTitle("+", for: .normal)
        buttonZoomIn.frame = CGRect(x:32,y: 0,width: 48,height: 56)
        buttonZoomIn.backgroundColor = UIColor.gray
        buttonZoomIn.translatesAutoresizingMaskIntoConstraints = false
        buttonZoomIn.addAction(UIAction(title: "+", handler: { _ in
            self.map.zoomIn(step: 1)
        }), for: .touchUpInside)
        buttonZoomOut.setTitle("-", for: .normal)
        //buttonZoomIn.frame = CGRect(x:0,y:64,width: 48,height: 56)

        buttonZoomOut.backgroundColor = UIColor.gray
        buttonZoomOut.translatesAutoresizingMaskIntoConstraints = false
        buttonZoomOut.addAction(UIAction(title: "-", handler: { _ in
            self.map.zoomOut(step: 1)
        }), for: .touchUpInside)

        viewStack?.alignment = .fill
        viewStack?.distribution = .fillEqually
        viewStack?.spacing = 8.0
        viewStack?.axis = .vertical
        
        viewStack?.addArrangedSubview(buttonZoomIn)
        viewStack?.addArrangedSubview(buttonZoomOut)
       
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //view.addSubview(map.view)
        map.onMapGestureDelegate = self
        map.mapHandlerDelegate = self
        
       
    }
   
    override func viewDidAppear(_ animated: Bool) {
        if !initMap {
            map.initialisationMapWithInitLocation()
            initMap = true
        }
        
        //map.moveTo(location: CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324), zoom: 12, animated: false)
        

        let roadConfig = RoadConfiguration(width:25.0,
                                           color: UIColor(hex: "#ff0000ff") ?? .green,
                                           borderWidth: 15.0,
                                           borderColor: .black,
                                           lineCap:LineCapType.ROUND)
        map.roadManager.addRoad(id: "road1", polylines: [
            CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324),
        CLLocationCoordinate2D(latitude: 47.4433594, longitude: 8.4680184),
        CLLocationCoordinate2D(latitude: 47.4317782, longitude: 8.4716146),
            CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324)
        ], configuration: roadConfig)
        map.roadTapHandlerDelegate = self
        map.userLocationDelegate = self
        /*DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [unowned self] in
            //map.locationManager.requestSingleLocation()
            map.setCustomTile(tile: CustomTiles(["urls":[["url":"https://a.tile-cyclosm.openstreetmap.fr/cyclosm/"]],
                                                 "tileExtension":".png","tileSize":256,"maxZoomLevel":19]))
        }*/
        let iconUserM = MarkerConfiguration(icon: UIImage(systemName: "location")!,
                                            iconSize: MarkerIconSize(x:48,y:48), angle: nil, anchor: nil)
        map.locationManager.setUserLocationIcons(
            userLocationIcons: UserLocationConfiguration(userIcon:iconUserM , directionIcon: iconUserM))
        map.shapeManager.drawShape(key: "rect",
                                   shape: CircleOSM(center:CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324),
                                   distanceInMeter:500,
                                   style:ShapeStyleConfiguration(
                                    filledColor: UIColor.red.withAlphaComponent(CGFloat(0.5)),
                                        borderColor: UIColor.green.withAlphaComponent(CGFloat(1)),
                                        borderWidth: 20
                                     )
                                   )
                                 )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [unowned self] in
            map.shapeManager.deleteShape(ckey: "rect")
            map.locationManager.requestEnableLocation()
            map.locationManager.toggleTracking(configuration: TrackConfiguration(
                moveMap: false,controlUserMarker: false))
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
