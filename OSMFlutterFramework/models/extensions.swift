//
//  extensions.swift
//  OSMFlutterFramework
//
//  Created by Dali Hamza on 01.12.23.
//

import Foundation
import MapKit
@_implementationOnly import MapCore


public func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}

func ==(lhs: MCRectCoord, rhs: MCRectCoord) -> Bool {
    return lhs.topLeft == rhs.topLeft && lhs.bottomRight == rhs.bottomRight
}
func ==(lhs: MCCoord, rhs: MCCoord) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y
}
extension MCRectCoord {
     func toBoundingBox()-> BoundingBox{
        return BoundingBox(north: topLeft.x,west: topLeft.y,east: bottomRight.y, south: bottomRight.x)
    }
}
extension CLLocationCoordinate2D {
     func toMCCoordEpsg3857()-> MCCoord {
        MCCoord(systemIdentifier: MCCoordinateSystemIdentifiers.epsg3857(),  x: (longitude * 20037508.34) / 180,
                y: ((log(tan(((90 + latitude) * Double.pi) / 360)) / (Double.pi / 180)) * 20037508.34) / 180, z: 10.0)
    }
    
    func toMCCoord() -> MCCoord {
        MCCoord (systemIdentifier: MCCoordinateSystemIdentifiers.epsg4326(),x: longitude,
                y: latitude,z: 10.0)
    }
    func id()->String {
        "\(latitude*longitude)"
    }
}
extension MCCoord {
    func toCLLocation2D() -> CLLocationCoordinate2D {
        let e = 2.7182818284
        let preLatitude3857 = y / (20037508.34 / 180)
        let exp = (Double.pi / 180) * preLatitude3857

        let latitude = (atan(pow(e, exp)) / (Double.pi / 360)) - 90
        return CLLocationCoordinate2D(latitude: latitude, longitude: (x * 180) / 20037508.34 )
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
