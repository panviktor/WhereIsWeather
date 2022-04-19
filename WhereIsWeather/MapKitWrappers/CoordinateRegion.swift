//
//  CoordinateRegion.swift
//  WhereIsWeather
//
//  Created by Viktor on 19.04.2022.
//

import MapKit

struct CoordinateRegion: Equatable {
    var center = LocationCoordinate2D()
    var span = CoordinateSpan()
}

extension CoordinateRegion {
    static var mocRegion: CoordinateRegion {
        CoordinateRegion.init(
            center: .init(latitude: 40.7, longitude: -74),
            span: .init(latitudeDelta: 0.075, longitudeDelta: 0.075)
        )
    }
}

extension CoordinateRegion {
    init(rawValue: MKCoordinateRegion) {
        self.init(
            center: .init(rawValue: rawValue.center),
            span: .init(rawValue: rawValue.span)
        )
    }
    
    var rawValue: MKCoordinateRegion {
        .init(center: self.center.rawValue, span: self.span.rawValue)
    }
}
