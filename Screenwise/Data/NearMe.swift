import CoreLocation
import Foundation
import Models
import Scoring

/// "Near me" (spec 5.11, decision D-39). Asks for location only when the user picks Near me,
/// takes one position, and keeps it in memory. The location never leaves the phone.
@MainActor
@Observable
final class NearMe {
  enum State: Equatable {
    case idle
    case locating
    case located(lat: Double, lon: Double)
    case denied
    case unavailable
  }

  private(set) var state: State = .idle
  private var task: Task<Void, Never>?

  var position: (lat: Double, lon: Double)? {
    if case .located(let lat, let lon) = state { return (lat, lon) }
    return nil
  }

  /// Straight-line kilometres from the user to a venue, when both are known.
  func distanceKm(to venue: Venue?) -> Double? {
    guard let position, let location = venue?.location else { return nil }
    return location.distanceKm(toLat: position.lat, lon: position.lon)
  }

  /// Starts one location lookup, unless one is running or a position is already known.
  func locate() {
    guard task == nil, position == nil else { return }
    state = .locating
    task = Task { [weak self] in
      // The session asks for When In Use permission the first time.
      let session = CLServiceSession(authorization: .whenInUse)
      defer {
        withExtendedLifetime(session) {}
        self?.task = nil
      }
      do {
        for try await update in CLLocationUpdate.liveUpdates() {
          if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
            self?.state = .denied
            return
          }
          if let location = update.location {
            self?.state = .located(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            return
          }
        }
        self?.state = .unavailable
      } catch {
        self?.state = .unavailable
      }
    }
  }

  /// The theatres to show for Near me: the best within 10 km, widening to 15 and then 25 km
  /// until there are at least three cinemas. Keeps the city ranking order.
  func nearby(_ ranking: [RankedScreen], venue: (Screen) -> Venue?) -> (list: [RankedScreen], radiusKm: Int) {
    for radius in [10, 15, 25] {
      let list = ranking.filter { (distanceKm(to: venue($0.screen)) ?? .infinity) <= Double(radius) }
      if Set(list.map(\.screen.venueID)).count >= 3 { return (list, radius) }
    }
    let list = ranking.filter { (distanceKm(to: venue($0.screen)) ?? .infinity) <= 25 }
    return (list, 25)
  }
}
