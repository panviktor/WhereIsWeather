//
//  CoordinateSpan.swift
//  WhereIsWeather
//
//  Created by Viktor on 19.04.2022.
//

import MapKit

struct CoordinateSpan: Equatable {
    var latitudeDelta: CLLocationDegrees = 0
    var longitudeDelta: CLLocationDegrees = 0
}

extension CoordinateSpan {
    init(rawValue: MKCoordinateSpan) {
        self.init(latitudeDelta: rawValue.latitudeDelta, longitudeDelta: rawValue.longitudeDelta)
    }
    
    var rawValue: MKCoordinateSpan {
        .init(latitudeDelta: self.latitudeDelta, longitudeDelta: self.longitudeDelta)
    }
}
