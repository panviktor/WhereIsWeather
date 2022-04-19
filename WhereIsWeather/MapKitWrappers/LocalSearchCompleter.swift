//
//  LocalSearchCompleter.swift
//  WhereIsWeather
//
//  Created by Viktor on 18.04.2022.
//

import Foundation
import ComposableArchitecture
import Combine
import MapKit

struct LocalSearchCompleter {
    var completions: () -> Effect<Result<[LocalSearchCompletion], Error>, Never>
    var search: (String) -> Effect<Never, Never>
}

extension LocalSearchCompleter {
    static var live: Self {
        class Delegate: NSObject, MKLocalSearchCompleterDelegate {
            let subscriber: Effect<Result<[LocalSearchCompletion], Error>, Never>.Subscriber
            
            init(subscriber: Effect<Result<[LocalSearchCompletion], Error>, Never>.Subscriber)  {
                self.subscriber = subscriber
            }
            
            func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
                self.subscriber.send(.success(completer.results.map(LocalSearchCompletion.init(rawValue: ))))
            }
            
            func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
                self.subscriber.send(.failure(error))
            }
        }
        
        let completer = MKLocalSearchCompleter()
        
        return Self(
            completions: {
                Effect.run { subscriber in
                    let delegate = Delegate(subscriber: subscriber)
                    completer.delegate = delegate
                    return AnyCancellable {
                        _ = delegate
                    }
                }
            },
            search: { queryFragment in
                    .fireAndForget {
                        completer.queryFragment = queryFragment
                    }
            }
        )
    }
}

