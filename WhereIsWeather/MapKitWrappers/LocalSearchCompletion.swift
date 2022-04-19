//
//  LocalSearchCompletion.swift
//  WhereIsWeather
//
//  Created by Viktor on 19.04.2022.
//

import MapKit

struct LocalSearchCompletion: Equatable {
    let rawValue: MKLocalSearchCompletion?
    
    var subtitle: String
    var title: String
    
    init(rawValue: MKLocalSearchCompletion) {
        self.rawValue = rawValue
        self.subtitle = rawValue.subtitle
        self.title = rawValue.title
    }
    
    init(subtitle: String, title: String) {
        self.rawValue = nil
        self.subtitle = subtitle
        self.title = title
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle
    }
}

extension LocalSearchCompletion: Identifiable {
    var id: [String] {  [self.title, self.subtitle] }
}
