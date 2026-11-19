import Foundation
import Models
import Scoring

/// Turns reason codes and data into plain sentences. No language model writes ranking text.
enum Copy {
  // MARK: Reasons

  static func reason(_ reason: Reason, screen: Screen, formats: FilmFormats) -> String {
    switch reason {
    case .bestTechBlackRoom:
      return String(localized: "The best picture technology in the city, in a room built to stay dark.")
    case .hdrFillsScope:
      return String(localized: "Bright, punchy HDR on a wide screen this movie fills edge to edge.")
    case .hdrBright:
      return String(localized: "Bright, punchy HDR from smart laser projection.")
    case .imaxPicture:
      return String(localized: "IMAX projection, with the extra picture that IMAX versions show.")
    case .ledPicture:
      return String(localized: "A self-lit LED screen with deep blacks and bright colours.")
    case .strongPicture:
      return String(localized: "Better picture technology than most theatres here.")
    case .dolbyCinemaSound:
      return String(localized: "Dolby Cinema sound, tuned for the room.")
    case .imaxSound:
      return String(localized: "IMAX sound, tuned for the room.")
    case .strongSound:
      return String(localized: "Better sound than most theatres here.")
    case .biggestPicture:
      return String(localized: "The biggest picture in Hyderabad. Pick a centre seat.")
    case .bigPicture:
      return String(localized: "One of the biggest pictures in Hyderabad for this movie.")
    case .biggerPicture:
      return String(localized: "A bigger picture than most theatres here.")
    case .specialVersion(let version):
      let name = versionName(version)
      if versionStatus(version, formats) == .confirmed {
        return String(localized: "Plays the \(name) version of this movie.")
      }
      return String(localized: "Should get the \(name) version, once the studio confirms it.")
    case .shapeMatch:
      return String(localized: "The screen matches this movie's shape, so the picture fills it.")
    case .techAndSound:
      if screen.techTier == .unknown && screen.soundTier == .unknown {
        return String(localized: "We don't have this screen's projector or sound details yet.")
      }
      return String(localized: "\(techName(screen.techTier)) with \(soundName(screen.soundTier)) sound.")
    case .pictureSizeRank(let w, let h, let rank):
      if rank == 1 {
        return String(localized: "Picture \(w) × \(h) ft for this movie, the biggest we know of in Hyderabad.")
      }
      return String(localized: "Picture \(w) × \(h) ft for this movie, #\(rank) for size of the screens we know.")
    case .flatScreenBands:
      return String(localized: "Flat screen, so wide scope movies get thin bars above and below.")
    case .tallScreenBands(let percent):
      return String(localized: "Tall screen, so this movie uses about \(percent)% of its height.")
    case .scopeScreenBars:
      return String(localized: "Scope screen, so this movie gets bars at the sides.")
    case .smallestPicture:
      return String(localized: "The smallest picture on this list for this movie.")
    case .sizeNotConfirmed:
      return String(localized: "Screen size not confirmed yet.")
    case .sizeReportsDiffer:
      return String(localized: "Reports differ on the screen size.")
    case .projectorNotConfirmed:
      return String(localized: "Projector model not confirmed yet.")
    case .projectorReportsDiffer:
      return String(localized: "Reports differ on the projector.")
    case .soundNotConfirmed:
      return String(localized: "Sound system not confirmed yet.")
    case .seatsNotConfirmed:
      return String(localized: "Seat count not confirmed yet.")
    case .review(let code):
      return reviewNote(code)
    }
  }

  static func reviewNote(_ code: String) -> String {
    switch code {
    case "side_seats_poor": String(localized: "Viewers report weak side seats.")
    case "legroom_tight": String(localized: "Viewers report tight legroom.")
    case "steep_rake": String(localized: "Steep rows, so heads in front rarely block the view.")
    case "crowd_energy_high": String(localized: "A loud, lively crowd on opening days.")
    case "sound_too_loud": String(localized: "Viewers say the sound can be too loud.")
    case "parking_hard": String(localized: "Parking is hard to find.")
    case "metro_nearby": String(localized: "A metro station is nearby.")
    case "food_good": String(localized: "Viewers like the food.")
    case "cleanliness_poor": String(localized: "Viewers report it isn't always clean.")
    default: code.replacingOccurrences(of: "_", with: " ").capitalized
    }
  }

  // MARK: Names

  static func versionName(_ v: PremiumVersion) -> String {
    switch v {
    case .imax, .imax143: "IMAX"
    case .dolbyVision: "Dolby Vision"
    case .hdrBarco: "HDR by Barco"
    case .threeD: "3D"
    }
  }

  static func versionStatus(_ v: PremiumVersion, _ f: FilmFormats) -> VersionStatus {
    switch v {
    case .imax, .imax143: f.imax
    case .dolbyVision: f.dolbyVision
    case .hdrBarco: f.hdrBarco
    case .threeD: f.threeD
    }
  }

  /// The format label, or the projection when a screen has no label (most regular screens).
  static func formatText(_ screen: Screen) -> String {
    screen.formatLabel.isEmpty ? techName(screen.techTier) : screen.formatLabel
  }

  static func techName(_ tier: TechTier) -> String {
    switch tier {
    case .dolbyVisionDualLaser: String(localized: "Dolby Vision projection")
    case .imaxLaserDual143, .imaxLaser190: String(localized: "IMAX laser projection")
    case .hdrBarcoLightsteering: String(localized: "HDR by Barco projection")
    case .directViewLED: String(localized: "An LED screen")
    case .rgbLaser4K: String(localized: "RGB laser projection")
    case .laser4K: String(localized: "4K laser projection")
    case .laser2K: String(localized: "2K laser projection")
    case .xenon4K: String(localized: "4K lamp projection")
    case .xenon2K: String(localized: "2K lamp projection")
    case .unknown: String(localized: "Projection we haven't confirmed")
    }
  }

  static func soundName(_ tier: SoundTier) -> String {
    switch tier {
    case .dolbyCinemaAtmos: String(localized: "Dolby Cinema Atmos")
    case .imax12ch: String(localized: "IMAX 12-channel")
    case .atmos: String(localized: "Dolby Atmos")
    case .dtsx: "DTS:X"
    case .auro11_1: "Auro 11.1"
    case .ch7_1: String(localized: "7.1 surround")
    case .ch5_1: String(localized: "5.1 surround")
    case .unknown: String(localized: "unconfirmed")
    }
  }

  // MARK: Movies

  static func languageName(_ code: String) -> String {
    Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
  }

  static func languages(_ film: Film) -> String {
    let codes = film.languages.isEmpty ? [film.originalLanguage].compactMap { $0 } : film.languages
    return ListFormatter.localizedString(byJoining: codes.map(languageName))
      .replacingOccurrences(of: " and ", with: ", ")
  }

  /// "Hindi, English · Directed by Nitesh Tiwari"
  static func meta(_ film: Film) -> String {
    var parts = [languages(film)].filter { !$0.isEmpty }
    if let d = film.director, !d.isEmpty { parts.append(String(localized: "Directed by \(d)")) }
    return parts.joined(separator: " · ")
  }

  /// "In cinemas" or "In cinemas 18 Dec" (with the year if it isn't this year).
  static func status(_ film: Film, today: Date) -> String {
    if film.isInCinemas(on: today) { return String(localized: "In cinemas") }
    guard let date = film.releaseDate() else { return String(localized: "Release date not set") }
    return String(localized: "In cinemas \(shortDate(date, today: today))")
  }

  static func shortDate(_ date: Date, today: Date) -> String {
    let cal = Calendar.india
    var style = Date.FormatStyle(timeZone: cal.timeZone).day().month(.abbreviated)
    if cal.component(.year, from: date) != cal.component(.year, from: today) {
      style = style.year()
    }
    return date.formatted(style.locale(Locale(identifier: "en_GB")))
  }

  struct FormatPill: Identifiable, Hashable {
    let text: String
    let term: Term
    let isEstimate: Bool
    var id: String { text }
  }

  /// One pill per known fact about the movie's formats (spec 5.3).
  static func formatPills(_ f: FilmFormats) -> [FormatPill] {
    var pills: [FormatPill] = []
    switch f.imax {
    case .confirmed:
      if let r = f.imaxRatio, r < 1.89 {
        pills.append(FormatPill(text: String(localized: "IMAX 1.43 scenes"), term: .imax143, isEstimate: false))
      } else {
        pills.append(FormatPill(text: "IMAX", term: .imax, isEstimate: false))
      }
    case .expected:
      if let r = f.imaxRatio, r < 1.89 {
        pills.append(
          FormatPill(text: String(localized: "IMAX 1.43 scenes · expected"), term: .imax143, isEstimate: true))
      } else {
        pills.append(FormatPill(text: String(localized: "IMAX · expected"), term: .imax, isEstimate: true))
      }
    case .none: break
    }
    switch f.dolbyVision {
    case .confirmed: pills.append(FormatPill(text: "Dolby Vision", term: .dolbyVision, isEstimate: false))
    case .expected:
      pills.append(FormatPill(text: String(localized: "Dolby Vision · expected"), term: .dolbyVision, isEstimate: true))
    case .none: break
    }
    switch f.hdrBarco {
    case .confirmed: pills.append(FormatPill(text: "HDR by Barco", term: .hdrBarco, isEstimate: false))
    case .expected:
      pills.append(FormatPill(text: String(localized: "HDR by Barco · expected"), term: .hdrBarco, isEstimate: true))
    case .none: break
    }
    switch f.threeD {
    case .confirmed: pills.append(FormatPill(text: "3D", term: .threeD, isEstimate: false))
    case .expected: pills.append(FormatPill(text: String(localized: "3D · expected"), term: .threeD, isEstimate: true))
    case .none: break
    }
    let ratio = f.scoringRatio
    let ratioText = ratio.formatted(.number.precision(.fractionLength(2)))
    let name: String
    if ratio >= 2.2 {
      name = String(localized: "Scope \(ratioText)")
    } else if ratio >= 1.7 {
      name = String(localized: "Flat \(ratioText)")
    } else {
      name = String(localized: "Frame \(ratioText)")
    }
    switch f.frameStatus {
    case .confirmed: pills.append(FormatPill(text: name, term: .shape, isEstimate: false))
    case .estimated, .unknown:
      pills.append(FormatPill(text: String(localized: "\(name) · est."), term: .shape, isEstimate: true))
    }
    return pills
  }

  // MARK: Screens

  static func feet(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
  }

  /// The term for a screen's picture technology.
  static func techTerm(_ screen: Screen) -> Term {
    switch screen.techTier {
    case .dolbyVisionDualLaser: return screen.formatLabel == "Dolby Cinema" ? .dolbyCinema : .dolbyVision
    case .hdrBarcoLightsteering: return .hdrBarco
    case .imaxLaserDual143, .imaxLaser190: return .imax
    case .directViewLED: return .led
    case .rgbLaser4K: return .rgbLaser
    default:
      if screen.formatLabel.hasPrefix("EPIQ") { return .epiq }
      if screen.formatLabel == "PCX" { return .pcx }
      return .laser
    }
  }

  struct Fact: Identifiable, Hashable {
    let text: String
    let term: Term?
    var id: String { text }
  }

  /// Up to 3 fact pills for a theatre card.
  static func facts(_ screen: Screen) -> [Fact] {
    var facts: [Fact] = []
    if !screen.formatLabel.isEmpty {
      // No explainer when we don't know the projector (4DX, Macro XE and similar).
      facts.append(Fact(text: screen.formatLabel, term: screen.techTier == .unknown ? nil : techTerm(screen)))
    }
    if let w = screen.widthFt {
      facts.append(Fact(text: String(localized: "\(feet(w)) ft screen"), term: nil))
    }
    switch screen.soundTier {
    case .atmos, .dolbyCinemaAtmos: facts.append(Fact(text: "Dolby Atmos", term: .atmos))
    case .dtsx: facts.append(Fact(text: "DTS:X", term: .dtsx))
    case .imax12ch: facts.append(Fact(text: String(localized: "IMAX sound"), term: .imax))
    default: break
    }
    return Array(facts.prefix(3))
  }

  struct TechRow: Identifiable, Hashable {
    enum Icon: String { case projection = "videoprojector", sound = "speaker.wave.3", screen = "rectangle" }
    let icon: Icon
    let title: String
    let detail: String
    let term: Term
    var id: String { icon.rawValue }
  }

  /// "The tech, in plain English": projection, sound and screen.
  static func techRows(_ screen: Screen) -> [TechRow] {
    let f = screen.fields
    let projectionDetail: String
    switch screen.techTier {
    case .dolbyVisionDualLaser: projectionDetail = String(localized: "Two 4K laser projectors working together")
    case .hdrBarcoLightsteering: projectionDetail = String(localized: "Brighter highlights from smart laser projection")
    case .directViewLED: projectionDetail = String(localized: "No projector. The screen gives off its own light.")
    default:
      switch f.projection.status {
      case .sourced: projectionDetail = String(localized: "Bright and sharp")
      case .conflicting: projectionDetail = String(localized: "Brand reported differently")
      case .unverified, .unknown: projectionDetail = String(localized: "Projector model not confirmed")
      }
    }
    let projectionTitle: String =
      screen.formatLabel.hasPrefix("EPIQ") && screen.techTier != .directViewLED
      ? String(localized: "EPIQ with 4K projection")
      : techName(screen.techTier).replacingOccurrences(of: "An LED screen", with: "LED screen")

    let channels = f.sound.value.flatMap(atmosChannels)
    var soundTitle = soundName(screen.soundTier)
    if screen.soundTier == .dolbyCinemaAtmos { soundTitle = "Dolby Atmos" }
    if let channels { soundTitle += String(localized: ", \(channels) channels") }
    let soundTerm: Term = screen.soundTier == .dtsx ? .dtsx : .atmos

    var screenTitle = String(localized: "Screen size not confirmed")
    var screenDetail = String(localized: "Size not confirmed")
    if let w = screen.widthFt, let h = screen.heightFt, let ratio = screen.shapeRatio {
      let shape = ScreenShape(ratio: ratio)
      screenTitle = String(localized: "\(shape.label) screen, \(feet(w)) × \(feet(h)) ft")
      switch (f.widthFt.status, f.heightFt.status) {
      case (.sourced, .sourced):
        switch shape {
        case .scope: screenDetail = String(localized: "Wide movies fill it edge to edge")
        case .flat: screenDetail = String(localized: "A taller screen shape")
        case .tall: screenDetail = String(localized: "Taller than most movies")
        }
      case (.conflicting, _), (_, .conflicting): screenDetail = String(localized: "Reports differ slightly")
      default: screenDetail = String(localized: "Size not confirmed")
      }
    }
    return [
      TechRow(icon: .projection, title: projectionTitle, detail: projectionDetail, term: techTerm(screen)),
      TechRow(
        icon: .sound, title: soundTitle, detail: String(localized: "Sound all around and above you"), term: soundTerm),
      TechRow(icon: .screen, title: screenTitle, detail: screenDetail, term: .shape),
    ]
  }

  /// "64" from "Dolby Atmos, 64-channel".
  static func atmosChannels(_ text: String) -> Int? {
    guard !text.contains("fan graphic") else { return nil }
    let pattern = /(\d{2})-channel/
    return text.firstMatch(of: pattern).flatMap { Int($0.1) }
  }

  /// "Screen 1 · Gachibowli"-style sub line pieces.
  static func hallLine(_ screen: Screen, venue: Venue?) -> String {
    let format = screen.formatLabel.isEmpty || screen.hall.contains(screen.formatLabel) ? nil : screen.formatLabel
    return [screen.hall, format, venue?.area].compactMap { $0 }.joined(separator: " · ")
  }
}
