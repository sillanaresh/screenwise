import Foundation

/// Root of `data/screens.json`: the Hyderabad venues and screens we cover, with sources.
public struct TheatreData: Codable, Sendable, Hashable {
  public var schemaVersion: Int
  public var updatedOn: String
  public var city: City
  public var sources: [Source]
  public var venues: [Venue]
  public var screens: [Screen]

  public init(
    schemaVersion: Int, updatedOn: String, city: City, sources: [Source], venues: [Venue],
    screens: [Screen]
  ) {
    self.schemaVersion = schemaVersion
    self.updatedOn = updatedOn
    self.city = city
    self.sources = sources
    self.venues = venues
    self.screens = screens
  }

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case updatedOn = "updated_on"
    case city, sources, venues, screens
  }

  public func venue(_ id: String) -> Venue? { venues.first { $0.id == id } }
  public func screen(_ id: String) -> Screen? { screens.first { $0.id == id } }
  public func source(_ id: String) -> Source? { sources.first { $0.id == id } }

  /// Screens that are open and can be ranked.
  public var openScreens: [Screen] { screens.filter { $0.status == .open } }
  /// Screens announced but not open yet.
  public var upcomingScreens: [Screen] { screens.filter { $0.status == .upcoming } }
}

public struct City: Codable, Sendable, Hashable {
  public var id: String
  public var name: String
  public var timezone: String
}

public struct Source: Codable, Sendable, Hashable, Identifiable {
  public enum Kind: String, Codable, Sendable {
    case official, press, news, listing, userPhoto = "user_photo", other
  }

  public var id: String
  public var title: String
  public var publisher: String?
  public var url: URL?
  public var publishedOn: String?
  public var kind: Kind

  enum CodingKeys: String, CodingKey {
    case id, title, publisher, url, kind
    case publishedOn = "published_on"
  }

  /// Short name for "Sourced · {source}" lines.
  public var shortName: String { publisher ?? "fan graphic only" }
}

public enum LifecycleStatus: String, Codable, Sendable {
  case open, upcoming, closed, renovating
}

public struct Venue: Codable, Sendable, Hashable, Identifiable {
  public enum VenueType: String, Codable, Sendable {
    case multiplex
    case singleScreen = "single_screen"
  }

  public var id: String
  public var name: String
  /// Short area for copy, e.g. "Kokapet".
  public var area: String
  public var areaDetail: String?
  public var venueType: VenueType
  public var status: LifecycleStatus
  public var openedOn: String?
  public var openedSources: [String]
  /// Free text for upcoming venues, e.g. "late November or December 2026".
  public var expectedOpen: String?
  /// Latest likely opening date (yyyy-MM-dd), so code can compare it with a release date.
  public var expectedOpenBy: String?
  public var bookmyshowURL: URL?
  public var districtURL: URL?

  enum CodingKeys: String, CodingKey {
    case id, name, area, status
    case areaDetail = "area_detail"
    case venueType = "venue_type"
    case openedOn = "opened_on"
    case openedSources = "opened_sources"
    case expectedOpen = "expected_open"
    case expectedOpenBy = "expected_open_by"
    case bookmyshowURL = "bookmyshow_url"
    case districtURL = "district_url"
  }
}

/// Picture technology tiers (spec 9.3).
public enum TechTier: String, Codable, Sendable, CaseIterable {
  case dolbyVisionDualLaser = "dolby_vision_dual_laser"
  case imaxLaserDual143 = "imax_laser_dual_143"
  case hdrBarcoLightsteering = "hdr_barco_lightsteering"
  case imaxLaser190 = "imax_laser_190"
  case directViewLED = "direct_view_led"
  case rgbLaser4K = "rgb_laser_4k"
  case laser4K = "laser_4k"
  case laser2K = "laser_2k"
  case xenon4K = "xenon_4k"
  case xenon2K = "xenon_2k"
  case unknown

  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = TechTier(rawValue: raw) ?? .unknown
  }
}

/// Sound system tiers (spec 9.5).
public enum SoundTier: String, Codable, Sendable, CaseIterable {
  case dolbyCinemaAtmos = "dolby_cinema_atmos"
  case imax12ch = "imax_12ch"
  case atmos
  case dtsx
  case auro11_1 = "auro_11_1"
  case ch7_1 = "ch_7_1"
  case ch5_1 = "ch_5_1"
  case unknown

  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = SoundTier(rawValue: raw) ?? .unknown
  }
}

/// Versions of a movie made for a format. A screen lists the ones it can play.
public enum PremiumVersion: String, Codable, Sendable, CaseIterable {
  case imax
  case imax143 = "imax_143"
  case dolbyVision = "dolby_vision"
  case hdrBarco = "hdr_barco"
  case threeD = "3d"
}

public struct ScreenFields: Codable, Sendable, Hashable {
  public var brandFormat: FieldValue<String>?
  public var widthFt: FieldValue<Double>
  public var heightFt: FieldValue<Double>
  public var shape: FieldValue<String>?
  public var seats: FieldValue<Int>
  public var projection: FieldValue<String>
  public var sound: FieldValue<String>
  public var knownIssues: FieldValue<String>?
  public var imaxCertified: FieldValue<Bool>?

  public init(
    brandFormat: FieldValue<String>? = nil, widthFt: FieldValue<Double> = .unknown,
    heightFt: FieldValue<Double> = .unknown, shape: FieldValue<String>? = nil,
    seats: FieldValue<Int> = .unknown, projection: FieldValue<String> = .unknown,
    sound: FieldValue<String> = .unknown, knownIssues: FieldValue<String>? = nil,
    imaxCertified: FieldValue<Bool>? = nil
  ) {
    self.brandFormat = brandFormat
    self.widthFt = widthFt
    self.heightFt = heightFt
    self.shape = shape
    self.seats = seats
    self.projection = projection
    self.sound = sound
    self.knownIssues = knownIssues
    self.imaxCertified = imaxCertified
  }

  enum CodingKeys: String, CodingKey {
    case brandFormat = "brand_format"
    case widthFt = "width_ft"
    case heightFt = "height_ft"
    case shape, seats, projection, sound
    case knownIssues = "known_issues"
    case imaxCertified = "imax_certified"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    brandFormat = try c.decodeIfPresent(FieldValue<String>.self, forKey: .brandFormat)
    widthFt = try c.decodeIfPresent(FieldValue<Double>.self, forKey: .widthFt) ?? .unknown
    heightFt = try c.decodeIfPresent(FieldValue<Double>.self, forKey: .heightFt) ?? .unknown
    shape = try c.decodeIfPresent(FieldValue<String>.self, forKey: .shape)
    seats = try c.decodeIfPresent(FieldValue<Int>.self, forKey: .seats) ?? .unknown
    projection = try c.decodeIfPresent(FieldValue<String>.self, forKey: .projection) ?? .unknown
    sound = try c.decodeIfPresent(FieldValue<String>.self, forKey: .sound) ?? .unknown
    knownIssues = try c.decodeIfPresent(FieldValue<String>.self, forKey: .knownIssues)
    imaxCertified = try c.decodeIfPresent(FieldValue<Bool>.self, forKey: .imaxCertified)
  }
}

/// A repeated point from reviews or articles, as a code (spec 11.7).
public struct ReviewNote: Codable, Sendable, Hashable {
  public var code: String
  public var sourceIDs: [String]

  enum CodingKeys: String, CodingKey {
    case code
    case sourceIDs = "sources"
  }
}

/// One auditorium. The app calls it a theatre in copy.
public struct Screen: Codable, Sendable, Hashable, Identifiable {
  public var id: String
  public var venueID: String
  public var name: String
  /// Short hall label for copy, e.g. "Screen 1".
  public var hall: String
  public var status: LifecycleStatus
  /// Short format label, e.g. "Dolby Cinema" or "4K laser".
  public var formatLabel: String
  public var techTier: TechTier
  public var soundTier: SoundTier
  public var eligibleVersions: Set<PremiumVersion>
  public var recliners: Bool?
  public var rowsCount: Int?
  public var firstRowFt: Double?
  public var rowPitchFt: Double?
  public var fields: ScreenFields
  public var reviewNotes: [ReviewNote]
  public var showOpeningSoon: Bool
  public var openingNote: String?

  public init(
    id: String, venueID: String, name: String, hall: String, status: LifecycleStatus = .open,
    formatLabel: String, techTier: TechTier, soundTier: SoundTier,
    eligibleVersions: Set<PremiumVersion> = [], recliners: Bool? = nil, rowsCount: Int? = nil,
    firstRowFt: Double? = nil, rowPitchFt: Double? = nil, fields: ScreenFields,
    reviewNotes: [ReviewNote] = [], showOpeningSoon: Bool = false, openingNote: String? = nil
  ) {
    self.id = id
    self.venueID = venueID
    self.name = name
    self.hall = hall
    self.status = status
    self.formatLabel = formatLabel
    self.techTier = techTier
    self.soundTier = soundTier
    self.eligibleVersions = eligibleVersions
    self.recliners = recliners
    self.rowsCount = rowsCount
    self.firstRowFt = firstRowFt
    self.rowPitchFt = rowPitchFt
    self.fields = fields
    self.reviewNotes = reviewNotes
    self.showOpeningSoon = showOpeningSoon
    self.openingNote = openingNote
  }

  enum CodingKeys: String, CodingKey {
    case id, name, hall, status, recliners, fields
    case venueID = "venue_id"
    case formatLabel = "format_label"
    case techTier = "tech_tier"
    case soundTier = "sound_tier"
    case eligibleVersions = "eligible_versions"
    case rowsCount = "rows_count"
    case firstRowFt = "first_row_ft"
    case rowPitchFt = "row_pitch_ft"
    case reviewNotes = "review_notes"
    case showOpeningSoon = "show_opening_soon"
    case openingNote = "opening_note"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    venueID = try c.decode(String.self, forKey: .venueID)
    name = try c.decode(String.self, forKey: .name)
    hall = try c.decode(String.self, forKey: .hall)
    status = try c.decode(LifecycleStatus.self, forKey: .status)
    formatLabel = try c.decode(String.self, forKey: .formatLabel)
    techTier = try c.decode(TechTier.self, forKey: .techTier)
    soundTier = try c.decode(SoundTier.self, forKey: .soundTier)
    let versions = try c.decodeIfPresent([String].self, forKey: .eligibleVersions) ?? []
    eligibleVersions = Set(versions.compactMap(PremiumVersion.init(rawValue:)))
    recliners = try c.decodeIfPresent(Bool.self, forKey: .recliners)
    rowsCount = try c.decodeIfPresent(Int.self, forKey: .rowsCount)
    firstRowFt = try c.decodeIfPresent(Double.self, forKey: .firstRowFt)
    rowPitchFt = try c.decodeIfPresent(Double.self, forKey: .rowPitchFt)
    fields = try c.decode(ScreenFields.self, forKey: .fields)
    reviewNotes = try c.decodeIfPresent([ReviewNote].self, forKey: .reviewNotes) ?? []
    showOpeningSoon = try c.decodeIfPresent(Bool.self, forKey: .showOpeningSoon) ?? false
    openingNote = try c.decodeIfPresent(String.self, forKey: .openingNote)
  }

  public var widthFt: Double? { fields.widthFt.value }
  public var heightFt: Double? { fields.heightFt.value }
  public var seats: Int? { fields.seats.value }

  /// Screen width ÷ height, when both are known.
  public var shapeRatio: Double? {
    guard let w = widthFt, let h = heightFt, h > 0 else { return nil }
    return w / h
  }

  /// Statuses of the four key fields: width, height, projection (tech tier) and sound.
  public var keyFieldStatuses: [Provenance] {
    [fields.widthFt.status, fields.heightFt.status, fields.projection.status, fields.sound.status]
  }

  /// `true` if any key field isn't sourced (spec 9.6).
  public var isLowConfidence: Bool { keyFieldStatuses.contains { $0 != .sourced } }

  /// `high` if all key fields are sourced, `medium` if one isn't, `low` otherwise.
  public var confidence: Confidence {
    switch keyFieldStatuses.filter({ $0 != .sourced }).count {
    case 0: .high
    case 1: .medium
    default: .low
    }
  }

  public enum Confidence: String, Sendable { case high, medium, low }
}

/// Screen shape words used in the app (spec 3).
public enum ScreenShape: String, Sendable {
  case scope, flat, tall

  public init(ratio: Double) {
    if ratio > 2.2 {
      self = .scope
    } else if ratio < 1.7 {
      self = .tall
    } else {
      self = .flat
    }
  }

  public var label: String {
    switch self {
    case .scope: "Scope"
    case .flat: "Flat"
    case .tall: "Tall"
    }
  }
}
