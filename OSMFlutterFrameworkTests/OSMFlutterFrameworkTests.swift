//
//  OSMFlutterFrameworkTests.swift
//  OSMFlutterFrameworkTests
//
//  Created by Dali Hamza on 04.12.23.
//

import XCTest
@testable import OSMFlutterFramework
import MapKit
final class OSMFlutterFrameworkTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    func testConvertMCCoordCLLocationCoordination() throws {
        let mccoordConverted = convertEPSG3857To4326(x: 942421.0495557635, y: 6010109.745834013)
        let p = CLLocationCoordinate2D(latitude: 47.41519494893657, longitude: 8.465912330097497)
        XCTAssertTrue(p.latitude == mccoordConverted.lat && p.longitude == mccoordConverted.lng)
    }
    
    func testCLLocationCoordinate2DIsEqual() throws {
        let p = CLLocationCoordinate2D(latitude: 47.415194, longitude: 8.465912)
        let p2 = CLLocationCoordinate2D(latitude: 47.41519494893657, longitude: 8.465912330097497)
        XCTAssertTrue(((try? p.isEqual(rhs: p2, precision: 1e6)) != nil))
    }
    
    func testCustomTile() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        let customTile = CustomTiles(["urls":[["url":"https://{s}.tile.openstreetmap.org/",
                                               "subdomains":["a","b","c"]],
                                              ],"tileExtension":".png",
                                      "tileSize":"256","maxZoomLevel":"19"])
        let sub = ["a","b","c"][customTile.randSubDomain]
        let url = customTile.toString()
        print(url)
        print(customTile.subDomains)
        XCTAssertTrue(url == "https://\(sub).tile.openstreetmap.org/{z}/{x}/{y}.png")
    }
    func testCustomTile2() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        let customTile = CustomTiles(["urls":[["url":"https://{s}.tile.openstreetmap.org/{z}/{y}/{x}",
                                               "subdomains":["a","b","c"]],
                                              ],"tileExtension":".png",
                                      "tileSize":"256","maxZoomLevel":"19"])
        let sub = ["a","b","c"][customTile.randSubDomain]
        let url = customTile.toString()
        print(url)
        print(customTile.subDomains)
        XCTAssertTrue(url == "https://\(sub).tile.openstreetmap.org/{z}/{y}/{x}.png")
    }
    func testBoundingBox() throws {
        let boundingbox = BoundingBox()
        XCTAssertTrue(boundingbox.isWorld())
       
        XCTAssertTrue(boundingbox.toBoundingEpsg3857() == BoundingBox(north: -20037508.34,west: 20037508.34,
                                                                      east: -20037508.34, south: 20037508.34))
    }
    
    func testZoomLevel() throws {
        let zoomLevel = 21536.731457737689
        let mapConfig = OSMTiledLayerConfig(tileURL: "",configuration: OSMMapConfiguration())
        let zoom = mapConfig.getZoomIdentifierFromZoom(zoom: zoomLevel)
        XCTAssertTrue(zoom == 15)
    }
    func testZoomIdentifierLevel() throws {
        let zoomLevel = 17061.8366708
        let zLvel = zoomIdentifierLevel[15]
        XCTAssertTrue(zLvel == zoomLevel)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
