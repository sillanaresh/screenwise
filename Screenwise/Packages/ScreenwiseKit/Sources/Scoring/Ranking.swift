import Foundation
import Models

/// One screen's place in the ranking for one movie.
public struct RankedScreen: Sendable, Identifiable, Hashable {
  public let screen: Screen
  public let parts: ScoreParts
  /// 1-based rank in score order.
  public let rank: Int
  /// 1-based rank by picture area for this movie, or nil when the size is unknown.
  public let sizeRank: Int?
  public let mainReason: Reason
  public let pros: [Reason]
  public let cons: [Reason]

  public var id: String { screen.id }
  public var shown: Int { parts.shown }
  public var band: Band { Band(shown: parts.shown) }
  public var isLowConfidence: Bool { screen.isLowConfidence }
}

/// Ranks screens for a movie and picks the reason codes (spec 9.6).
///
/// Explanations are codes, never generated text. The app maps each code to a plain sentence.
public enum Ranker {
  public static func rank(formats: FilmFormats, screens: [Screen]) -> [RankedScreen] {
    let film = ScoringFilm(formats)
    let scored = screens.map { (screen: $0, parts: Scorer.score(screen: ScoringScreen($0), film: film)) }
    let ordered = scored.sorted { a, b in
      if a.parts.total != b.parts.total { return a.parts.total > b.parts.total }
      if a.parts.area != b.parts.area { return a.parts.area > b.parts.area }
      if a.screen.name != b.screen.name { return a.screen.name < b.screen.name }
      return a.screen.id < b.screen.id
    }

    let sized = ordered.filter { $0.parts.pictureW != nil }.sorted { $0.parts.area > $1.parts.area }
    let sizeRanks = Dictionary(
      uniqueKeysWithValues: sized.enumerated().map { ($0.element.screen.id, $0.offset + 1) })
    let medians = Medians(ordered)
    let maxTech = ordered.map(\.parts.tech).max() ?? 0

    return ordered.enumerated().map { index, item in
      let context = ReasonContext(
        screen: item.screen, parts: item.parts, film: film, formats: formats, medians: medians,
        maxTech: maxTech, sizeRank: sizeRanks[item.screen.id], sizedCount: sized.count)
      let main = context.mainReason()
      return RankedScreen(
        screen: item.screen, parts: item.parts, rank: index + 1,
        sizeRank: sizeRanks[item.screen.id], mainReason: main, pros: context.pros(main: main),
        cons: context.cons())
    }
  }
}

/// City medians for each part of the score, over the screens where that part is known.
/// An unknown projector, sound system or size isn't a low value, so it must not pull the median
/// down and make every known screen look above average (decision D-34).
struct Medians {
  var tech: Double
  var sound: Double
  var size: Double
  var format: Double

  init(_ scored: [(screen: Screen, parts: ScoreParts)]) {
    let sized = scored.filter { $0.parts.pictureW != nil }
    tech = Self.median(scored.filter { $0.screen.techTier != .unknown }.map(\.parts.tech))
    sound = Self.median(scored.filter { $0.screen.soundTier != .unknown }.map(\.parts.sound))
    size = Self.median(sized.map(\.parts.size))
    format = Self.median(sized.map(\.parts.format))
  }

  static func median(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    let s = values.sorted()
    let mid = s.count / 2
    return s.count % 2 == 1 ? s[mid] : (s[mid - 1] + s[mid]) / 2
  }
}

struct ReasonContext {
  let screen: Screen
  let parts: ScoreParts
  let film: ScoringFilm
  let formats: FilmFormats
  let medians: Medians
  let maxTech: Double
  let sizeRank: Int?
  let sizedCount: Int

  enum Component: CaseIterable { case tech, sound, size, format }

  /// The component where this screen beats the city median by the most.
  /// Ties go to tech, then sound, then size, then format.
  func mainComponent() -> Component? {
    let deltas: [(Component, Double)] = [
      (.tech, parts.tech - medians.tech),
      (.sound, parts.sound - medians.sound),
      (.size, parts.size - medians.size),
      (.format, parts.format - medians.format),
    ]
    var best: (Component, Double)?
    for d in deltas where d.1 > 1e-9 {
      if best == nil || d.1 > best!.1 + 1e-9 { best = d }
    }
    return best?.0
  }

  /// The best premium version this screen gets for this movie, if any.
  var matchedVersion: PremiumVersion? {
    let order: [PremiumVersion] = [.imax, .dolbyVision, .hdrBarco]
    return order.first { v in
      guard let status = film.versions[v], status != .none else { return false }
      return Scorer.ceiling(for: v, screen: ScoringScreen(screen), film: film) != nil
    }
  }

  var screenShape: ScreenShape? { screen.shapeRatio.map(ScreenShape.init(ratio:)) }

  func mainReason() -> Reason {
    switch mainComponent() {
    case .tech: return techReason()
    case .sound: return soundReason()
    case .size: return sizeReason()
    case .format:
      if let v = matchedVersion { return .specialVersion(v) }
      return .shapeMatch
    case nil: return .techAndSound
    }
  }

  func techReason() -> Reason {
    switch screen.techTier {
    case .dolbyVisionDualLaser where parts.tech >= maxTech: return .bestTechBlackRoom
    case .imaxLaserDual143, .imaxLaser190: return .imaxPicture
    case .hdrBarcoLightsteering:
      return parts.shapeMatch && screenShape == .scope ? .hdrFillsScope : .hdrBright
    case .directViewLED: return .ledPicture
    default: return .strongPicture
    }
  }

  func soundReason() -> Reason {
    switch screen.soundTier {
    case .dolbyCinemaAtmos: .dolbyCinemaSound
    case .imax12ch: .imaxSound
    default: .strongSound
    }
  }

  func sizeReason() -> Reason {
    guard let rank = sizeRank else { return .biggerPicture }
    if rank == 1 { return .biggestPicture }
    if rank <= 3 { return .bigPicture }
    return .biggerPicture
  }

  /// "Why it suits this movie": 2 to 4 lines. The main reason comes first, then picture size.
  func pros(main: Reason) -> [Reason] {
    var list: [Reason] = [main]
    if let w = parts.pictureW, let h = parts.pictureH, let rank = sizeRank {
      list.append(.pictureSizeRank(w: Int(w.rounded()), h: Int(h.rounded()), rank: rank))
    }
    if parts.shapeMatch && main != .shapeMatch {
      list.append(.shapeMatch)
    }
    if let v = matchedVersion, main != .specialVersion(v) {
      list.append(.specialVersion(v))
    }
    if parts.sound > medians.sound + 1e-9 && !list.contains(soundReason()) {
      list.append(soundReason())
    }
    if parts.tech > medians.tech + 1e-9 && !list.contains(techReason()) {
      list.append(techReason())
    }
    for note in screen.reviewNotes where Reason.positiveReviewCodes.contains(note.code) {
      list.append(.review(note.code))
    }
    return Array(list.prefix(4))
  }

  func cons() -> [Reason] {
    var list: [Reason] = []
    if let ratio = screen.shapeRatio, let ph = parts.pictureH, let sh = screen.heightFt {
      if film.ratio >= 2.2 && ratio < film.ratio * 0.95 {
        if ScreenShape(ratio: ratio) == .tall {
          list.append(.tallScreenBands(percentOfHeight: Int((ph / sh * 100).rounded())))
        } else {
          list.append(.flatScreenBands)
        }
      } else if film.ratio < 2.2 && ratio > film.ratio * 1.05 {
        list.append(.scopeScreenBars)
      }
    }
    if let rank = sizeRank, rank == sizedCount, sizedCount > 2 {
      list.append(.smallestPicture)
    }
    for note in screen.reviewNotes where !Reason.positiveReviewCodes.contains(note.code) {
      list.append(.review(note.code))
    }
    let f = screen.fields
    if f.widthFt.status == .conflicting || f.heightFt.status == .conflicting {
      list.append(.sizeReportsDiffer)
    } else if !f.widthFt.status.isConfirmed || !f.heightFt.status.isConfirmed {
      list.append(.sizeNotConfirmed)
    }
    switch f.projection.status {
    case .conflicting: list.append(.projectorReportsDiffer)
    case .unverified, .unknown: list.append(.projectorNotConfirmed)
    case .sourced: break
    }
    if f.sound.status != .sourced { list.append(.soundNotConfirmed) }
    if f.seats.status != .sourced { list.append(.seatsNotConfirmed) }
    return list
  }
}

/// Why a screen suits (or doesn't suit) a movie. Codes, not prose (spec 9.6).
public enum Reason: Hashable, Sendable {
  // Main reasons and pros
  case bestTechBlackRoom
  case hdrFillsScope
  case hdrBright
  case imaxPicture
  case ledPicture
  case strongPicture
  case dolbyCinemaSound
  case imaxSound
  case strongSound
  case biggestPicture
  case bigPicture
  case biggerPicture
  case specialVersion(PremiumVersion)
  case shapeMatch
  case techAndSound
  case pictureSizeRank(w: Int, h: Int, rank: Int)
  // Cons
  case flatScreenBands
  case tallScreenBands(percentOfHeight: Int)
  case scopeScreenBars
  case smallestPicture
  case sizeNotConfirmed
  case sizeReportsDiffer
  case projectorNotConfirmed
  case projectorReportsDiffer
  case soundNotConfirmed
  case seatsNotConfirmed
  /// A repeated point from reviews, e.g. "side_seats_poor".
  case review(String)

  /// Review codes that count in a screen's favour. The rest are cons.
  public static let positiveReviewCodes: Set<String> = [
    "steep_rake", "crowd_energy_high", "metro_nearby", "food_good",
  ]

  /// Stable snake_case code, matching the spec's naming.
  public var code: String {
    switch self {
    case .bestTechBlackRoom: "best_tech_black_room"
    case .hdrFillsScope: "hdr_fills_scope"
    case .hdrBright: "hdr_bright"
    case .imaxPicture: "imax_picture"
    case .ledPicture: "led_picture"
    case .strongPicture: "strong_picture"
    case .dolbyCinemaSound: "dolby_cinema_sound"
    case .imaxSound: "imax_sound"
    case .strongSound: "strong_sound"
    case .biggestPicture: "biggest_picture"
    case .bigPicture: "big_picture"
    case .biggerPicture: "bigger_picture"
    case .specialVersion: "special_version"
    case .shapeMatch: "shape_match"
    case .techAndSound: "tech_and_sound"
    case .pictureSizeRank: "picture_size_rank"
    case .flatScreenBands: "flat_screen_bands"
    case .tallScreenBands: "tall_screen_bands"
    case .scopeScreenBars: "scope_screen_bars"
    case .smallestPicture: "smallest_picture"
    case .sizeNotConfirmed: "size_not_confirmed"
    case .sizeReportsDiffer: "size_reports_differ"
    case .projectorNotConfirmed: "projector_not_confirmed"
    case .projectorReportsDiffer: "projector_reports_differ"
    case .soundNotConfirmed: "sound_not_confirmed"
    case .seatsNotConfirmed: "seats_not_confirmed"
    case .review(let code): code
    }
  }
}
