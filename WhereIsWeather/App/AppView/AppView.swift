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

struct AppView: View {
    let store: Store<AppState, AppAction>
        
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
