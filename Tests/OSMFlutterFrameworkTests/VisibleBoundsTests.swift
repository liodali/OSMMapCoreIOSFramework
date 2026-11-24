import XCTest
import CoreGraphics
import CoreLocation
import Metal
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import OSMFlutterFramework

@MainActor
final class VisibleBoundsTests: XCTestCase {
    func testZeroSizeViewDoesNotInventVisibleExtent() async throws {
        try skipWithoutMapCoreRenderingResources()
        let center = CLLocationCoordinate2D(latitude: 48, longitude: 6)
        let map = OSMView(rect: .zero, location: center, zoomConfig: ZoomConfiguration(initZoom: 12))

        let bounds = map.getBoundingBox()
        assertFinite(bounds)
        XCTAssertEqual(bounds.north, center.latitude, accuracy: 0.000_001)
        XCTAssertEqual(bounds.south, center.latitude, accuracy: 0.000_001)
        XCTAssertEqual(bounds.east, center.longitude, accuracy: 0.000_001)
        XCTAssertEqual(bounds.west, center.longitude, accuracy: 0.000_001)
    }

    func testInitialZoomDoesNotOverrideImmediateExplicitZoom() async throws {
        try skipWithoutMapCoreRenderingResources()
        let map = OSMView(
            rect: CGRect(x: 0, y: 0, width: 640, height: 480), location: nil,
            zoomConfig: ZoomConfiguration(initZoom: 12))

        XCTAssertEqual(map.zoom(), 12)
        map.setZoom(zoom: 15, animated: false)
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(map.zoom(), 15)
    }

    func testAntimeridianViewportWrapsProjectedLongitudeEndpoints() async throws {
        try skipWithoutMapCoreRenderingResources()
        let center = CLLocationCoordinate2D(latitude: 48, longitude: 179.99)
        let map = OSMView(
            rect: CGRect(x: 0, y: 0, width: 640, height: 480), location: center,
            zoomConfig: ZoomConfiguration(initZoom: 14))

        let bounds = map.getBoundingBox()
        assertFinite(bounds)
        XCTAssertGreaterThan(bounds.north, bounds.south)
        XCTAssertGreaterThan(bounds.west, 0)
        XCTAssertLessThan(bounds.east, 0)
        XCTAssertLessThan(bounds.east, bounds.west)
        XCTAssertTrue(center.latitude >= bounds.south && center.latitude <= bounds.north)
        XCTAssertTrue(center.longitude >= bounds.west || center.longitude <= bounds.east)
    }

    func testLaidOutVisibleBoundsTrackCameraViewportAndCallbacks() async throws {
        try skipWithoutMapCoreRenderingResources()
        let initialCenter = CLLocationCoordinate2D(latitude: 48, longitude: 6)
        let map = OSMView(
            rect: CGRect(x: 0, y: 0, width: 640, height: 480), location: initialCenter,
            zoomConfig: ZoomConfiguration(initZoom: 12))
        let recorder = MapMoveRecorder()
        map.onMapMove = recorder
        defer { map.onMapMove = nil }

        // Exercise the camera/viewport pipeline without requiring a WindowServer.
        #if os(macOS)
        map.layout()
        #else
        map.layoutIfNeeded()
        #endif

        let initial = await waitForPositiveVisibleBounds(on: map)
        assertVisible(initial, contains: initialCenter)
        await waitForCallback(matching: initial, on: map, recorder: recorder)

        let pannedCenter = CLLocationCoordinate2D(latitude: 48.01, longitude: 6.02)
        map.moveTo(location: pannedCenter, zoom: nil, animated: false)
        let panned = await waitForPositiveVisibleBounds(on: map, center: pannedCenter)
        assertVisible(panned, contains: pannedCenter)
        XCTAssertNotEqual(panned.north, initial.north)
        XCTAssertNotEqual(panned.east, initial.east)
        await waitForCallback(matching: panned, on: map, recorder: recorder)

        map.setZoom(zoom: 13, animated: false)
        let zoomed = await waitForVisibleExtentChange(on: map, from: panned, smaller: true)
        assertVisible(zoomed, contains: pannedCenter)
        await waitForCallback(matching: zoomed, on: map, recorder: recorder)

        #if os(macOS)
        map.setFrameSize(NSSize(width: 480, height: 360))
        map.layout()
        #else
        map.frame = CGRect(x: 0, y: 0, width: 480, height: 360)
        map.layoutIfNeeded()
        #endif
        let resized = await waitForVisibleExtentChange(on: map, from: zoomed, smaller: true)
        assertVisible(resized, contains: pannedCenter)
        await waitForCallback(matching: resized, on: map, recorder: recorder)

        map.enableRotation(enable: true)
        map.setRotation(angle: 45, animated: false)
        let rotated = await waitForVisibleExtentChange(on: map, from: resized, smaller: false)
        assertVisible(rotated, contains: pannedCenter)
        await waitForCallback(matching: rotated, on: map, recorder: recorder)
    }

    private func waitForPositiveVisibleBounds(
        on map: OSMView, center: CLLocationCoordinate2D? = nil
    ) async -> BoundingBox {
        var bounds = map.getBoundingBox()
        for _ in 0..<200 {
            bounds = map.getBoundingBox()
            let currentCenter = center ?? map.center()
            if isPositive(bounds), contains(currentCenter, in: bounds) {
                return bounds
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Rendered viewport did not produce positive visible bounds containing its center: \(bounds.toMap())")
        return bounds
    }

    private func waitForVisibleExtentChange(
        on map: OSMView, from previous: BoundingBox, smaller: Bool
    ) async -> BoundingBox {
        var bounds = map.getBoundingBox()
        for _ in 0..<200 {
            bounds = map.getBoundingBox()
            let latitudeExtent = bounds.north - bounds.south
            let previousLatitudeExtent = previous.north - previous.south
            let changed = smaller ? latitudeExtent < previousLatitudeExtent * 0.95 : latitudeExtent > previousLatitudeExtent * 1.05
            if isPositive(bounds), changed, contains(map.center(), in: bounds) {
                return bounds
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Visible extent did not follow the camera/viewport change: previous=\(previous.toMap()) current=\(bounds.toMap())")
        return bounds
    }

    private func waitForCallback(
        matching expected: BoundingBox, on map: OSMView, recorder: MapMoveRecorder
    ) async {
        for _ in 0..<200 {
            if let last = recorder.moves.last,
               approximatelyEqual(last.bounds, expected),
               approximatelyEqual(last.center, map.center()) {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        let actual = recorder.moves.last?.bounds.toMap() ?? [:]
        XCTFail("Last callback did not match the settled visible-bounds query: callback=\(actual) query=\(expected.toMap())")
    }

    private func assertVisible(
        _ bounds: BoundingBox, contains center: CLLocationCoordinate2D,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        assertFinite(bounds, file: file, line: line)
        XCTAssertTrue(isPositive(bounds), "Expected a non-zero viewport, got \(bounds.toMap())", file: file, line: line)
        XCTAssertTrue(contains(center, in: bounds), "Expected \(bounds.toMap()) to contain \(center)", file: file, line: line)
    }

    private func assertFinite(
        _ bounds: BoundingBox, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(bounds.north.isFinite, file: file, line: line)
        XCTAssertTrue(bounds.south.isFinite, file: file, line: line)
        XCTAssertTrue(bounds.east.isFinite, file: file, line: line)
        XCTAssertTrue(bounds.west.isFinite, file: file, line: line)
    }

    private func isPositive(_ bounds: BoundingBox) -> Bool {
        bounds.north.isFinite && bounds.south.isFinite && bounds.east.isFinite && bounds.west.isFinite
            && bounds.north > bounds.south && bounds.east > bounds.west
    }

    private func contains(_ center: CLLocationCoordinate2D, in bounds: BoundingBox) -> Bool {
        center.latitude >= bounds.south && center.latitude <= bounds.north
            && center.longitude >= bounds.west && center.longitude <= bounds.east
    }

    private func approximatelyEqual(_ lhs: BoundingBox, _ rhs: BoundingBox) -> Bool {
        abs(lhs.north - rhs.north) < 0.000_001 && abs(lhs.south - rhs.south) < 0.000_001
            && abs(lhs.east - rhs.east) < 0.000_001 && abs(lhs.west - rhs.west) < 0.000_001
    }

    private func approximatelyEqual(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.000_001 && abs(lhs.longitude - rhs.longitude) < 0.000_001
    }

    private func skipWithoutMapCoreRenderingResources() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "MapCore requires Metal")
        // swift test copies .metal sources; Xcode compiles the engine's metallib.
        let products = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        let libraries = ["MapCore_MapCore.bundle/default.metallib",
                         "MapCore_MapCore.bundle/Contents/Resources/default.metallib"]
        try XCTSkipUnless(libraries.contains {
            FileManager.default.fileExists(atPath: products.appendingPathComponent($0).path)
        }, "Run rendered visible-bounds checks with Xcode-compiled Metal resources")
    }
}

private final class MapMoveRecorder: OnMapMoved {
    struct Move {
        let center: CLLocationCoordinate2D
        let bounds: BoundingBox
        let zoom: Double
    }

    private(set) var moves: [Move] = []

    func onMove(center: CLLocationCoordinate2D, bounds: BoundingBox, zoom: Double) {
        moves.append(Move(center: center, bounds: bounds, zoom: zoom))
    }

    func onRotate(angle: Double) {}
    func onMapInteraction() {}
}
