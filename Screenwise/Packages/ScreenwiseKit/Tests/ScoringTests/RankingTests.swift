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
let doomsdayGenres = ["Science Fiction", "Action", "Adventure"]
let flatFormats = FilmFormats(frameRatio: 1.85, frameStatus: .confirmed)

@Suite("Ranking with the real theatre data")
struct RankingTests {
  @Test func doomsdayOrderMatchesTheReference() throws {
    let data = try loadTheatres()
    // The 9 reference screens in fixtures/scoring/doomsday.json (v3, D-38), plus AAA Screen 2 (D-01).
    // The cinemas added later rank among them, so compare the reference screens' order only.
    let reference: Set = [
      "allu-s1-dolby", "amb-s1-hdr", "prasads-pcx", "prasads-screen4-hdr", "vimal-s1", "aaa-s1",
      "shiva-ganga-s1", "sudarshan-s1", "art-s6-epiq", "aaa-s2-epiq-led",
    ]
    let ranked = Ranker.rank(formats: doomsdayFormats, genres: doomsdayGenres, screens: data.openScreens)
      .filter { reference.contains($0.screen.id) }
    let ids = ranked.map(\.screen.id)
    #expect(
      ids == [
        "allu-s1-dolby", "prasads-pcx", "vimal-s1", "amb-s1-hdr", "aaa-s1", "shiva-ganga-s1",
        "prasads-screen4-hdr", "sudarshan-s1", "art-s6-epiq", "aaa-s2-epiq-led",
      ])
    #expect(ranked.map(\.shown) == [85, 78, 73, 72, 72, 72, 68, 68, 65, 57])
  }

  @Test func flatHDRMovieRaisesPrasadsScreen4AbovePCX() throws {
    // v3: Screen 4's HDR projector only counts fully for a movie released in HDR by Barco.
    let hdr = FilmFormats(frameRatio: 1.85, frameStatus: .confirmed, hdrBarco: .confirmed)
    let ranked = Ranker.rank(formats: hdr, screens: try loadTheatres().openScreens)
    let ids = ranked.map(\.screen.id)
    let s4 = try #require(ids.firstIndex(of: "prasads-screen4-hdr"))
    let pcx = try #require(ids.firstIndex(of: "prasads-pcx"))
    #expect(s4 < pcx)
  }

  @Test func theBestScreenDependsOnTheMovie() throws {
    let screens = try loadTheatres().openScreens
    let top = { (f: FilmFormats, g: [String]) in Ranker.rank(formats: f, genres: g, screens: screens)[0].screen.id }
    let scope = FilmFormats(frameRatio: 2.39)
    #expect(top(FilmFormats(frameRatio: 2.39, dolbyVision: .confirmed), ["Drama"]) == "allu-s1-dolby")
    #expect(top(scope, ["Action", "Thriller"]) == "prasads-pcx")
  }

  @Test func mainReasonsForDoomsday() throws {
    let ranked = Ranker.rank(formats: doomsdayFormats, genres: doomsdayGenres, screens: try loadTheatres().openScreens)
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
    let ranked = Ranker.rank(formats: doomsdayFormats, genres: doomsdayGenres, screens: try loadTheatres().openScreens)
    for r in ranked {
      #expect(r.pros.first == r.mainReason)
      guard r.parts.pictureW != nil else {
        // Unknown size: no size line, so the main reason may stand alone.
        #expect((1...4).contains(r.pros.count), "\(r.screen.id) has \(r.pros.count) pros")
        continue
      }
      #expect((2...4).contains(r.pros.count), "\(r.screen.id) has \(r.pros.count) pros")
      if case .pictureSizeRank = r.pros[1] {} else { Issue.record("\(r.screen.id) second pro") }
    }
  }

  @Test func unknownDetailsDoNotMakeKnownScreensLookAboveAverage() throws {
    let ranked = Ranker.rank(formats: doomsdayFormats, genres: doomsdayGenres, screens: try loadTheatres().openScreens)
    let byID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.screen.id, $0) })
    // Many regular screens have no known details. They rank below every known premium screen.
    let standard = try #require(byID["pvr-next-galleria-regular"])
    #expect(standard.mainReason == .techAndSound)
    #expect(standard.rank > byID["sudarshan-s1"]!.rank)
    #expect(standard.isLowConfidence)
  }

  @Test func consFlagShapeAndUnconfirmedSpecs() throws {
    let ranked = Ranker.rank(formats: doomsdayFormats, genres: doomsdayGenres, screens: try loadTheatres().openScreens)
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
    let ranked = Ranker.rank(formats: doomsdayFormats, genres: doomsdayGenres, screens: try loadTheatres().openScreens)
    let byID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.screen.id, $0) })
    #expect(byID["prasads-pcx"]?.sizeRank == 1)
    #expect(byID["allu-s1-dolby"]?.sizeRank == 2)
    #expect(byID["aaa-s2-epiq-led"]?.sizeRank == 10)
  }
}
