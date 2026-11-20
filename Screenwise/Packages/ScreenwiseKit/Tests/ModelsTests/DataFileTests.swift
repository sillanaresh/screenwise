import Foundation
import Testing

@testable import Models

let repoRoot: URL = {
  var url = URL(fileURLWithPath: #filePath)
  for _ in 0..<6 { url.deleteLastPathComponent() }
  return url
}()

func decode<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
  try JSONDecoder().decode(T.self, from: Data(contentsOf: repoRoot.appending(path: path)))
}

@Suite("data/screens.json")
struct TheatreDataTests {
  @Test func counts() throws {
    // The seed's 8 open venues and 10 open screens, plus the 31 cinemas added on 19 Nov 2026.
    let data = try decode(TheatreData.self, "data/screens.json")
    #expect(data.venues.filter { $0.status == .open }.count == 39)
    #expect(data.openScreens.count == 51)
    #expect(data.venues.filter { $0.status == .upcoming }.count == 5)
  }

  @Test func everyOpenVenueHasASourcedLocation() throws {
    let data = try decode(TheatreData.self, "data/screens.json")
    let ids = Set(data.sources.map(\.id))
    for venue in data.venues where venue.status == .open {
      let loc = try #require(venue.location, "\(venue.id) has no location")
      #expect((17.0...17.8).contains(loc.lat) && (78.0...79.0).contains(loc.lon), "\(venue.id) isn't in Hyderabad")
      #expect(!loc.sources.isEmpty && loc.sources.allSatisfy(ids.contains), "\(venue.id) location source")
    }
  }

  @Test func distanceIsStraightLineKilometres() {
    // Prasads (Khairatabad) to AMB (Gachibowli) is about 11.8 km in a straight line.
    let prasads = VenueLocation(lat: 17.4127019, lon: 78.4657508)
    let d = prasads.distanceKm(toLat: 17.4573210, lon: 78.3634764)
    #expect(abs(d - 11.8) < 0.3, "\(d)")
  }

  @Test func everyOpenVenueHasAScreen() throws {
    let data = try decode(TheatreData.self, "data/screens.json")
    for venue in data.venues where venue.status == .open {
      #expect(data.openScreens.contains { $0.venueID == venue.id }, "\(venue.id)")
    }
  }

  @Test func everySourceIDExists() throws {
    let data = try decode(TheatreData.self, "data/screens.json")
    let ids = Set(data.sources.map(\.id))
    for screen in data.screens {
      let f = screen.fields
      var used: [String] = []
      used += f.widthFt.sourceIDs + f.heightFt.sourceIDs + f.seats.sourceIDs
      used += f.projection.sourceIDs + f.sound.sourceIDs
      used += (f.brandFormat?.sourceIDs ?? []) + (f.shape?.sourceIDs ?? [])
      used += f.widthFt.alternatives.flatMap(\.sourceIDs)
      used += f.projection.alternatives.flatMap(\.sourceIDs)
      used += screen.reviewNotes.flatMap(\.sourceIDs)
      for id in used {
        #expect(ids.contains(id), "\(screen.id) cites missing source \(id)")
      }
    }
  }

  @Test func knownValuesHaveSourcesAndUnknownsHaveNone() throws {
    let data = try decode(TheatreData.self, "data/screens.json")
    for screen in data.screens {
      for (name, status, sources) in [
        ("width", screen.fields.widthFt.status, screen.fields.widthFt.sourceIDs),
        ("height", screen.fields.heightFt.status, screen.fields.heightFt.sourceIDs),
        ("projection", screen.fields.projection.status, screen.fields.projection.sourceIDs),
        ("sound", screen.fields.sound.status, screen.fields.sound.sourceIDs),
      ] {
        if status == .unknown {
          #expect(sources.isEmpty, "\(screen.id) \(name)")
        } else {
          #expect(!sources.isEmpty, "\(screen.id) \(name) has a value but no source")
        }
      }
    }
  }

  @Test func conflictingFieldsListAlternatives() throws {
    let data = try decode(TheatreData.self, "data/screens.json")
    let ganga = try #require(data.screen("shiva-ganga-s1"))
    #expect(ganga.fields.widthFt.status == .conflicting)
    #expect(ganga.fields.widthFt.alternatives.first?.value == 68)
  }

  @Test func everyScreenHasAVenue() throws {
    let data = try decode(TheatreData.self, "data/screens.json")
    for screen in data.screens {
      #expect(data.venue(screen.venueID) != nil, "\(screen.id)")
    }
  }
}

@Suite("data/catalogue.json")
struct CatalogueTests {
  @Test func decodes() throws {
    let catalogue = try decode(Catalogue.self, "data/catalogue.json")
    #expect(!catalogue.films.isEmpty)
    for film in catalogue.films {
      #expect(film.releaseDate() != nil, "\(film.id) needs an India release date")
    }
  }

  @Test func inCinemasUsesIndiaDate() {
    let film = Film(id: "x", title: "X", releaseDateIN: "2026-12-18")
    let cal = Calendar.india
    let before = cal.date(from: DateComponents(year: 2026, month: 12, day: 17, hour: 23))!
    let on = cal.date(from: DateComponents(year: 2026, month: 12, day: 18, hour: 0, minute: 5))!
    #expect(!film.isInCinemas(on: before))
    #expect(film.isInCinemas(on: on))
  }
}
