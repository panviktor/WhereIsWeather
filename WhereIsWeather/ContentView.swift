//
//  ContentView.swift
//  WhereIsWeather
//
//  Created by Viktor on 18.04.2022.
//

import ComposableArchitecture
import SwiftUI
import MapKit

struct AppState: Equatable {
    var completions: [LocalSearchCompletion] = []
    var mapItems: [MKMapItem] = []
    var query = ""
    var region = CoordinateRegion.mocRegion
    
    var navigationBarIsHiden = false
    var uiButtonIsHiden = false
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
}

struct AppEnvironment {
    var localSearch: LocalSearchClient
    var localSearchCompleter: LocalSearchCompleter
    var mainQueue: AnySchedulerOf<DispatchQueue>
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> {
    state, action, environment in
    switch action {
    case .onAppear:
        return environment.localSearchCompleter.completions()
            .map { result in
                result.mapError { $0 as NSError }
            }
            .map(AppAction.comletionsUpdated)
        
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
        state.uiButtonIsHiden = false
        return .none
    case .changeUIButtonOff:
        state.uiButtonIsHiden = true
        return .none
    }
}

struct ContentView: View {
    let store: Store<AppState, AppAction>
    
    @Environment(\.isSearching) var isSearching
    
    var body: some View {
        WithViewStore(self.store) { viewStore in
            ZStack(alignment: .bottomTrailing) {
                ExtractedView(store: self.store)
       
                if !viewStore.uiButtonIsHiden {
                    VStack(alignment: .leading) {
                        Button {
                            viewStore.send(.tappedChangeUI)
                        } label: {
                            HStack {
                                Text("Change UI")
                                    .bold()
                                Image(systemName: "circle.grid.cross.fill")
                            }
                            .foregroundColor(.black)
                            .padding([.vertical], 25)
                            .padding([.horizontal], 10)
                        }
                    }
                }
            }

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
            ContentView(
                store: .init(
                    initialState: .init(),
                    reducer: appReducer.debugActions(),
                    environment: .init(
                        localSearch: .live,
                        localSearchCompleter: .live,
                        mainQueue: .main
                    )
                )
            )
        }
    }
}

extension CoordinateRegion {
    static var mocRegion: CoordinateRegion {
        CoordinateRegion.init(
            center: .init(latitude: 40.7, longitude: -74),
            span: .init(latitudeDelta: 0.075, longitudeDelta: 0.075)
        )
    }
}

struct CoordinateRegion: Equatable {
    var center = LocationCoordinate2D()
    var span = CoordinateSpan()
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

extension LocalSearchCompletion: Identifiable {
    var id: [String] {  [self.title, self.subtitle] }
}

extension MKMapItem: Identifiable {}


struct ExtractedView: View {
    let store: Store<AppState, AppAction>
    var body: some View {
        WithViewStore(self.store) { viewStore in
            Map.init(
                coordinateRegion: viewStore.binding(
                    get: \.region.rawValue,
                    send: { .regionChanged(.init(rawValue: $0)) }
                ),
                annotationItems: viewStore.mapItems,
                annotationContent: { mapItem in
                    MapMarker(coordinate: mapItem.placemark.coordinate)
                }
            )
            .searchable(
                text: viewStore.binding(
                    get: \.query,
                    send: AppAction.queryChanged
                )
            ) {
                Group {
                    ForEach(viewStore.completions) { completion in
                        Button {
                            viewStore.send(.tappedCompletion(completion))
                        } label: {
                            VStack(alignment: .leading) {
                                Text(completion.title)
                                Text(completion.subtitle)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .onAppear {
                    viewStore.send(.changeUIButtonOff)
                }
                .onDisappear {
                    viewStore.send(.changeUIButtonOn)
                }
            }
        }
    }
}
