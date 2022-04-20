//
//  WeatherClient.swift
//  WhereIsWeather
//
//  Created by Viktor on 21.04.2022.
//

import Combine
import ComposableArchitecture

struct WeatherResponse: Decodable, Equatable {
    let main: Weather
}

struct Weather: Decodable, Equatable {
    var temp: Double?
    var humidity: Double?
}

struct WeatherClient {
    var weather: (CoordinateRegion) -> Effect<WeatherResponse, Failure>
    struct Failure: Error, Equatable {}
}

extension WeatherClient {
    static let live = WeatherClient(
        weather: { geo in

            let latitude = Double(round(1000 * geo.center.latitude) / 1000)
            let longitude = Double(round(1000 * geo.center.longitude) / 1000)
            
            guard let url = URL(
                string: "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&appid=78f89cc931cdccee027bb343b5e7ec9f")
            else {
                fatalError("Error on creating url")
            }
            
            var decoder: JSONDecoder {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return decoder
            }
            
            return URLSession.shared.dataTaskPublisher(for: url)
                .map { data, _ in data }
                .decode(type: WeatherResponse.self, decoder: decoder)
                .mapError { _ in Failure() }
                .eraseToEffect()
        }
    )
}
