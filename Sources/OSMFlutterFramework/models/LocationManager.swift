//
//  LocationManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 16.12.23.
//

import Foundation
import CoreLocation
import MapKit
#if compiler(>=5.10)
/* private */ internal import MapCore
#else
@_implementationOnly import MapCore
#endif

public struct TrackConfiguration {
    public var moveMap:Bool = false
    public var useDirectionMarker:Bool = false
    public var disableMarkerRotation:Bool = false
    public var controlUserMarker:Bool = true
    public init(moveMap: Bool = false, useDirectionMarker: Bool = false, disableMarkerRotation: Bool = false, controlUserMarker: Bool = true) {
        self.moveMap = moveMap
        self.useDirectionMarker = useDirectionMarker
        self.disableMarkerRotation = disableMarkerRotation
        self.controlUserMarker = controlUserMarker
    }
}

public enum LocationPermission {
    case Granted
    case NotGranted
}
public protocol OSMUserLocationHandler {
    func locationChanged(userLocation:CLLocationCoordinate2D,heading:Double)
    func handlePermission(state:LocationPermission)
}
public class LocationManager: NSObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager
    private let map: MCMapView
    var userLocationHandler:OSMUserLocationHandler?
    private var isSingleRetrieve = false
    private var enableLocation = false
    private var isTracking = false
    private var updateIcon = false
    public private(set) var userLocationIconConfiguration:UserLocationConfiguration
    private let iconLayer = MCIconLayerInterface.create()
    private var userMarker:Marker?
    private var userMCCoord:MCCoord?
    private var controlMapFromOutSide = false
    private var useDirectionMarker = false
    private var disableMarkerRotation = false
    private var controlUserMarker = true
    private var iconUserMarkerMap:MCIconInfoInterface? = nil
    init(map: MCMapView,userLocationIcons:UserLocationConfiguration?) {
        self.map = map
        self.locationManager = CLLocationManager()
        self.userLocationIconConfiguration = userLocationIcons ?? UserLocationConfiguration(
            userIcon: LocationManager.pinIcon(),
            directionIcon: LocationManager.directionIcon()
        )
        super.init()
        self.locationManager.delegate = self
        iconLayer?.setLayerClickable(false)
        self.map.insert(layer: iconLayer?.asLayerInterface(), at: 3)
    }
    public func setUserLocationIcons(userLocationIcons:UserLocationConfiguration) {
        self.userLocationIconConfiguration = userLocationIcons
        if userMarker != nil {
            userMarker?.updateMarker(newLocation: nil, configuration: userLocationIconConfiguration.userIcon)
        }
        updateIcon = true
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
    public func toggleTracking(configuration:TrackConfiguration) {
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
            self.controlMapFromOutSide = configuration.moveMap
            self.useDirectionMarker = configuration.useDirectionMarker
            self.disableMarkerRotation = configuration.disableMarkerRotation
            controlUserMarker = configuration.controlUserMarker
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
        self.disableMarkerRotation = false
        enableLocation = false
        self.useDirectionMarker = false
        controlUserMarker = true
    }
    public func moveToUserLocation(animated:Bool = true){
        if let userMCCoord = userMCCoord {
            self.map.camera.move(toCenterPosition: userMCCoord, animated: animated)
        }
        
    }
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if let handler = userLocationHandler, locations.last != nil && locations.last?.coordinate != nil {
            if userMCCoord == nil || userMCCoord != locations.last!.coordinate.mcCoord {
                userMCCoord = locations.last!.coordinate.mcCoord
            }
            handler.locationChanged(userLocation: locations.last!.coordinate,heading: manager.heading?.trueHeading ?? 0)
        }
        if locations.last != nil && locations.last?.coordinate != nil && !isSingleRetrieve {
            userMCCoord = locations.last!.coordinate.mcCoord
            if (!controlMapFromOutSide){
                self.map.camera.move(toCenterPosition: userMCCoord!, animated: true)
            }
            
            if isTracking && controlUserMarker {
                if iconLayer != nil && iconLayer!.getIcons().isEmpty {
                    let iconMarker = if (useDirectionMarker && userLocationIconConfiguration.directionIcon != nil) {
                        userLocationIconConfiguration.directionIcon!
                    }  else  {
                        userLocationIconConfiguration.userIcon
                    }
                    
                    userMarker = Marker(location: locations.last!.coordinate,
                                        markerConfiguration: MarkerConfiguration(
                                            icon: iconMarker.icon,
                                            iconSize: iconMarker.iconSize,
                                            angle: nil,
                                            anchor: userLocationIconConfiguration.userIcon.anchor
                                        )
                    )
                    addUserMakerToMap()
                }
                if updateIcon {
                    iconLayer?.remove(iconUserMarkerMap)
                    updateIcon = false
                }
                let angle = manager.heading?.trueHeading
                if (angle != nil && angle != 0 && !disableMarkerRotation) {
                    iconLayer?.remove(iconUserMarkerMap)
                    let configuration = userMarker!.markerConfiguration.copyWith(
                        icon: userLocationIconConfiguration.directionIcon?.icon,
                        iconSize: userLocationIconConfiguration.directionIcon?.iconSize,
                        angle: Float(angle!),
                        anchor: userLocationIconConfiguration.directionIcon?.anchor
                    )
                    userMarker?.updateMarker(newLocation:nil, configuration: configuration)
                    addUserMakerToMap()
                }
                iconLayer?.getIcons().first?.setCoordinate(userMCCoord!)
                iconLayer?.invalidate()
                map.invalidate()
            }
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
    
    private func addUserMakerToMap() {
        iconUserMarkerMap = userMarker?.createMapIcon(mccoord: userMCCoord)!
        iconLayer?.add(iconUserMarkerMap)
    }

}
extension LocationManager {
    func setCLLocationManager(locationDelegate:CLLocationManagerDelegate?){
        self.locationManager.delegate = locationDelegate
    }
    public func setCLLocationManagerToDefault(){
        self.locationManager.delegate = self
    }
}
public struct UserLocationConfiguration {
    public private(set) var userIcon:MarkerConfiguration
    public private(set) var directionIcon:MarkerConfiguration?
    public init(userIcon: MarkerConfiguration , directionIcon: MarkerConfiguration?) {
        self.userIcon = userIcon
        self.directionIcon = directionIcon
    }
    
    public func copyWith(userIcon: MarkerConfiguration? = nil, directionIcon: MarkerConfiguration? = nil) -> UserLocationConfiguration{
        return UserLocationConfiguration(userIcon: userIcon ?? self.userIcon, directionIcon: directionIcon ?? self.directionIcon)
    }
}
