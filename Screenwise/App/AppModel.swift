import Foundation
import Models
import Observation
import Scoring
import SwiftUI

/// Screens that push onto the one NavigationStack (spec 4.1).
enum Route: Hashable {
  case movie(filmID: String)
  /// `filmID` is nil for "Theatre without a movie".
  case theatre(screenID: String, filmID: String?)
  case you
}

/// Everything else opens as a sheet.
enum SheetRoute: Identifiable, Hashable {
  case explainer(Term, ExplainerExtra?)
  case book(filmID: String, screenID: String)
  case sources(screenID: String)
  case allScreens
  case cinemaTech
  case about
  case city
  case feedback(FeedbackDraft)

  var id: String {
    switch self {
    case .explainer(let t, let e): "explainer-\(t.rawValue)-\(e?.id ?? "")"
    case .book(let f, let s): "book-\(f)-\(s)"
    case .sources(let s): "sources-\(s)"
    case .allScreens: "all"
    case .cinemaTech: "tech"
    case .about: "about"
    case .city: "city"
    case .feedback(let d): "feedback-\(d.id)"
    }
  }
}

/// Extra context for an explainer, e.g. the screen shape box on a Theatre page.
struct ExplainerExtra: Hashable, Sendable {
  var venue: String?
  var screenSize: String?
  var pictureSize: String?
  var isEstimate = false

  var id: String { [venue, screenSize, pictureSize, isEstimate ? "est" : nil].compactMap { $0 }.joined() }
}

/// What a feedback or correction email is about.
struct FeedbackDraft: Hashable, Sendable, Identifiable {
  enum Kind: String, Hashable, Sendable { case correction, missingMovie, general }
  var kind: Kind
  var subject: String
  /// The field being corrected, e.g. "AMB Cinemas Screen 1 · Seats".
  var field: String?
  var id: String { kind.rawValue + subject + (field ?? "") }
}

/// System, Light or Dark (spec 7.1). Stored in UserDefaults.
enum Appearance: String, CaseIterable, Identifiable {
  case system, light, dark
  var id: String { rawValue }
  var label: String {
    switch self {
    case .system: String(localized: "System")
    case .light: String(localized: "Light")
    case .dark: String(localized: "Dark")
    }
  }
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

struct ToastMessage: Equatable, Identifiable {
  let id = UUID()
  let text: String
}

/// The app's single source of truth for data and navigation.
@MainActor
@Observable
final class AppModel {
  private(set) var catalogue: Catalogue
  private(set) var theatres: TheatreData
  private(set) var dataUpdatedAt: Date?
  var user: UserData {
    didSet { if user != oldValue { userStore.save(user) } }
  }

  /// "Near me": the user's position, in memory only (D-39).
  let nearMe = NearMe()

  var path: [Route] = []
  var sheet: SheetRoute?
  var showSearch = false
  var toast: ToastMessage?
  var savedFeedback = 0
  var removedFeedback = 0
  /// The carousel card a Movie page zooms from (spec 7.7).
  var zoomSourceID: String?
  @ObservationIgnored var zoomNamespace: Namespace.ID?

  @ObservationIgnored private let dataStore = DataStore()
  @ObservationIgnored private let userStore = UserStore()
  @ObservationIgnored private var rankingCache: [String: [RankedScreen]] = [:]
  @ObservationIgnored let now: () -> Date

  /// `catalogue` replaces the loaded movie list. Tests use it with a fixed sample list.
  init(now: @escaping () -> Date = { .now }, catalogue override: Catalogue? = nil) {
    self.now = now
    let loaded = dataStore.loadLocal()
    catalogue = override ?? loaded.catalogue
    theatres = loaded.theatres
    dataUpdatedAt = loaded.updatedAt
    user = userStore.load()
  }

  /// Refreshes the data files in the background and re-ranks if anything changed.
  func refresh() async {
    guard let fresh = await dataStore.refresh() else { return }
    // Only move forward: an older download never replaces newer data.
    let newerCatalogue = fresh.catalogue.generatedAt > catalogue.generatedAt
    let newerTheatres = fresh.theatres.updatedOn > theatres.updatedOn
    if newerCatalogue || newerTheatres {
      withAnimation(Motion.push) {
        if newerCatalogue { catalogue = fresh.catalogue }
        if newerTheatres { theatres = fresh.theatres }
      }
      rankingCache = [:]
    }
    dataUpdatedAt = fresh.updatedAt
  }

  // MARK: Lookups

  var today: Date { now() }

  func film(_ id: String) -> Film? { catalogue.films.first { $0.id == id } }
  func screen(_ id: String) -> Screen? { theatres.screen(id) }
  func venue(for screen: Screen) -> Venue? { theatres.venue(screen.venueID) }

  var hasOpenIMAX: Bool {
    theatres.openScreens.contains { $0.eligibleVersions.contains(.imax) || $0.eligibleVersions.contains(.imax143) }
  }

  /// Every open screen ranked for a movie. Cached per movie.
  func ranking(for film: Film) -> [RankedScreen] {
    if let cached = rankingCache[film.id] { return cached }
    let ranked = Ranker.rank(formats: film.formats, genres: film.genres, screens: theatres.openScreens)
    rankingCache[film.id] = ranked
    return ranked
  }

  /// Up to 8 movies for the Home carousel (spec 5.2): released in the last 30 days or due in
  /// the next 120, top 8 by anticipation, then movies in cinemas first and upcoming by date.
  var carouselFilms: [Film] {
    let cal = Calendar.india
    let today = cal.startOfDay(for: self.today)
    guard let from = cal.date(byAdding: .day, value: -30, to: today),
      let to = cal.date(byAdding: .day, value: 120, to: today)
    else { return [] }
    let candidates = catalogue.films.filter { film in
      guard let d = film.releaseDate() else { return false }
      return d >= from && d <= to
    }
    let top = candidates.sorted { ($0.anticipation ?? $0.popularity ?? 0) > ($1.anticipation ?? $1.popularity ?? 0) }
      .prefix(8)
    let showing = top.filter { $0.isInCinemas(on: today) }
      .sorted { ($0.anticipation ?? 0) > ($1.anticipation ?? 0) }
    let upcoming = top.filter { !$0.isInCinemas(on: today) }
      .sorted { ($0.releaseDate() ?? .distantFuture) < ($1.releaseDate() ?? .distantFuture) }
    return showing + upcoming
  }

  /// Movies for "Popular now" in Search.
  var popularFilms: [Film] {
    catalogue.films.sorted { ($0.anticipation ?? $0.popularity ?? 0) > ($1.anticipation ?? $1.popularity ?? 0) }
  }

  /// The one upcoming screen worth a card on this movie's page, if any (spec 5.3).
  func openingSoon(for film: Film) -> Screen? {
    let cal = Calendar.india
    let limit = film.releaseDate().flatMap { cal.date(byAdding: .day, value: 30, to: $0) }
    let candidates = theatres.upcomingScreens.filter { screen in
      guard screen.showOpeningSoon else { return false }
      guard let by = venue(for: screen)?.expectedOpenBy.flatMap({ DayFormatter.date(from: $0) }) else {
        return true  // unknown opening date
      }
      guard let limit else { return true }
      return by <= limit
    }
    let wanted = ScoringFilm(film.formats).versions.keys
    return candidates.sorted { a, b in
      let am = !a.eligibleVersions.isDisjoint(with: wanted)
      let bm = !b.eligibleVersions.isDisjoint(with: wanted)
      if am != bm { return am }
      let ad = venue(for: a)?.expectedOpenBy ?? "9999"
      let bd = venue(for: b)?.expectedOpenBy ?? "9999"
      return ad < bd
    }.first
  }

  /// "Best for": up to 3 current or upcoming movies where this screen ranks in the top 3.
  func bestFor(screenID: String) -> [(film: Film, ranked: RankedScreen)] {
    catalogue.films
      .compactMap { film -> (Film, RankedScreen)? in
        guard let r = ranking(for: film).first(where: { $0.screen.id == screenID }), r.rank <= 3 else { return nil }
        return (film, r)
      }
      .sorted { ($0.0.anticipation ?? 0) > ($1.0.anticipation ?? 0) }
      .prefix(3)
      .map { (film: $0.0, ranked: $0.1) }
  }

  // MARK: Actions

  func open(_ route: Route) {
    path.append(route)
  }

  func openMovie(_ film: Film) {
    recordHistory(.init(kind: .film, id: film.id, filmID: nil, at: now()))
    path.append(.movie(filmID: film.id))
  }

  func openTheatre(_ screen: Screen, film: Film?) {
    recordHistory(.init(kind: .theatre, id: screen.id, filmID: film?.id, at: now()))
    path.append(.theatre(screenID: screen.id, filmID: film?.id))
  }

  func explain(_ term: Term, extra: ExplainerExtra? = nil) {
    sheet = .explainer(term, extra)
  }

  func isSaved(_ screenID: String) -> Bool { user.saved.contains { $0.screenID == screenID } }

  func toggleSaved(_ screenID: String) {
    if isSaved(screenID) {
      user.saved.removeAll { $0.screenID == screenID }
      removedFeedback += 1
      showToast(String(localized: "Removed from saved theatres."))
    } else {
      user.saved.insert(.init(screenID: screenID, savedAt: now()), at: 0)
      savedFeedback += 1
      showToast(String(localized: "Saved. Find it under You."))
    }
  }

  func removeSaved(at offsets: IndexSet) {
    user.saved.remove(atOffsets: offsets)
  }

  func recordHistory(_ item: UserData.HistoryItem) {
    var list = user.history.filter { !($0.kind == item.kind && $0.id == item.id) }
    list.insert(item, at: 0)
    user.history = Array(list.prefix(50))
  }

  func showToast(_ text: String) {
    toast = ToastMessage(text: text)
  }

  /// Marks the movie's formats as seen. Returns true if they changed since last time.
  func noteFormatsSeen(_ film: Film) -> Bool {
    let key = formatsKey(film.formats)
    let old = user.seenFormats[film.id]
    if old != key { user.seenFormats[film.id] = key }
    return old != nil && old != key
  }

  private func formatsKey(_ f: FilmFormats) -> String {
    [
      f.frameRatio.map { "\($0)" } ?? "-", f.frameStatus.rawValue, f.imax.rawValue,
      f.dolbyVision.rawValue, f.hdrBarco.rawValue, f.threeD.rawValue,
    ].joined(separator: "|")
  }

  // MARK: Deep links (spec 4.3)

  func handle(url: URL) {
    let parts: [String]
    if url.scheme == "screenwise" {
      parts = ([url.host].compactMap { $0 } + url.pathComponents.filter { $0 != "/" })
    } else {
      parts = url.pathComponents.filter { $0 != "/" }
    }
    sheet = nil
    showSearch = false
    #if DEBUG
      if parts.first == "debug" { return handleDebug(Array(parts.dropFirst())) }
    #endif
    switch parts.count {
    case 2 where parts[0] == "film":
      if let film = film(parts[1]) { path = [.movie(filmID: film.id)] }
    case 4 where parts[0] == "film" && parts[2] == "screen":
      if let film = film(parts[1]), let screen = screen(parts[3]) {
        path = [.movie(filmID: film.id), .theatre(screenID: screen.id, filmID: film.id)]
      }
    case 2 where parts[0] == "screen":
      if let screen = screen(parts[1]) { path = [.theatre(screenID: screen.id, filmID: nil)] }
    default:
      break
    }
  }

  #if DEBUG
    /// Debug only: opens sheets and screens by link, for screenshots.
    private func handleDebug(_ parts: [String]) {
      let arg = parts.dropFirst().first ?? ""
      switch parts.first {
      case "explain": if let term = Term(rawValue: arg) { sheet = .explainer(term, nil) }
      case "book": if parts.count >= 3 { sheet = .book(filmID: parts[1], screenID: parts[2]) }
      case "sources": sheet = .sources(screenID: arg)
      case "all": sheet = .allScreens
      case "about": sheet = .about
      case "tech": sheet = .cinemaTech
      case "you": path = [.you]
      case "search": showSearch = true
      case "correction": sheet = .feedback(FeedbackDraft(kind: .correction, subject: arg, field: nil))
      default: break
      }
    }
  #endif
}
