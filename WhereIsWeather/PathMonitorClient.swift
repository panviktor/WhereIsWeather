//
//  PathMonitorClient.swift
//  WhereIsWeather
//
//  Created by Viktor on 19.04.2022.
//
//
import Combine
import Network
import ComposableArchitecture

struct NetworkPath: Equatable {
    var status: NWPath.Status
}

extension NetworkPath {
    init(rawValue: NWPath) {
        self.status = rawValue.status
    }
}

struct PathMonitorClient {
    var networkPathPublisher: Effect<NetworkPath, Never>
    
    init(
        networkPathPublisher: Effect<NetworkPath, Never>
    ) {
        self.networkPathPublisher = networkPathPublisher
    }
}

extension PathMonitorClient {
  public static func live(queue: DispatchQueue) -> Self {
    let monitor = NWPathMonitor()
    let subject = PassthroughSubject<NWPath, Never>()
    monitor.pathUpdateHandler = subject.send

    return Self(
      networkPathPublisher: subject
        .handleEvents(
          receiveSubscription: { _ in monitor.start(queue: queue) },
          receiveCancel: monitor.cancel
        )
        .map(NetworkPath.init(rawValue:))
        .eraseToAnyPublisher()
        .eraseToEffect()
    )
  }
}
