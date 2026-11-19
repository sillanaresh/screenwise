import Foundation
import Models
import Testing

@testable import Scoring

func loadTheatres() throws -> TheatreData {
  let url = repoRoot.appending(path: "data/screens.json")
  return try JSONDecoder().decode(TheatreData.self, from: Data(contentsOf: url))
}

let doomsdayFormats = FilmFormats(
  frameRatio: 2.39, frameStatus: .estimated, imax: .expected, imaxRatio: 1.90,
  dolbyVision: .expected)
let flatFormats = FilmFormats(frameRatio: 1.85, frameStatus: .confirmed)

@Suite("Ranking with the real theatre data")
struct RankingTests {
  @Test func doomsdayOrderMatchesSpec() throws {
    let data = try loadTheatres()
    // The spec's table covers the 9 reference screens. AAA Screen 2 is ranked too (decision D-01).
    let ranked = Ranker.rank(formats: doomsdayFormats, screens: data.openScreens)
    let ids = ranked.map(\.screen.id)
    #expect(
      ids == [
        "allu-s1-dolby", "amb-s1-hdr", "prasads-pcx", "prasads-screen4-hdr", "vimal-s1", "aaa-s1",
        "shiva-ganga-s1", "sudarshan-s1", "art-s6-epiq", "aaa-s2-epiq-led",
      ])
    #expect(ranked.map(\.shown) == [90, 79, 77, 75, 73, 72, 72, 68, 66, 61])
  }

  @Test func flatMovieRaisesPrasadsScreen4AbovePCX() throws {
    let ranked = Ranker.rank(formats: flatFormats, screens: try loadTheatres().openScreens)
    let ids = ranked.map(\.screen.id)
    let s4 = try #require(ids.firstIndex(of: "prasads-screen4-hdr"))
    let pcx = try #require(ids.firstIndex(of: "prasads-pcx"))
    #expect(s4 < pcx)
  }

  @Test func mainReasonsForDoomsday() throws {
    let ranked = Ranker.rank(formats: doomsdayFormats, screens: try loadTheatres().openScreens)
    let byID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.screen.id, $0) })
    #expect(byID["allu-s1-dolby"]?.mainReason == .bestTechBlackRoom)
    #expect(byID["amb-s1-hdr"]?.mainReason == .hdrFillsScope)
    #expect(byID["prasads-pcx"]?.mainReason == .biggestPicture)
    #expect(byID["prasads-screen4-hdr"]?.mainReason == .hdrBright)
    #expect(byID["vimal-s1"]?.mainReason == .bigPicture)
    // Not above the city median on anything: falls back to a plain summary.
    #expect(byID["sudarshan-s1"]?.mainReason == .techAndSound)
  }

  @Test func prosStartWithMainReasonThenSize() throws {
    let ranked = Ranker.rank(formats: doomsdayFormats, screens: try loadTheatres().openScreens)
    for r in ranked {
      #expect(r.pros.first == r.mainReason)
      #expect((2...4).contains(r.pros.count), "\(r.screen.id) has \(r.pros.count) pros")
      if case .pictureSizeRank = r.pros[1] {} else { Issue.record("\(r.screen.id) second pro") }
    }
  }

  @Test func consFlagShapeAndUnconfirmedSpecs() throws {
    let ranked = Ranker.rank(formats: doomsdayFormats, screens: try loadTheatres().openScreens)
    let byID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.screen.id, $0) })
    #expect(byID["allu-s1-dolby"]?.cons.contains(.flatScreenBands) == true)
    #expect(byID["prasads-pcx"]?.cons.contains(.tallScreenBands(percentOfHeight: 66)) == true)
    #expect(byID["prasads-pcx"]?.cons.contains(.projectorNotConfirmed) == true)
    #expect(byID["prasads-pcx"]?.cons.contains(.review("side_seats_poor")) == true)
    #expect(byID["shiva-ganga-s1"]?.cons.contains(.sizeReportsDiffer) == true)
    #expect(byID["amb-s1-hdr"]?.isLowConfidence == false)
    #expect(byID["prasads-pcx"]?.isLowConfidence == true)
  }

  @Test func sizeRanks() throws {
    let ranked = Ranker.rank(formats: doomsdayFormats, screens: try loadTheatres().openScreens)
    let byID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.screen.id, $0) })
    #expect(byID["prasads-pcx"]?.sizeRank == 1)
    #expect(byID["allu-s1-dolby"]?.sizeRank == 2)
    #expect(byID["aaa-s2-epiq-led"]?.sizeRank == 10)
  }
}
