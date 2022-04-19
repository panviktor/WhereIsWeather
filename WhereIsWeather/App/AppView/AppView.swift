//
//  AppView.swift
//  WhereIsWeather
//
//  Created by Viktor on 18.04.2022.
//

import ComposableArchitecture
import ComposableCoreLocation
import SwiftUI
import MapKit

struct AppState: Equatable {
    var completions: [LocalSearchCompletion] = []
    var mapItems: [MKMapItem] = []
    var query = ""
    var region = CoordinateRegion.mocRegion
    
    var navigationBarIsHiden = false
    var uiButtonsIsHiden = false
    
    var isRequestingCurrentLocation = false
    var alert: AlertState<AppAction>?
}

enum AppAction: Equatable {
    case comletionsUpdated(Result<[LocalSearchCompletion], NSError>)
    case onAppear
    case queryChanged(String)
    case regionChanged(CoordinateRegion)
    case searchResponse(Result<LocalSearchClient.Response, NSError>)
    case tappedCompletion(LocalSearchCompletion)
    case tappedChangeUI
    case changeUIButtonOn
    case changeUIButtonOff
    
    case locationManager(LocationManager.Action)
    case dismissAlertButtonTapped
    case currentLocationButtonTapped
}

struct AppEnvironment {
    var localSearch: LocalSearchClient
    var localSearchCompleter: LocalSearchCompleter
    var mainQueue: AnySchedulerOf<DispatchQueue>
    
    var locationManager: LocationManager
}

private struct LocationManagerId: Hashable {}

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
                .cancellable(id: LocationManagerId())
        )
        
    case let .queryChanged(query):
        state.query = query
        return environment.localSearchCompleter.search(query)
            .fireAndForget()
        
    case let .regionChanged(region):
        state.region = region
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
    }
}
    .combined(
        with:
            locationManagerReducer
            .pullback(state: \.self, action: /AppAction.locationManager, environment: { $0 })
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




struct AppView: View {
    let store: Store<AppState, AppAction>
    
    @Environment(\.isSearching) var isSearching
    
    var body: some View {
        WithViewStore(self.store) { viewStore in
            
            ZStack(alignment: .bottom) {
                ZStack(alignment: .bottomTrailing) {
                    MapsView(store: self.store)
                    
                    if !viewStore.uiButtonsIsHiden {
                        HStack {
                            Button {
                                viewStore.send(.currentLocationButtonTapped)
                            } label: {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                            }
                            .background(Color.black)
                            .opacity(0.9)
                            .clipShape(Circle())
                            Spacer()
                            Button {
                                viewStore.send(.tappedChangeUI)
                            } label: {
                                HStack {
                                    Text("Change UI")
                                        .bold()
                                    Image(systemName: "circle.grid.cross.fill")
                                }
                                .foregroundColor(.black)
                            }
                        }
                        .padding([.vertical], 30)
                        .padding([.horizontal], 10)
                    }
                }
                
                if true {
                    HStack {
                        Image(systemName: "exclamationmark.octagon.fill")
                        Text("Not connected to internet")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .padding([.vertical], 90)
                }
            }
            .alert(self.store.scope(state: { $0.alert }), dismiss: .dismissAlertButtonTapped)
            
            .navigationTitle("Places")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: viewStore.navigationBarIsHiden ? .vertical : .bottom)
            .navigationBarHidden(viewStore.navigationBarIsHiden)
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AppView(
                store: .init(
                    initialState: .init(),
                    reducer: appReducer.debugActions(),
                    environment: .init(
                        localSearch: .live,
                        localSearchCompleter: .live,
                        mainQueue: .main,
                        locationManager: .live
                    )
                )
            )
        }
    }
}
