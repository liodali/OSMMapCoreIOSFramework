//
//  extensions.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 01.12.23.
//

import Foundation
import MapKit
@_implementationOnly import MapCore

let RADIUS_EARTH = 6378137.0
let deg2rad = Double.pi / 180.0
public func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}
/**
  this function illustraction subscation between two location with precison of 0.0000001
 */
public func -(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude - rhs.latitude <= 0.0000001 && lhs.longitude - rhs.longitude <= 0.0000001
}
func ==(lhs: MCRectCoord, rhs: MCRectCoord) -> Bool {
    return lhs.topLeft == rhs.topLeft && lhs.bottomRight == rhs.bottomRight
}
func ==(lhs: MCCoord, rhs: MCCoord) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y
}
func isEqualTo1eX(value: Float) -> Bool {
    let log10Value = log10(value)
    let exponent = Int(log10Value)
    return value == Float(truncating: pow(10, exponent) as NSNumber) && exponent >= 2 && exponent <= 8  // Adjust the range as needed
}
extension MCRectCoord {
     func toBoundingBox()-> BoundingBox {
         let topLeft4326 = topLeft.toCLLocation2D()
         let bottomRight4326 = bottomRight.toCLLocation2D()
         return BoundingBox(north: topLeft4326.longitude,west: topLeft4326.latitude,
                            east: bottomRight4326.latitude, south: bottomRight4326.longitude)
    }
}
extension CLLocationCoordinate2D {
     func toMCCoordEpsg3857()-> MCCoord {
      let x = (longitude * 20037508.34) / 180
      let preY = (log(tan(((90 + latitude) * Double.pi) / 360)) / (Double.pi / 180))
      let y = (preY * 20037508.34) / 180
      return MCCoord(systemIdentifier: MCCoordinateSystemIdentifiers.epsg3857(),
                     x: x,
                     y: y,
                     z: 0.0
          )
    }
    /**
      this function check if current Location is equal to [rhs:CLLocationCoordinate2D] with precision, note that precision should be between [1e2 .. 1e8]
     */
    public func isEqual(rhs: CLLocationCoordinate2D,precision:Double = 1e6)throws -> Bool{
        guard isEqualTo1eX(value: Float(precision)) else {
            throw NSError(domain: "precision is wrong value should be value like 1e4,5,6", code: 400)
        }
        let exponent = Int(log10(precision))
        let nPrecision = if precision.sign == FloatingPointSign.plus {
            1 / precision
        }else {
            precision
        }
        return abs(latitude - rhs.latitude) <= precision && abs(longitude - rhs.longitude) <= precision
    }
    func toMCCoord() -> MCCoord {
        MCCoord (systemIdentifier: MCCoordinateSystemIdentifiers.epsg4326(),x: longitude,
                 y: latitude,z: 0.0)
    }
    func id()->String {
        "\(latitude),\(longitude)"
    }
    public func distance(other:CLLocationCoordinate2D) -> Double {
        
        let lat1 = deg2rad * latitude
        let lat2 = deg2rad * other.latitude
        let lon1 = deg2rad * longitude
        let lon2 = deg2rad * other.longitude
        let powLats = pow(sin((lat2 - lat1) / 2), 2)
        let powLons = pow(sin((lon2 - lon1) / 2), 2)
        return RADIUS_EARTH * 2 * asin(min(1, sqrt(powLats + cos(lat1) * cos(lat2) * powLons)))
    }
    public func destinationPoint(distanceInMeter: Double , bearingInDegree: Double) -> CLLocationCoordinate2D {
        let dist = distanceInMeter / RADIUS_EARTH
        let brng = deg2rad * bearingInDegree
        
        let lat1 = deg2rad * latitude
        let lon1 = deg2rad * longitude
        
        let lat2 = asin(sin(lat1) * cos(dist) + cos(lat1) * sin(dist) * cos(brng))
        let coslat1lat2 =  cos(dist) - sin(lat1) * sin(lat2)
        let lon2 = lon1 + atan2(sin(brng) * sin(dist) * cos(lat1), coslat1lat2)
        
        let lat2deg = lat2 / deg2rad
        let lon2deg = lon2 / deg2rad
        
        return CLLocationCoordinate2D(latitude: lat2deg, longitude: lon2deg)
    }
    
}
extension MCCoord {
    func toCLLocation2D() -> CLLocationCoordinate2D {
        let e = 2.7182818284
        let preLatitude3857 = y / (20037508.34 / 180)
        let exp = (Double.pi / 180) * preLatitude3857

        let latitude = (atan(pow(e, exp)) / (Double.pi / 360)) - 90
        let longitude = (x * 180) / 20037508.34
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}


extension UIImage {
    func rotate(radians: Float) -> UIImage? {
            var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
            // Trim off the extremely small float value to prevent core graphics from rounding it up
            newSize.width = floor(newSize.width)
            newSize.height = floor(newSize.height)

            UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
            let context = UIGraphicsGetCurrentContext()!

            // Move origin to middle
            context.translateBy(x: newSize.width/2, y: newSize.height/2)
            // Rotate around middle
            context.rotate(by: CGFloat(radians))
            // Draw the image at its center
            self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return newImage
        }
    func toTexture(angle:Float)->TextureHolder {
        var iconImage = self
        if angle != 0 || angle != 360 {
            iconImage  = rotate(radians: angle) ?? self
        }
        let texture = try! TextureHolder(iconImage.cgImage!)
        return texture
    }
}

