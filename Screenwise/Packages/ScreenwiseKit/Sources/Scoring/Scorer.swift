import Foundation
import Models

/// Screen Score v2 (spec section 9). A line by line port of `ref/score_v2.py`.
///
/// Keep the order of every arithmetic step the same as the Python, so the doubles match
/// bit for bit. The parity tests in `ScoringTests` check this against `fixtures/scoring`.
public enum Scorer {
  public static let version = "v2"

  /// Size curve anchors in square feet. Fixed for the city.
  static let areaMin = 300.0
  static let areaMax = 4500.0
  static let sizeWeight = 25.0
  /// Size points when width or height is unknown. Conservative and low confidence.
  public static let unknownSizePoints = 8.0

  public static func techPoints(_ tier: TechTier) -> Double {
    switch tier {
    case .dolbyVisionDualLaser, .imaxLaserDual143: 35
    case .hdrBarcoLightsteering: 31
    case .imaxLaser190, .directViewLED: 30
    case .rgbLaser4K: 27
    case .laser4K: 23
    case .laser2K: 17
    case .xenon4K: 16
    case .xenon2K: 12
    case .unknown: 14
    }
  }

  public static func soundPoints(_ tier: SoundTier) -> Double {
    switch tier {
    case .dolbyCinemaAtmos, .imax12ch: 25
    case .atmos: 22
    case .dtsx, .auro11_1: 18
    case .ch7_1: 13
    case .ch5_1: 10
    case .unknown: 12
    }
  }

  /// The largest rectangle in the movie's frame that fits the screen.
  public static func picture(screenW: Double, screenH: Double, filmRatio: Double) -> (
    w: Double, h: Double
  ) {
    if screenW / screenH <= filmRatio {
      return (screenW, screenW / filmRatio)  // constant width
    }
    return (screenH * filmRatio, screenH)  // constant height
  }

  public static func sizePoints(area: Double) -> Double {
    let x = (log(area) - log(areaMin)) / (log(areaMax) - log(areaMin))
    return sizeWeight * min(1.0, max(0.0, x))
  }

  public static func shapeMatches(screen: ScoringScreen, filmRatio: Double) -> Bool {
    guard let w = screen.w, let h = screen.h, w != 0, h != 0 else { return false }
    return abs((w / h) - filmRatio) / filmRatio <= 0.05
  }

  public static func formatPoints(screen: ScoringScreen, film: ScoringFilm) -> Double {
    let base: Double = shapeMatches(screen: screen, filmRatio: film.ratio) ? 10 : 7
    var best = base
    for (version, status) in film.versions {
      guard let ceiling = ceiling(for: version, screen: screen, film: film) else { continue }
      switch status {
      case .confirmed: best = max(best, ceiling)
      case .expected: best = max(best, base + (ceiling - base) * 0.5)
      case .none: break
      }
    }
    return best
  }

  /// Highest format points this screen can reach for one version, or nil if it can't play it.
  static func ceiling(for version: PremiumVersion, screen: ScoringScreen, film: ScoringFilm)
    -> Double?
  {
    switch version {
    case .imax:
      let wants143 = (film.imax?.ratio ?? 1.90) < 1.89
      if screen.eligibleVersions.contains(.imax143) { return 15 }
      if screen.eligibleVersions.contains(.imax) { return wants143 ? 13 : 15 }
      return nil
    case .imax143, .threeD:
      // 1.43 is folded into `imax`. 3D only counts when the user asks for it (v1.1).
      return nil
    case .dolbyVision, .hdrBarco:
      return screen.eligibleVersions.contains(version) ? 15 : nil
    }
  }

  /// Picture size and area for this movie, blending IMAX expanded scenes when the screen gets them.
  public static func pictureArea(screenW: Double, screenH: Double, film: ScoringFilm, screen: ScoringScreen)
    -> (w: Double, h: Double, area: Double)
  {
    let (w, h) = picture(screenW: screenW, screenH: screenH, filmRatio: film.ratio)
    var area = w * h
    if let imax = film.imax,
      screen.eligibleVersions.contains(.imax) || screen.eligibleVersions.contains(.imax143)
    {
      var ratio = imax.ratio
      if ratio < 1.89 && !screen.eligibleVersions.contains(.imax143) {
        ratio = 1.90  // a 1.90 IMAX screen shows 1.43 scenes cropped to 1.90
      }
      let (ew, eh) = picture(screenW: screenW, screenH: screenH, filmRatio: ratio)
      var share = imax.share ?? 0.4
      if imax.status == .expected { share = share / 2 }
      area = area * (1 - share) + ew * eh * share
    }
    return (w, h, area)
  }

  public static func score(screen: ScoringScreen, film: ScoringFilm) -> ScoreParts {
    let size: Double
    var pictureW: Double?
    var pictureH: Double?
    var area = 0.0
    if let sw = screen.w, let sh = screen.h {
      let p = pictureArea(screenW: sw, screenH: sh, film: film, screen: screen)
      pictureW = p.w
      pictureH = p.h
      area = p.area
      size = sizePoints(area: p.area)
    } else {
      size = unknownSizePoints
    }
    let tech = techPoints(screen.tech)
    let format = formatPoints(screen: screen, film: film)
    let sound = soundPoints(screen.sound)
    let total = size + tech + format + sound  // unrounded; round only for display
    return ScoreParts(
      tech: tech, sound: sound, size: size, format: format, total: total,
      pictureW: pictureW, pictureH: pictureH, area: area,
      shapeMatch: shapeMatches(screen: screen, filmRatio: film.ratio))
  }

  /// Shown score: round half up, once, from the unrounded total. Never round twice.
  public static func display(_ total: Double) -> Int {
    Int((total + 0.5).rounded(.down))
  }
}

/// The score inputs for one screen.
public struct ScoringScreen: Sendable, Hashable {
  public var id: String
  public var w: Double?
  public var h: Double?
  public var tech: TechTier
  public var sound: SoundTier
  public var eligibleVersions: Set<PremiumVersion>

  public init(
    id: String, w: Double?, h: Double?, tech: TechTier, sound: SoundTier,
    eligibleVersions: Set<PremiumVersion>
  ) {
    self.id = id
    self.w = w
    self.h = h
    self.tech = tech
    self.sound = sound
    self.eligibleVersions = eligibleVersions
  }

  public init(_ screen: Screen) {
    self.init(
      id: screen.id, w: screen.widthFt, h: screen.heightFt, tech: screen.techTier,
      sound: screen.soundTier, eligibleVersions: screen.eligibleVersions)
  }
}

/// The score inputs for one movie.
public struct ScoringFilm: Sendable, Hashable {
  public struct IMAX: Sendable, Hashable {
    public var status: VersionStatus
    public var ratio: Double
    public var share: Double?

    public init(status: VersionStatus, ratio: Double, share: Double?) {
      self.status = status
      self.ratio = ratio
      self.share = share
    }
  }

  public var ratio: Double
  public var versions: [PremiumVersion: VersionStatus]
  public var imax: IMAX?

  public init(ratio: Double, versions: [PremiumVersion: VersionStatus], imax: IMAX?) {
    self.ratio = ratio
    self.versions = versions
    self.imax = imax
  }

  public init(_ formats: FilmFormats) {
    var versions: [PremiumVersion: VersionStatus] = [:]
    if formats.imax != .none { versions[.imax] = formats.imax }
    if formats.dolbyVision != .none { versions[.dolbyVision] = formats.dolbyVision }
    if formats.hdrBarco != .none { versions[.hdrBarco] = formats.hdrBarco }
    let imax: IMAX? =
      formats.imax == .none
      ? nil
      : IMAX(status: formats.imax, ratio: formats.imaxRatio ?? 1.90, share: formats.imaxExpandedShare)
    self.init(ratio: formats.scoringRatio, versions: versions, imax: imax)
  }
}

public struct ScoreParts: Sendable, Hashable {
  public var tech: Double
  public var sound: Double
  public var size: Double
  public var format: Double
  /// Unrounded. Use `shown` for display.
  public var total: Double
  public var pictureW: Double?
  public var pictureH: Double?
  /// Picture area in square feet, IMAX blend included. 0 when the size is unknown.
  public var area: Double
  public var shapeMatch: Bool

  public var shown: Int { Scorer.display(total) }
}

/// The word next to the score (spec 9.6).
public enum Band: String, Sendable, CaseIterable {
  case reference, excellent, great, good, standard

  public init(shown: Int) {
    switch shown {
    case 85...: self = .reference
    case 75..<85: self = .excellent
    case 65..<75: self = .great
    case 55..<65: self = .good
    default: self = .standard
    }
  }

  public var label: String {
    switch self {
    case .reference: "Reference"
    case .excellent: "Excellent"
    case .great: "Great"
    case .good: "Good"
    case .standard: "Standard"
    }
  }
}
