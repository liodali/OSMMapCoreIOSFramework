//
// Created by Dali Hamza on 13.11.22.
//

import Foundation

public class CustomTiles {
    var tileURL: String = ""
    var subDomains: String = ""
    var tileSize: String
    var maxZoom: String
    private(set) var randSubDomain = 0
    public private(set) var isVector: Bool = false
    public init(_ mapTile: [String: Any], isMapCore: Bool = true) {
        let isVector = mapTile["isVector"] as? Bool ?? false
        self.isVector = isVector

        if isVector {
            tileURL =
                (mapTile["styleURL"] as? String)
                ?? ((mapTile["urls"] as? [[String: Any]])?.first?["url"] as? String)
                ?? ""
            tileSize = (mapTile["tileSize"] as? Int)?.description ?? "256"
            maxZoom = mapTile["maxZoomLevel"] as? String ?? "19"
            return
        }

        let tiles = (mapTile["urls"] as! [[String: Any]]).first
        tileURL = tiles!["url"] as! String
        if !tileURL.contains("{z}") && !tileURL.contains("{y}") && !tileURL.contains("{x}") {
            tileURL += "{z}/{x}/{y}"
        }
        tileURL += (mapTile["tileExtension"] as! String)
        if isMapCore && ((tiles?.keys.contains("subdomains")) != nil) {
            let len = (tiles!["subdomains"] as? [String])?.count ?? 0
            if len != 0 {
                randSubDomain = Int.random(in: 0...(len - 1))
                subDomains = (tiles!["subdomains"] as? [String])?[randSubDomain] ?? ""
            }
        } else if !isMapCore && ((tiles?.keys.contains("subdomains")) != nil) {
            subDomains = (tiles!["subdomains"] as? [String])?.description ?? ""
        }
        tileSize = (mapTile["tileSize"] as? Int)?.description ?? "256"

        if mapTile.keys.contains("api") {
            let mapApi = (mapTile["api"] as! [String: String])
            tileURL = tileURL + "?\(mapApi.keys.first!)=\(mapApi.values.first ?? "")"
        }
        maxZoom = mapTile["maxZoomLevel"] as? String ?? "19"
    }
    public func toString() -> String {
        if isVector {
            return tileURL
        }
        var url = tileURL
        if !subDomains.isEmpty {
            url = url.replacingOccurrences(of: "{s}", with: "\(subDomains)")
        }
        return url
    }
}
