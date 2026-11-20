import Foundation
import Models
import Testing

@testable import Scoring

/// Repo root, found from this file's path, so tests read the shared fixtures in place.
let repoRoot: URL = {
  var url = URL(fileURLWithPath: #filePath)
  for _ in 0..<6 { url.deleteLastPathComponent() }
  return url
}()

struct Fixture: Decodable {
  struct FixtureFilm: Decodable {
    struct IMAX: Decodable {
      var status: String
      var ratio: Double
      var share: Double?
    }
    var ratio: Double
    var versions: [String: String]
    var imax: IMAX?
    var spectacle: Bool?
  }
  struct FixtureScreen: Decodable {
    var name: String
    var w: Double?
    var h: Double?
    var tech: String
    var sound: String
    var eligible_versions: [String]
  }
  struct Expected: Decodable {
    var rank: Int
    var name: String
    var shown: Int
    var total: Double
    var tech: Double
    var sound: Double
    var size: Double
    var format: Double
    var picture_w: Double?
    var picture_h: Double?
  }
  var name: String
  var film: FixtureFilm
  var screens: [FixtureScreen]
  var expected: [Expected]

  var scoringFilm: ScoringFilm {
    var versions: [PremiumVersion: VersionStatus] = [:]
    for (k, v) in film.versions {
      versions[PremiumVersion(rawValue: k)!] = VersionStatus(rawValue: v)!
    }
    let imax = film.imax.map {
      ScoringFilm.IMAX(status: VersionStatus(rawValue: $0.status)!, ratio: $0.ratio, share: $0.share)
    }
    return ScoringFilm(ratio: film.ratio, versions: versions, imax: imax, spectacle: film.spectacle ?? false)
  }

  func scoringScreen(_ s: FixtureScreen) -> ScoringScreen {
    ScoringScreen(
      id: s.name, w: s.w, h: s.h, tech: TechTier(rawValue: s.tech)!,
      sound: SoundTier(rawValue: s.sound)!,
      eligibleVersions: Set(s.eligible_versions.map { PremiumVersion(rawValue: $0)! }))
  }

  static func load(_ name: String) throws -> Fixture {
    let url = repoRoot.appending(path: "fixtures/scoring/\(name).json")
    return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
  }
}

@Suite("Parity with ref/score_v2.py")
struct ParityTests {
  @Test(arguments: ["doomsday", "flat", "imax143", "scope_drama", "dolby_vision"])
  func matchesReference(name: String) throws {
    let fixture = try Fixture.load(name)
    let film = fixture.scoringFilm
    var results: [(name: String, parts: ScoreParts)] = []
    for s in fixture.screens {
      results.append((s.name, Scorer.score(screen: fixture.scoringScreen(s), film: film)))
    }
    results.sort { $0.parts.total > $1.parts.total }

    #expect(results.count == fixture.expected.count)
    for (got, want) in zip(results, fixture.expected) {
      #expect(got.name == want.name, "rank \(want.rank)")
      #expect(got.parts.shown == want.shown, "\(want.name) shown")
      #expect(abs(got.parts.total - want.total) < 0.01, "\(want.name) total")
      #expect(got.parts.total == want.total, "\(want.name) total should match bit for bit")
      #expect(got.parts.tech == want.tech)
      #expect(got.parts.sound == want.sound)
      #expect(abs(got.parts.size - want.size) < 1e-9, "\(want.name) size")
      #expect(abs(got.parts.format - want.format) < 1e-9, "\(want.name) format")
      if let w = want.picture_w, let h = want.picture_h {
        #expect(abs((got.parts.pictureW ?? 0) - w) < 1e-9)
        #expect(abs((got.parts.pictureH ?? 0) - h) < 1e-9)
      } else {
        #expect(got.parts.pictureW == nil)
      }
    }
  }

  @Test func premiumProjectorsNeedTheirVersion() throws {
    // v3 (D-38): Dolby Cinema gets 35 only for a Dolby Vision release, 31 when it's expected,
    // and 27 (like an RGB laser) for a regular movie.
    let allu = ScoringScreen(
      id: "allu", w: 75, h: 40.5, tech: .dolbyVisionDualLaser, sound: .dolbyCinemaAtmos,
      eligibleVersions: [.dolbyVision])
    let dv = ScoringFilm(ratio: 2.39, versions: [.dolbyVision: .confirmed], imax: nil)
    let expected = ScoringFilm(ratio: 2.39, versions: [.dolbyVision: .expected], imax: nil)
    let plain = ScoringFilm(ratio: 2.39, versions: [:], imax: nil)
    #expect(Scorer.score(screen: allu, film: dv).tech == 35)
    #expect(Scorer.score(screen: allu, film: expected).tech == 31)
    #expect(Scorer.score(screen: allu, film: plain).tech == 27)
  }

  @Test func spectacleMoviesCountSizeMore() throws {
    let pcx = ScoringScreen(id: "pcx", w: 101.6, h: 64, tech: .laser4K, sound: .atmos, eligibleVersions: [])
    let drama = Scorer.score(screen: pcx, film: ScoringFilm(ratio: 2.39, versions: [:], imax: nil))
    let action = Scorer.score(
      screen: pcx, film: ScoringFilm(ratio: 2.39, versions: [:], imax: nil, spectacle: true))
    #expect(abs(action.size - drama.size * 1.2) < 1e-9)
    #expect(abs(action.tech - drama.tech * 30 / 35) < 1e-9)
    #expect(ScoringFilm(FilmFormats(), genres: ["Drama", "Action"]).spectacle)
    #expect(!ScoringFilm(FilmFormats(), genres: ["Drama", "Comedy"]).spectacle)
  }

  @Test func displayRoundsHalfUpOnce() {
    #expect(Scorer.display(78.5) == 79)
    #expect(Scorer.display(78.4999) == 78)
    #expect(Scorer.display(72.5) == 73)  // not banker's rounding
    #expect(Scorer.display(0) == 0)
  }

  @Test func bands() {
    #expect(Band(shown: 90) == .reference)
    #expect(Band(shown: 85) == .reference)
    #expect(Band(shown: 84) == .excellent)
    #expect(Band(shown: 75) == .excellent)
    #expect(Band(shown: 74) == .great)
    #expect(Band(shown: 65) == .great)
    #expect(Band(shown: 64) == .good)
    #expect(Band(shown: 55) == .good)
    #expect(Band(shown: 54) == .standard)
  }
}
