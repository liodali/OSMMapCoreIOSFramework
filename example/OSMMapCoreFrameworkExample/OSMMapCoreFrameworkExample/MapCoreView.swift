//
//  MapCoreView.swift
//  MapOSMSwift
//
//  Created by Dali Hamza on 21.11.23.
//

import CoreLocation
import Foundation
import OSMFlutterFramework
import Polyline
import SwiftUI
import osrm_swift

struct OSMMapView: UIViewControllerRepresentable {
    typealias UIViewControllerType = InnerOSMMapView

    let width, height: Int
    @Binding var controller: InnerOSMMapView?

    init(
        width: Int = 200, height: Int = 200, controller: Binding<InnerOSMMapView?> = .constant(nil)
    ) {
        self.width = width
        self.height = height
        self._controller = controller
    }
    func makeUIViewController(context: Context) -> InnerOSMMapView {
        let view = InnerOSMMapView(
            rect: .init(origin: .zero, size: CGSize(width: width, height: height)))
        DispatchQueue.main.async {
            self.controller = view
        }
        return view
    }

    func updateUIViewController(_ uiViewController: InnerOSMMapView, context: Context) {

    }

}
public func - (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude - rhs.latitude <= 0.0000001 && lhs.longitude - rhs.longitude <= 0.0000001
}
struct MapCoreOSM: View {
    @State private var mapController: InnerOSMMapView?
    @State private var isTracking: Bool = false
    @State private var searchText: String = ""

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                OSMMapView(
                    width: Int(geometry.size.width),
                    height: Int(geometry.size.height),
                    controller: $mapController
                )

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search", text: $searchText)
                            .font(.body)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 56)

                    Spacer()

                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            VStack(spacing: 0) {
                                Button {
                                    mapController?.zoomIn()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .medium))
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.primary)
                                }
                                Divider()
                                    .frame(width: 24)
                                Button {
                                    mapController?.zoomOut()
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 18, weight: .medium))
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.primary)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            )

                            Button {
                                mapController?.toggleTracking()
                                isTracking = mapController?.isTracking() ?? false
                            } label: {
                                Image(systemName: isTracking ? "location.fill" : "location")
                                    .font(.system(size: 18))
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.blue)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            )
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}
class InnerOSMMapView: UIViewController, OnMapGesture, OSMUserLocationHandler, PoylineHandler,
    MapMarkerHandler
{
    func onMarkerSingleTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [unowned self] in
            do {
                self.map.markerManager.removeMarker(location: location)
                let searchedLocation = try self.locations.first(where: {
                    (l: CLLocationCoordinate2D) -> Bool in
                    return try l.isEqual(rhs: location, precision: 1e6)
                })
                if searchedLocation != nil {
                    self.map.markerManager.removeMarker(location: searchedLocation!)
                    let isEq = try self.location!.isEqual(rhs: searchedLocation!)
                    if self.location != nil && isEq {
                        self.location = nil
                    }
                }

            } catch {

            }

        }
    }

    func onMarkerLongPress(location: CLLocationCoordinate2D) {

    }

    var location: CLLocationCoordinate2D? = nil
    var locations: [CLLocationCoordinate2D] = [CLLocationCoordinate2D]()

    func onTap(roadId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [unowned self] in
            map.roadManager.removeRoad(id: roadId)
        }
    }

    func locationChanged(userLocation: CLLocationCoordinate2D, heading: Double) {
        print("\(userLocation),\(heading)")
        self.map.moveTo(location: userLocation, zoom: nil, animated: true)
    }

    func handlePermission(state: OSMFlutterFramework.LocationPermission) {
        print("\(state)")
    }

    func onSingleTap(location: CLLocationCoordinate2D) {
        if geos.count < 2 {
            let image = UIImage(systemName: "mappin")
            let nImage = resizeImage(image: image!, targetSize: CGSize(width: 48, height: 56))
            let xImage = nImage?.size.width ?? CGFloat(48)
            let yImage = nImage?.size.height ?? CGFloat(56)
            let marker = Marker(
                location: location,
                markerConfiguration: MarkerConfiguration(
                    icon: image!,
                    iconSize: (
                        x: Int(xImage * UIScreen.main.nativeScale),
                        y: Int(yImage * UIScreen.main.nativeScale)
                    ),
                    //(x:Int(56.0 * UIScreen.main.nativeScale),y:Int(56.0 * UIScreen.main.nativeScale)),
                    angle: nil,
                    anchor: (0.5, 1)  // (0.5,0.5))
                )
            )
            self.map.markerManager.addMarker(marker: marker)
            let steLoc = "\(location)"
            self.location = location

            geos.append(location)
        }

        if geos.count >= 2 && alert == nil {
            self.showRoadTypeActionDialog()
        }
    }
    func showWaitingDialog() {
        Task.detached { @MainActor in
            self.alert = UIAlertController(
                title: nil, message: "Please wait...", preferredStyle: .alert)
            let loadingIndicator = UIActivityIndicatorView(
                frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.style = UIActivityIndicatorView.Style.medium
            loadingIndicator.startAnimating()
            self.alert!.view.addSubview(loadingIndicator)
            self.present(self.alert!, animated: true, completion: nil)
        }
    }
    func showRoadTypeActionDialog() {
        Task.detached { @MainActor in
            let actionSheetController = UIAlertController(
                title: "Select Road Type", message: "Choose an road", preferredStyle: .actionSheet)

            let action1 = UIAlertAction(title: "Car", style: .default) { _ in
                self.drawRoad()
            }

            let action2 = UIAlertAction(title: "Foot", style: .destructive) { _ in
                actionSheetController.dismiss(animated: true)
                self.drawRoad(roadType: RoadType.foot)
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                actionSheetController.dismiss(animated: true)
                self.geos.removeAll()
            }

            actionSheetController.addAction(action1)
            actionSheetController.addAction(action2)
            actionSheetController.addAction(cancelAction)

            self.present(actionSheetController, animated: true, completion: nil)
        }
    }

    func drawRoad(roadType: RoadType = RoadType.car) {
        DispatchQueue.global().async {
            Task {
                let result = await self.osrmManager.getRoadAsync(
                    wayPoints: self.geos, configuration: InputRoadConfiguration(typeRoad: roadType))
                if result != nil {
                    let polyline = Polyline(encodedPolyline: result!.mRouteHigh)
                    Task.detached { @MainActor in
                        self.map.roadManager.addRoad(
                            id: "1", polylines: polyline.coordinates!,
                            configuration: RoadConfiguration(
                                width: 25.0, color: UIColor.red, polylineType: PolylineType.DOT))
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

    func onLongTap(location: CLLocationCoordinate2D) {
        self.map.markerManager.removeMarker(location: location)
    }

    let map: OSMView
    let osrmManager: OSRMManager
    var alert: UIAlertController? = nil
    var geos: [CLLocationCoordinate2D] = []
    var initMap: Bool = false
    let rect: CGRect
    let zoomConf = ZoomConfiguration(initZoom: 16, minZoom: 1, maxZoom: 19)
    let initLoc = CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324)
    var zoomL = 16
    public init(rect: CGRect) {
        self.map = OSMView(
            rect: rect,
            location: initLoc,
            zoomConfig: zoomConf)

        //map.frame = rect//CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 300, height: 300))
        self.rect = rect
        self.osrmManager = try! OSRMManager()
        super.init(nibName: nil, bundle: nil)
        //map.frame = rect
        self.view.addSubview(self.map)
    }

    func zoomIn() {
        self.map.zoomIn(step: 1)
    }

    func zoomOut() {
        self.map.zoomOut(step: 1)
    }

    func isTracking() -> Bool {
        return self.map.locationManager.isTrackingEnabled()
    }

    func toggleTracking() {
        self.map.locationManager.toggleTracking(
            configuration: TrackConfiguration(moveMap: false, controlUserMarker: false))
    }

    func removeAllMarkers() {
        for geo in self.geos {
            self.map.markerManager.removeMarker(location: geo)
        }
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

        map.roadTapHandlerDelegate = self
        map.userLocationDelegate = self

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [unowned self] in
            print("current zoom \(map.zoom())")
            //self.map.setBoundingBox(bounds: BoundingBox(center: CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324), distanceKm: 0.1))

            let iconUserM = MarkerConfiguration(
                icon: UIImage(systemName: "location")!,
                iconSize: MarkerIconSize(x: 48, y: 48),
                angle: nil,
                anchor: nil
            )
            self.map.markerManager.addMarker(
                marker: Marker(
                    location: CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324),
                    markerConfiguration: iconUserM
                )
            )
            //map.shapeManager.deleteShape(ckey: "circle")
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

    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        // Create a new image context with the target size
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)

        // Draw the original image into the new context
        image.draw(in: CGRect(origin: .zero, size: targetSize))

        // Extract the new image from the context
        let newImage = UIGraphicsGetImageFromCurrentImageContext()

        // End the context
        UIGraphicsEndImageContext()

        return newImage
    }
}
extension UIColor {
    public convenience init?(hex: String) {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff00_0000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff_0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000_ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x0000_00ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            } else if hexColor.count == 6 {
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
