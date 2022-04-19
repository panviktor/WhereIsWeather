//
//  LocationCoordinate2D.swift
//  WhereIsWeather
//
//  Created by Viktor on 19.04.2022.
//

import MapKit

struct LocationCoordinate2D: Equatable {
    var latitude: CLLocationDegrees = 0
    var longitude: CLLocationDegrees = 0
}

extension LocationCoordinate2D {
    init(rawValue: CLLocationCoordinate2D) {
        self.init(latitude: rawValue.latitude, longitude: rawValue.longitude)
    }
    
    var rawValue: CLLocationCoordinate2D {
        .init(latitude: self.latitude, longitude: self.longitude)
    }
}
