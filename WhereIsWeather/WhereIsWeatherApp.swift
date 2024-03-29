//
//  WhereIsWeatherApp.swift
//  WhereIsWeather
//
//  Created by Viktor on 18.04.2022.
//

import ComposableArchitecture
import SwiftUI

@main
struct WhereIsWeatherApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                AppView(
                    store: .init(
                        initialState: .init(),
                        reducer: appReducer.debugActions(),
                        environment: .init(
                            localSearch: .live,
                            localSearchCompleter: .live,
                            mainQueue: .main,
                            locationManager: .live,
                            pathMonitor: .live(queue: .main),
                            weatherClient: .live
                        )
                    )
                )
            }
            .navigationViewStyle(.stack)
        }
    }
} 
