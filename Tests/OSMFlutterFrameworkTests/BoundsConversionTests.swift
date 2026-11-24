import XCTest
import CoreLocation
import MapCore
@testable import OSMFlutterFramework

final class BoundsConversionTests: XCTestCase {
    func testGeographicRectPreservesLatitudeAndLongitudeAxes() {
        let rect = MCRectCoord(
            topLeft: CLLocationCoordinate2D(latitude: 48, longitude: 6).mcCoord,
            bottomRight: CLLocationCoordinate2D(latitude: 46, longitude: 10).mcCoord)

        assertBoundingBox(rect.toBoundingBox(), north: 48, south: 46, east: 10, west: 6)
    }

    func testProjectedRectPreservesLatitudeAndLongitudeAxes() {
        let rect = MCRectCoord(
            topLeft: CLLocationCoordinate2D(latitude: 48, longitude: 6).toMCCoordEpsg3857(),
            bottomRight: CLLocationCoordinate2D(latitude: 46, longitude: 10).toMCCoordEpsg3857())

        assertBoundingBox(rect.toBoundingBox(), north: 48, south: 46, east: 10, west: 6)
    }

    func testAntimeridianRectKeepsEndpointConvention() {
        let rect = MCRectCoord(
            topLeft: CLLocationCoordinate2D(latitude: 20, longitude: 170).mcCoord,
            bottomRight: CLLocationCoordinate2D(latitude: 10, longitude: -170).mcCoord)

        assertBoundingBox(rect.toBoundingBox(), north: 20, south: 10, east: -170, west: 170)
        XCTAssertLessThan(rect.toBoundingBox().east, rect.toBoundingBox().west)
    }

    private func assertBoundingBox(
        _ bounds: BoundingBox, north: Double, south: Double, east: Double, west: Double,
        accuracy: Double = 0.000_000_1,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(bounds.north, north, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(bounds.south, south, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(bounds.east, east, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(bounds.west, west, accuracy: accuracy, file: file, line: line)
    }
}
