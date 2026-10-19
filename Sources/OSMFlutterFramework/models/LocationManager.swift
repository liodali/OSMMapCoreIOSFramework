//
//  LocationManager.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 16.12.23.
//

import CoreLocation
import Foundation
import MapKit

#if compiler(>=5.10)
    /* private */ internal import MapCore
#else
    @_implementationOnly import MapCore
#endif

public struct TrackConfiguration {
    public var moveMap: Bool = false
    public var useDirectionMarker: Bool = false
    public var disableMarkerRotation: Bool = false
    public var controlUserMarker: Bool = true
    public init(
        moveMap: Bool = false, useDirectionMarker: Bool = false,
        disableMarkerRotation: Bool = false, controlUserMarker: Bool = true
    ) {
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

@MainActor
public protocol OSMUserLocationHandler {
    func locationChanged(userLocation: CLLocationCoordinate2D, heading: Double)
    func handlePermission(state: LocationPermission)
}

private class LocationDelegateHandler: NSObject, CLLocationManagerDelegate {
    weak var manager: LocationManager?

    nonisolated func locationManager(
        _ mgr: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard let lm = manager, let location = locations.last else { return }
        #if os(macOS)
        let heading = 0.0
        #else
        let heading = mgr.heading?.trueHeading ?? 0
        #endif
        Task { @MainActor in
            lm.handleLocationUpdate(location: location, heading: heading)
        }
    }

    nonisolated func locationManager(
        _ mgr: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
    ) {
        guard let lm = manager else { return }
        Task { @MainActor in
            lm.handleAuthorizationChange(status: status)
        }
    }

    nonisolated func locationManager(_ mgr: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
}

@MainActor
public class LocationManager: NSObject {
    private var locationManager: CLLocationManager
    private let map: MCMapView
    var userLocationHandler: OSMUserLocationHandler?
    private var isSingleRetrieve = false
    private var enableLocation = false
    private var isTracking = false
    private var updateIcon = false
    public private(set) var userLocationIconConfiguration: UserLocationConfiguration
    private let iconLayer = MCIconLayerInterface.create()
    private var userMarker: Marker?
    private var userMCCoord: MCCoord?
    private var controlMapFromOutSide = false
    private var useDirectionMarker = false
    private var disableMarkerRotation = false
    private var controlUserMarker = true
    private var iconUserMarkerMap: MCIconInfoInterface? = nil
    private let delegateHandler = LocationDelegateHandler()
    init(map: MCMapView, userLocationIcons: UserLocationConfiguration?) {
        self.map = map
        self.locationManager = CLLocationManager()
        self.userLocationIconConfiguration =
            userLocationIcons
            ?? UserLocationConfiguration(
                userIcon: LocationManager.pinIcon(),
                directionIcon: LocationManager.directionIcon()
            )
        super.init()
        delegateHandler.manager = self
        self.locationManager.delegate = delegateHandler
        iconLayer?.setLayerClickable(false)
        self.map.insert(layer: iconLayer?.asLayerInterface(), at: 3)
    }
    isolated deinit {
        locationManager.stopUpdatingLocation()
        #if !os(macOS)
        locationManager.stopUpdatingHeading()
        #endif
        locationManager.delegate = nil
    }

    public func setUserLocationIcons(userLocationIcons: UserLocationConfiguration) {
        self.userLocationIconConfiguration = userLocationIcons
        if userMarker != nil {
            userMarker?.updateMarker(
                newLocation: nil, configuration: userLocationIconConfiguration.userIcon)
        }
        updateIcon = true
    }
    public func requestSingleLocation() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        isSingleRetrieve = true
        checkLocationAuthorization()
    }
    nonisolated static func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        #if os(macOS)
        return status == .authorizedAlways
        #else
        return status == .authorizedAlways || status == .authorizedWhenInUse
        #endif
    }

    func requestLocation() {
        if Self.isAuthorized(locationManager.authorizationStatus) {
            locationManager.requestLocation()
        }
    }

    private func authorizationLocation() -> CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    func checkLocationAuthorization() {
        let status = authorizationLocation()
        if Self.isAuthorized(status) {
            locationManager.requestLocation()
        } else if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            userLocationHandler?.handlePermission(state: .NotGranted)
        }
    }

    public func requestEnableLocation() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        enableLocation = true
        checkLocationAuthorization()
    }
    public func toggleTracking(configuration: TrackConfiguration) {
        if isTracking {
            stopLocation()
            return
        }
        let autorizationLocation = authorizationLocation()
        if autorizationLocation == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if Self.isAuthorized(autorizationLocation) {
            locationManager.startUpdatingLocation()
            #if !os(macOS)
            if CLLocationManager.headingAvailable() { locationManager.startUpdatingHeading() }
            #endif
        } else {
            userLocationHandler?.handlePermission(state: .NotGranted)
            return
        }
        self.controlMapFromOutSide = configuration.moveMap
        #if os(macOS)
        self.useDirectionMarker = false
        #else
        self.useDirectionMarker = configuration.useDirectionMarker
        #endif
        self.disableMarkerRotation = configuration.disableMarkerRotation
        controlUserMarker = configuration.controlUserMarker
        isTracking = true
    }
    public func isTrackingEnabled() -> Bool {
        isTracking
    }
    public func stopLocation() {
        locationManager.stopUpdatingLocation()
        #if !os(macOS)
        locationManager.stopUpdatingHeading()
        #endif
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
    public func moveToUserLocation(animated: Bool = true) {
        if let userMCCoord = userMCCoord {
            self.map.camera.move(toCenterPosition: userMCCoord, animated: animated)
        }

    }
    static func pinIcon() -> MarkerConfiguration {
        let icon = AppleImageUtilities.symbol(named: "mappin", tint: .red)
        return MarkerConfiguration(icon: icon, iconSize: nil, angle: nil, anchor: nil)
    }
    static func directionIcon() -> MarkerConfiguration {
        let icon = AppleImageUtilities.symbol(named: "location.north.fill", tint: .black)
        return MarkerConfiguration(icon: icon, iconSize: nil, angle: nil, anchor: nil)
    }

    private func addUserMakerToMap() {
        iconUserMarkerMap = userMarker?.createMapIcon(mccoord: userMCCoord)!
        iconLayer?.add(iconUserMarkerMap)
    }

    func handleLocationUpdate(location: CLLocation, heading: Double) {
        userMCCoord = location.coordinate.mcCoord
        if let handler = userLocationHandler {
            handler.locationChanged(
                userLocation: location.coordinate, heading: heading
            )
        }
        if !isSingleRetrieve {
            userMCCoord = location.coordinate.mcCoord
            if !controlMapFromOutSide {
                self.map.camera.move(toCenterPosition: userMCCoord!, animated: true)
            }

            if isTracking && controlUserMarker {
                if iconLayer != nil && iconLayer!.getIcons().isEmpty {
                    let iconMarker =
                        if useDirectionMarker && userLocationIconConfiguration.directionIcon != nil
                        {
                            userLocationIconConfiguration.directionIcon!
                        } else {
                            userLocationIconConfiguration.userIcon
                        }

                    userMarker = Marker(
                        location: location.coordinate,
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
                if heading != 0 && !disableMarkerRotation {
                    iconLayer?.remove(iconUserMarkerMap)
                    let configuration = userMarker!.markerConfiguration.copyWith(
                        icon: userLocationIconConfiguration.directionIcon?.icon,
                        iconSize: userLocationIconConfiguration.directionIcon?.iconSize,
                        angle: Float(heading),
                        anchor: userLocationIconConfiguration.directionIcon?.anchor
                    )
                    userMarker?.updateMarker(newLocation: nil, configuration: configuration)
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

    func handleAuthorizationChange(status: CLAuthorizationStatus) {
        if Self.isAuthorized(status)
        {
            if isTracking {
                locationManager.startUpdatingLocation()
                #if !os(macOS)
                if CLLocationManager.headingAvailable() { locationManager.startUpdatingHeading() }
                #endif
            }
            if isSingleRetrieve || enableLocation {
                requestLocation()
            }
            if let handler = userLocationHandler {
                handler.handlePermission(state: LocationPermission.Granted)
            }
        } else if status == CLAuthorizationStatus.denied
            || status == CLAuthorizationStatus.restricted
        {
            if let handler = userLocationHandler {
                handler.handlePermission(state: LocationPermission.NotGranted)
            }
        }
    }

    func setCLLocationManager(locationDelegate: CLLocationManagerDelegate?) {
        self.locationManager.delegate = locationDelegate
    }
    public func setCLLocationManagerToDefault() {
        self.locationManager.delegate = delegateHandler
    }
}
public struct UserLocationConfiguration {
    public private(set) var userIcon: MarkerConfiguration
    public private(set) var directionIcon: MarkerConfiguration?
    public init(userIcon: MarkerConfiguration, directionIcon: MarkerConfiguration?) {
        self.userIcon = userIcon
        self.directionIcon = directionIcon
    }

    public func copyWith(
        userIcon: MarkerConfiguration? = nil, directionIcon: MarkerConfiguration? = nil
    ) -> UserLocationConfiguration {
        return UserLocationConfiguration(
            userIcon: userIcon ?? self.userIcon, directionIcon: directionIcon ?? self.directionIcon)
    }
}
