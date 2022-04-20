//
//  AppView.swift
//  WhereIsWeather
//
//  Created by Viktor on 19.04.2022.
//

import ComposableArchitecture
import ComposableCoreLocation
import SwiftUI
import MapKit
import Network

struct AppState: Equatable {
    var completions: [LocalSearchCompletion] = []
    var mapItems: [MKMapItem] = []
    var query = ""
    var region = CoordinateRegion.mocRegion
    
    var navigationBarIsHiden = false
    var uiButtonsIsHiden = false
    
    var status: NetworkPath = .init(status: .satisfied)
    
    var isRequestingCurrentLocation = false
    var alert: AlertState<AppAction>?
    
    var weather: Weather = .init()
}

enum AppAction: Equatable {
    case comletionsUpdated(Result<[LocalSearchCompletion], NSError>)
    case onAppear
    case queryChanged(String)
    case regionWillChanged(CoordinateRegion)
    case regionChanged(CoordinateRegion)
    case locationsResponse(Result<WeatherResponse, WeatherClient.Failure>)
    case searchResponse(Result<LocalSearchClient.Response, NSError>)
    case tappedCompletion(LocalSearchCompletion)
    case tappedChangeUI
    case changeUIButtonOn
    case changeUIButtonOff
    
    case locationManager(LocationManager.Action)
    case dismissAlertButtonTapped
    case currentLocationButtonTapped
    
    case pathMonitor(NetworkPath)
}

struct AppEnvironment {
    var localSearch: LocalSearchClient
    var localSearchCompleter: LocalSearchCompleter
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var locationManager: LocationManager
    var pathMonitor: PathMonitorClient
    var weatherClient: WeatherClient
}

struct LocationManagerId: Hashable {}
struct PathMonitorClientId: Hashable {}
struct DebounceDelayId: Hashable {}


let appReducer = Reducer<AppState, AppAction, AppEnvironment> {
    state, action, environment in
    switch action {
    case .onAppear:
        return .merge(
            environment.localSearchCompleter.completions()
                .map { result in
                    result.mapError { $0 as NSError }
                }
                .map(AppAction.comletionsUpdated),
            
            environment.locationManager.delegate()
                .map(AppAction.locationManager)
                .cancellable(id: LocationManagerId()),
            
            environment.pathMonitor.networkPathPublisher
                .receive(on: environment.mainQueue.animation())
                .eraseToEffect()
                .map(AppAction.pathMonitor)
        )
        
    case let .queryChanged(query):
        state.query = query
        return environment.localSearchCompleter.search(query)
            .fireAndForget()
        
    case let .regionWillChanged(region):
        return Effect(value: region)
            .debounce(
                id: DebounceDelayId(),
                for: 1,
                scheduler: environment.mainQueue)
            .map(AppAction.regionChanged)
        
    case let .regionChanged(region):
        struct SearchWeatherId: Hashable {}
        state.region = region
        return environment.weatherClient
            .weather(region)
            .receive(on: environment.mainQueue)
            .catchToEffect(AppAction.locationsResponse)
            .cancellable(id: SearchWeatherId(), cancelInFlight: true)
    case let .locationsResponse(.success(locationWeather)):
        state.weather = locationWeather.main
        return .none
        
    case let .locationsResponse(.failure(locationWeather)):
        return .none
        
    case let .comletionsUpdated(.success(completions)):
        state.completions = completions
        return .none
        
    case let .comletionsUpdated(.failure(error)):
        // TODO: -
        return .none
    case let .tappedCompletion(completion):
        state.query = completion.title
        return environment.localSearch.search(completion)
            .receive(on: environment.mainQueue.animation())
            .catchToEffect()
            .map { result in
                result.mapError { $0 as NSError }
            }
            .map(AppAction.searchResponse)
    case let .searchResponse(.success(response)):
        state.region = response.boundingRegion
        state.mapItems = response.mapItems
        return .none
    case let .searchResponse(.failure(error)):
        // TODO: -
        return .none
    case .tappedChangeUI:
        state.navigationBarIsHiden.toggle()
        return .none
    case .changeUIButtonOn:
        state.uiButtonsIsHiden = false
        return .none
    case .changeUIButtonOff:
        state.uiButtonsIsHiden = true
        return .none
    case .currentLocationButtonTapped:
        guard environment.locationManager.locationServicesEnabled() else {
            state.alert = .init(title: TextState("Location services are turned off."))
            return .none
        }
        
        switch environment.locationManager.authorizationStatus() {
        case .notDetermined:
            state.isRequestingCurrentLocation = true
#if os(macOS)
            return environment.locationManager
                .requestAlwaysAuthorization()
                .fireAndForget()
#else
            return environment.locationManager
                .requestWhenInUseAuthorization()
                .fireAndForget()
#endif
            
        case .restricted:
            state.alert = .init(title: TextState("Please give us access to your location in settings."))
            return .none
            
        case .denied:
            state.alert = .init(title: TextState("Please give us access to your location in settings."))
            return .none
            
        case .authorizedAlways, .authorizedWhenInUse:
            return environment.locationManager
                .requestLocation()
                .fireAndForget()
            
        @unknown default:
            return .none
        }
        
        
    case .dismissAlertButtonTapped:
        state.alert = nil
        return .none
    case .locationManager:
        return .none
    case let .pathMonitor(monitor):
        state.status = monitor
        return .none
    }
}
    .combined(
        with:
            locationManagerReducer.pullback(
                state: \.self,
                action: /AppAction.locationManager,
                environment: { $0 }
            )
    )


private let locationManagerReducer = Reducer<AppState, LocationManager.Action, AppEnvironment> {
    state, action, environment in
    
    switch action {
    case .didChangeAuthorization(.authorizedAlways),
            .didChangeAuthorization(.authorizedWhenInUse):
        if state.isRequestingCurrentLocation {
            return environment.locationManager
                .requestLocation()
                .fireAndForget()
        }
        return .none
        
    case .didChangeAuthorization(.denied):
        if state.isRequestingCurrentLocation {
            state.alert = .init(
                title: TextState("Location makes this app better. Please consider giving us access.")
            )
            state.isRequestingCurrentLocation = false
        }
        return .none
        
    case let .didUpdateLocations(locations):
        state.isRequestingCurrentLocation = false
        guard let location = locations.first else { return .none }
        state.region = CoordinateRegion(
            center: LocationCoordinate2D.init(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude),
            span: CoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        return .none
        
    default:
        return .none
    }
}
