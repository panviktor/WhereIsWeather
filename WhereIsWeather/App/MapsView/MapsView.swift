//
//  MapsView.swift
//  WhereIsWeather
//
//  Created by Viktor on 19.04.2022.
//

import SwiftUI
import MapKit
import ComposableArchitecture

struct MapsView: View {
    let store: Store<AppState, AppAction>
    var body: some View {
        WithViewStore(self.store) { viewStore in
            Map.init(
                coordinateRegion: viewStore.binding(
                    get: \.region.rawValue,
                    send: { .regionWillChanged(.init(rawValue: $0)) }
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
