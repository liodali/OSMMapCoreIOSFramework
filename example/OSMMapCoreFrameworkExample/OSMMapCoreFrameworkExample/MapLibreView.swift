//
//  MapLibreView.swift
//  OSMMapCoreFrameworkExample
//
//  Temporary MapLibre example using the OpenFreeMap Liberty style.
//

import CoreLocation
import MapLibre
import SwiftUI
import UIKit

struct MapLibreView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MapLibreViewController {
        MapLibreViewController()
    }

    func updateUIViewController(_ uiViewController: MapLibreViewController, context: Context) {}
}

class MapLibreViewController: UIViewController {
    private var mapView: MLNMapView?

    override func viewDidLoad() {
        super.viewDidLoad()
        let styleURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")!
        let map = MLNMapView(frame: view.bounds, styleURL: styleURL)
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.setCenter(
            CLLocationCoordinate2D(latitude: 47.4358055, longitude: 8.4737324),
            zoomLevel: 16,
            animated: false
        )
        view.addSubview(map)
        mapView = map
    }
}
