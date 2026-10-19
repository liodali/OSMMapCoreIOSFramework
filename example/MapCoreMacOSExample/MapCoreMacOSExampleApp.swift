import AppKit
import Combine
import CoreLocation
import OSMFlutterFramework
import SwiftUI

@main
struct MapCoreMacOSExampleApp: App {
    var body: some Scene {
        WindowGroup("OSMFlutterFramework — Native macOS") { NativeMapContentView() }
    }
}

private enum NativeMapStyle: String, CaseIterable {
    case vector = "Vector"
    case raster = "Raster"
}

@MainActor
private struct NativeMapContentView: View {
    @StateObject private var model = NativeMapModel()
    private let refresh = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(NativeMapStyle.allCases, id: \.self) { style in
                    Button { model.select(style) } label: {
                        Label("\(style.rawValue) tiles", systemImage: model.style == style ? "checkmark.circle.fill" : "circle")
                    }.disabled(model.style == style)
                }
                Toggle("Map input", isOn: $model.acceptsInput)
                    .onChange(of: model.acceptsInput) { $0 ? model.map.enableTouch() : model.map.disableTouch() }
                Spacer()
                Button("My Location") { model.map.locationManager.requestSingleLocation() }
            }
            .buttonStyle(.bordered)
            .padding(10)
            Divider()
            NativeMapView(map: model.map)
                .id(ObjectIdentifier(model.map))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    HStack {
                        if model.style == .vector {
                            Link("OpenFreeMap", destination: URL(string: "https://openfreemap.org")!)
                            Link("© OpenMapTiles", destination: URL(string: "https://openmaptiles.org")!)
                        }
                        Link("© OpenStreetMap", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    }.font(.caption).padding(6).background(.regularMaterial).padding(8)
                }
            Divider()
            HStack {
                Text(model.event)
                Spacer()
                Text(model.position).monospacedDigit()
            }.font(.caption).padding(10)
        }
        .frame(minWidth: 850, idealWidth: 1000, minHeight: 550, idealHeight: 700)
        .toolbar {
            Button("Zurich") { model.home() }
            Button("Zoom In") { model.map.zoomIn() }
            Button("Zoom Out") { model.map.zoomOut() }
            Button("Rotate") { model.map.setRotation(angle: 45) }
            Button("Reset Rotation") { model.map.setRotation(angle: 0) }
            Button("Recreate Map") { model.recreate() }
        }
        .onAppear { model.connect() }
        .onDisappear { model.disconnect() }
        .onReceive(refresh) { _ in model.refreshPosition() }
    }
}

private struct NativeMapView: NSViewRepresentable {
    let map: OSMView
    func makeNSView(context: Context) -> OSMView { map }
    func updateNSView(_ nsView: OSMView, context: Context) {}
}

@MainActor
private final class NativeMapModel: ObservableObject, OnMapGesture, MapMarkerHandler, PoylineHandler, OSMUserLocationHandler {
    @Published private(set) var map: OSMView
    @Published private(set) var style = NativeMapStyle.vector
    @Published private(set) var position = ""
    @Published private(set) var event = "Click a marker or road · Drag to pan · Scroll to zoom"
    @Published var acceptsInput = true
    private static let zurich = CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417)

    init() {
        map = Self.makeMap()
        configure()
        if ProcessInfo.processInfo.arguments.contains("--smoke-test") {
            Task { await runSmokeTest() }
        }
    }

    private func runSmokeTest() async {
        func settle() async { try? await Task.sleep(nanoseconds: 3_000_000_000) }
        NSLog("Native wrapper smoke: vector map and demo overlays created")
        await settle()
        select(.raster)
        NSLog("Native wrapper smoke: switched to raster")
        await settle()
        map.moveTo(location: CLLocationCoordinate2D(latitude: 47.38, longitude: 8.548), zoom: 16, animated: false)
        await settle()
        let center = map.center()
        guard abs(center.latitude - 47.38) < 0.0001,
              abs(center.longitude - 8.548) < 0.0001, map.zoom() == 16 else {
            NSLog("Native wrapper smoke FAILED: camera command/query mismatch")
            return
        }
        map.setRotation(angle: 45, animated: false)
        acceptsInput = false
        map.disableTouch()
        map.setZoom(zoom: 15, animated: false)
        await settle()
        let hitPoint = NSPoint(x: map.frame.midX, y: map.frame.midY)
        guard map.zoom() == 15, map.hitTest(hitPoint) == nil else {
            NSLog("Native wrapper smoke FAILED: static input/camera behavior")
            return
        }
        acceptsInput = true
        map.enableTouch()
        select(.vector)
        NSLog("Native wrapper smoke: rotation, static mode and vector switch completed")
        await settle()
        weak var previousMap = map
        recreate()
        await settle()
        guard previousMap == nil else {
            NSLog("Native wrapper smoke FAILED: replaced OSMView is still retained")
            return
        }
        NSLog("Native wrapper smoke PASSED: camera, tile switches, input and view recreation; visual rendering still needs confirmation")
    }

    private static func tiles(_ style: NativeMapStyle) -> CustomTiles {
        if style == .vector {
            return CustomTiles(["isVector": true, "styleURL": "https://tiles.openfreemap.org/styles/liberty"])
        }
        return CustomTiles(["urls": [["url": "https://tile.openstreetmap.org/{z}/{x}/{y}"]], "tileExtension": ".png"])
    }

    private static func makeMap() -> OSMView {
        OSMView(rect: CGRect(x: 0, y: 0, width: 900, height: 500), location: zurich,
                zoomConfig: ZoomConfiguration(initZoom: 14, minZoom: 0, maxZoom: 19), tile: tiles(.vector))
    }

    func connect() {
        map.onMapGestureDelegate = self
        map.mapHandlerDelegate = self
        map.roadTapHandlerDelegate = self
        map.userLocationDelegate = self
    }

    private func configure() {
        connect()
        let image = NSImage(systemSymbolName: "mappin.circle.fill", accessibilityDescription: "Demo marker")!
        image.size = NSSize(width: 28, height: 28)
        map.markerManager.addMarker(marker: Marker(location: Self.zurich,
            markerConfiguration: MarkerConfiguration(icon: image, iconSize: (28, 28), angle: nil, anchor: nil)))
        let nearby = CLLocationCoordinate2D(latitude: 47.3800, longitude: 8.5480)
        map.poisManager.setOrCreateIconPoi(id: "demo-pois", icon: image, iconSize: (24, 24))
        map.poisManager.setMarkersPoi(id: "demo-pois", markers: [MarkerIconPoi(location: nearby, angle: nil, anchor: nil)])
        map.roadManager.addRoad(id: "demo-road", polylines: [Self.zurich, nearby],
            configuration: RoadConfiguration(width: 5, color: .systemBlue, borderWidth: 2, borderColor: .white))
        map.shapeManager.drawShape(key: "demo-circle", shape: CircleOSM(
            center: CLLocationCoordinate2D(latitude: 47.373, longitude: 8.535), distanceInMeter: 180,
            style: ShapeStyleConfiguration(filledColor: NSColor.systemGreen.withAlphaComponent(0.25), borderColor: .systemGreen, borderWidth: 2)))
    }

    func select(_ style: NativeMapStyle) {
        self.style = style
        map.setCustomTile(tile: Self.tiles(style))
    }

    func home() { map.moveTo(location: Self.zurich, zoom: 14, animated: true) }
    func refreshPosition() {
        let center = map.center()
        position = String(format: "%.5f, %.5f · Zoom %d", center.latitude, center.longitude, map.zoom())
    }

    func disconnect() {
        map.onMapGestureDelegate = nil
        map.mapHandlerDelegate = nil
        map.roadTapHandlerDelegate = nil
        map.userLocationDelegate = nil
        map.locationManager.stopLocation()
    }

    func recreate() {
        disconnect()
        map = Self.makeMap()
        style = .vector
        acceptsInput = true
        configure()
    }

    nonisolated func onSingleTap(location: CLLocationCoordinate2D) { report("Map clicked") }
    nonisolated func onLongTap(location: CLLocationCoordinate2D) { report("Map long press") }
    nonisolated func onMarkerSingleTap(location: CLLocationCoordinate2D) { report("Marker clicked") }
    nonisolated func onMarkerLongPress(location: CLLocationCoordinate2D) { report("Marker long press") }
    nonisolated func onTap(roadId: String) { report("Road clicked") }
    private nonisolated func report(_ message: String) {
        Task { @MainActor [weak self] in self?.event = message }
    }
    func locationChanged(userLocation: CLLocationCoordinate2D, heading: Double) {
        event = "Location received (heading \(heading))"
        map.moveTo(location: userLocation, zoom: nil, animated: true)
    }
    func handlePermission(state: LocationPermission) { event = "Location permission: \(state)" }
}
