//
//  LocalSearchClient.swift
//  WhereIsWeather
//
//  Created by Viktor on 18.04.2022.
//

import Foundation
import ComposableArchitecture
import MapKit

struct LocalSearchClient {
    var search: (LocalSearchCompletion) -> Effect<Response, Error>
    
    struct Response: Equatable {
        var boundingRegion = CoordinateRegion()
        var mapItems: [MKMapItem] = []
    }
}

extension LocalSearchClient.Response {
    init(rawValue: MKLocalSearch.Response) {
        self.boundingRegion = .init(rawValue: rawValue.boundingRegion)
        self.mapItems = rawValue.mapItems
    }
}

extension LocalSearchClient {
    static let live = Self(
        search: { completion in
                .task {
                    .init(
                        rawValue:
                            try await MKLocalSearch(
                                /// its ok, because in .live never will be nil
                                request: .init(completion: completion.rawValue!)
                            )
                                .start()
                    )
                }
        }
    )
}
