//
//  LocationManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 16.12.23.
//

import Foundation
import CoreLocation
@_implementationOnly import MapCore
import MapKit



public enum LocationPermission {
    case Granted
    case NotGranted
}
public protocol OSMUserLocationHandler {
    func locationChanged(userLocation:CLLocationCoordinate2D)
    func handlePermission(state:LocationPermission)
}
public class LocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager
    private let map: MCMapView
    var userLocationHandler:OSMUserLocationHandler?
    private var isSingleRetrieve = false
    private var enableLocation = false
    private var isTracking = false
    private var userLocationIcons:UserLocationConfiguration
    private let iconLayer = MCIconLayerInterface.create()
    private var userMarker:Marker?
    private var controlMapFromOutSide = false
    init(map: MCMapView,userLocationIcons:UserLocationConfiguration?) {
        self.map = map
        self.locationManager = CLLocationManager()
        self.userLocationIcons = userLocationIcons ?? UserLocationConfiguration(
            userIcon: LocationManager.pinIcon(),
            directionIcon: LocationManager.directionIcon()
        )
        super.init()
        self.locationManager.delegate = self
        iconLayer?.setLayerClickable(false)
        self.map.insert(layer: iconLayer?.asLayerInterface(), at: 3)
    }
    public func setUserLocationIcons(userLocationIcons:UserLocationConfiguration) {
        self.userLocationIcons = userLocationIcons
    }
    public func requestSingleLocation() {
           checkLocationAuthorization()
           // Start location updates
           locationManager.desiredAccuracy = kCLLocationAccuracyBest
           isSingleRetrieve = true
    }
    func requestLocation() {
        if #available(iOS 14.0, *) {
            if(locationManager.authorizationStatus == CLAuthorizationStatus.authorizedWhenInUse 
               || locationManager.authorizationStatus == CLAuthorizationStatus.authorizedAlways ) {
                locationManager.requestLocation()
            }
        } else {
            if(CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse
               || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways ) {
                locationManager.requestLocation()
            }
        }
    }
    
    func checkLocationAuthorization() {
        if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways
            || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse {
            locationManager.requestLocation()
        }else {
            locationManager.requestWhenInUseAuthorization() // Request permission
        }
    }
  
    public func requestEnableLocation() {
        checkLocationAuthorization()// Request permission
        // Start location updates
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        enableLocation = true
    }
    public func toggleTracking(controlMapFromOutSide:Bool = false) {
        isTracking = !isTracking
        if !isTracking {
            stopLocation()
        }else {
            if CLLocationManager.authorizationStatus() == .notDetermined {
                        locationManager.requestWhenInUseAuthorization()
            }else {
                locationManager.startUpdatingLocation()
                locationManager.startUpdatingHeading()
            }
            self.controlMapFromOutSide = controlMapFromOutSide
        }
    }
    public func isTrackingEnabled()-> Bool {
        isTracking
    }
    public func stopLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        isSingleRetrieve = false
        isTracking = false
        iconLayer?.clear()
        iconLayer?.invalidate()
        userMarker = nil
        self.controlMapFromOutSide = false
        enableLocation = false
    }
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locations.last != nil && locations.last?.coordinate != nil && !isSingleRetrieve {
            let mccoord = locations.last!.coordinate.toMCCoordEpsg3857()
            if (!controlMapFromOutSide){
                self.map.camera.move(toCenterPosition: mccoord, animated: true)
            }
            if isTracking {
                if iconLayer != nil && iconLayer!.getIcons().isEmpty {
                    userMarker = Marker(location: locations.last!.coordinate, 
                                        markerConfiguration: MarkerConfiguration(
                                            icon: userLocationIcons.userIcon.icon, iconSize: userLocationIcons.userIcon.iconSize, angle: nil, anchor: userLocationIcons.userIcon.anchor
                                        )
                    )
                    iconLayer?.add(userMarker?.createMapIcon()!)
                }
                let angle = manager.heading?.trueHeading
                if (angle != nil && angle != 0) {
                    let configuration = userMarker!.markerConfiguration.copyWith(icon: userLocationIcons.directionIcon?.icon,
                                                                                 iconSize: userLocationIcons.directionIcon?.iconSize,
                                                                                 angle: Float(angle!), anchor:
                                                                                userLocationIcons.directionIcon?.anchor)
                    userMarker?.updateMarker(newLocation:nil, configuration: configuration)
                }
                iconLayer?.getIcons().first?.setCoordinate(mccoord)
            }
        }
        if let handler = userLocationHandler, locations.last != nil && locations.last?.coordinate != nil {
            handler.locationChanged(userLocation: locations.last!.coordinate)
        }
        if isSingleRetrieve {
            isSingleRetrieve = false
        }
    }
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

        if status == CLAuthorizationStatus.authorizedWhenInUse || status == CLAuthorizationStatus.authorizedAlways  {
            if isTracking {
                locationManager.startUpdatingLocation()
                locationManager.startUpdatingHeading()
            }
            if isSingleRetrieve || enableLocation {
                requestLocation()
            }
            if  let handler = userLocationHandler {
                handler.handlePermission(state: LocationPermission.Granted)
            }
        }else if status == CLAuthorizationStatus.denied || status == CLAuthorizationStatus.restricted {
            if  let handler = userLocationHandler {
                handler.handlePermission(state: LocationPermission.NotGranted)
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
        if  userLocationHandler != nil {
            
        }
    }
     static func pinIcon() -> MarkerConfiguration {
         let icon = (UIImage(systemName: "mappin") ?? UIImage()).withTintColor(.red)
         return MarkerConfiguration(icon: icon, iconSize: nil, angle: nil, anchor: nil)
       }
     static func directionIcon() -> MarkerConfiguration {
         let icon = (UIImage(systemName: "location.north.fill") ?? UIImage()).withTintColor(.black)
        return MarkerConfiguration(icon: icon, iconSize: nil, angle: nil, anchor: nil)
       }

}
public struct UserLocationConfiguration {
    let userIcon:MarkerConfiguration
    let directionIcon:MarkerConfiguration?
    public init(userIcon: MarkerConfiguration , directionIcon: MarkerConfiguration?) {
        self.userIcon = userIcon
        self.directionIcon = directionIcon
    }
}
