import Foundation
import Models
import Scoring
import Testing

@testable import Screenwise

/// A fixed "today" for tests: 19 Nov 2026, 10:00 in Hyderabad.
let testToday: Date = {
  Calendar.india.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 10))!
}()

/// The 8 sample movies from the design, kept as a fixed test list.
let sampleCatalogue: Catalogue = {
  let url = Bundle(for: BundleToken.self).url(forResource: "catalogue.sample", withExtension: "json")!
  return try! JSONDecoder().decode(Catalogue.self, from: Data(contentsOf: url))
}()

private final class BundleToken {}

@MainActor
func sampleModel() -> AppModel { AppModel(now: { testToday }, catalogue: sampleCatalogue) }

@MainActor
@Suite("App model")
struct AppModelTests {
  @Test func carouselFollowsTheSelectionRule() {
    let model = sampleModel()
    let films = model.carouselFilms
    #expect(films.count <= 8)
    // Varanasi releases more than 120 days out, so it isn't in the carousel.
    #expect(!films.contains { $0.id == "sample-varanasi" })
    // Movies in cinemas come first.
    #expect(films.first?.isInCinemas(on: testToday) == true)
    let upcoming = films.drop { $0.isInCinemas(on: testToday) }
    let dates = upcoming.compactMap { $0.releaseDate() }
    #expect(dates == dates.sorted())
  }

  @Test func doomsdayRanksAlluFirst() throws {
    let model = sampleModel()
    let film = try #require(model.film("sample-avengers-doomsday"))
    let ranking = model.ranking(for: film)
    #expect(ranking.first?.screen.id == "allu-s1-dolby")
    #expect(ranking.first?.shown == 90)
  }

  @Test func openingSoonShowsClassicVictoryForIMAXMovies() throws {
    let model = sampleModel()
    let film = try #require(model.film("sample-avengers-doomsday"))
    #expect(model.openingSoon(for: film)?.id == "amb-classic-victory-imax")
  }

  @Test func deepLinks() {
    let model = sampleModel()
    model.handle(url: URL(string: "screenwise://film/sample-king")!)
    #expect(model.path == [.movie(filmID: "sample-king")])
    model.handle(url: URL(string: "screenwise://film/sample-king/screen/amb-s1-hdr")!)
    #expect(model.path == [.movie(filmID: "sample-king"), .theatre(screenID: "amb-s1-hdr", filmID: "sample-king")])
    model.handle(url: URL(string: "screenwise://screen/prasads-pcx")!)
    #expect(model.path == [.theatre(screenID: "prasads-pcx", filmID: nil)])
  }
}

@Suite("Search")
struct SearchTests {
  let films = [
    Film(id: "a", title: "Ramayana: Rise of a Legend", anticipation: 1),
    Film(id: "b", title: "Avengers: Doomsday", anticipation: 0.9),
    Film(id: "c", title: "Pushpa 3", originalTitle: "పుష్ప 3", anticipation: 0.5, aliases: ["Pushpa Three"]),
  ]

  @Test func prefixAndWordMatches() {
    #expect(MovieSearch.search("rama", in: films).first?.id == "a")
    #expect(MovieSearch.search("doomsday", in: films).first?.id == "b")
    #expect(MovieSearch.search("Pushpa three", in: films).first?.id == "c")
    #expect(MovieSearch.search("పుష్ప", in: films).first?.id == "c")
  }

  @Test func smallTyposStillMatch() {
    #expect(MovieSearch.search("avengres", in: films).first?.id == "b")
    #expect(MovieSearch.search("zzzz", in: films).isEmpty)
  }
}

@Suite("Copy rules")
struct CopyTests {
  /// App copy says "movie", never "film", and uses no em or en dashes (spec 0).
  @Test func explainersFollowTheWritingRules() {
    for term in Term.allCases {
      let copy = Explainer.copy(for: term)
      for text in [copy.title, copy.what, copy.why] {
        #expect(!text.lowercased().contains("film"), "\(term): \(text)")
        #expect(!text.contains("\u{2014}") && !text.contains("\u{2013}"), "\(term) has a dash")
      }
      let words = (copy.what + " " + copy.why).split(separator: " ").count
      #expect(words < 60, "\(term) has \(words) words")
    }
  }

  @Test @MainActor func reasonsFollowTheWritingRules() throws {
    let model = sampleModel()
    for film in model.catalogue.films {
      for ranked in model.ranking(for: film) {
        for reason in ranked.pros + ranked.cons {
          let text = Copy.reason(reason, screen: ranked.screen, formats: film.formats)
          #expect(!text.lowercased().contains("film"), "\(text)")
          #expect(!text.contains("\u{2014}") && !text.contains("\u{2013}"), "\(text)")
        }
      }
    }
  }

  @Test func formatPills() {
    let pills = Copy.formatPills(
      FilmFormats(frameRatio: 2.39, frameStatus: .estimated, imax: .expected, imaxRatio: 1.9, dolbyVision: .expected))
    #expect(pills.map(\.text) == ["IMAX · expected", "Dolby Vision · expected", "Scope 2.39 · est."])
    #expect(pills.allSatisfy { $0.isEstimate })
  }

  @Test func statusLine() {
    let film = Film(id: "x", title: "X", releaseDateIN: "2026-12-18")
    #expect(Copy.status(film, today: testToday) == "In cinemas 18 Dec")
    let later = Film(id: "y", title: "Y", releaseDateIN: "2027-04-07")
    #expect(Copy.status(later, today: testToday) == "In cinemas 7 Apr 2027")
    let now = Film(id: "z", title: "Z", releaseDateIN: "2026-11-08")
    #expect(Copy.status(now, today: testToday) == "In cinemas")
  }
}
