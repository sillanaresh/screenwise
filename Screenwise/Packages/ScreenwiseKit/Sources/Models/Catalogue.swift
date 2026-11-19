import Foundation

/// Root of `data/catalogue.json`: the movies the app knows about.
public struct Catalogue: Codable, Sendable, Hashable {
  public var schemaVersion: Int
  public var generatedAt: String
  /// "tmdb" for the daily sync, "sample" for the bundled stand-in list.
  public var source: String
  public var films: [Film]

  public init(schemaVersion: Int, generatedAt: String, source: String, films: [Film]) {
    self.schemaVersion = schemaVersion
    self.generatedAt = generatedAt
    self.source = source
    self.films = films
  }

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case generatedAt = "generated_at"
    case source, films
  }

  public var isSample: Bool { source == "sample" }
}

/// Status of a premium version of a movie (spec 3).
public enum VersionStatus: String, Codable, Sendable {
  case confirmed, expected, none
}

/// Status of the frame ratio of a movie.
public enum FrameStatus: String, Codable, Sendable {
  case confirmed, estimated, unknown
}

public struct FilmFormats: Codable, Sendable, Hashable {
  public var frameRatio: Double?
  public var frameStatus: FrameStatus
  public var imax: VersionStatus
  public var imaxRatio: Double?
  public var imaxExpandedShare: Double?
  public var dolbyVision: VersionStatus
  public var hdrBarco: VersionStatus
  public var threeD: VersionStatus
  /// Short plain note on how the formats were decided, shown in the movie's sources.
  public var note: String?

  public init(
    frameRatio: Double? = 2.39, frameStatus: FrameStatus = .estimated, imax: VersionStatus = .none,
    imaxRatio: Double? = nil, imaxExpandedShare: Double? = nil, dolbyVision: VersionStatus = .none,
    hdrBarco: VersionStatus = .none, threeD: VersionStatus = .none, note: String? = nil
  ) {
    self.frameRatio = frameRatio
    self.frameStatus = frameStatus
    self.imax = imax
    self.imaxRatio = imaxRatio
    self.imaxExpandedShare = imaxExpandedShare
    self.dolbyVision = dolbyVision
    self.hdrBarco = hdrBarco
    self.threeD = threeD
    self.note = note
  }

  enum CodingKeys: String, CodingKey {
    case frameRatio = "frame_ratio"
    case frameStatus = "frame_status"
    case imax
    case imaxRatio = "imax_ratio"
    case imaxExpandedShare = "imax_expanded_share"
    case dolbyVision = "dolby_vision"
    case hdrBarco = "hdr_barco"
    case threeD = "three_d"
    case note
  }

  /// The ratio used for scoring. Unknown frames use scope 2.39, the spec's default estimate.
  public var scoringRatio: Double { frameRatio ?? 2.39 }
}

public struct Film: Codable, Sendable, Hashable, Identifiable {
  public var id: String
  public var tmdbID: Int?
  public var title: String
  public var originalTitle: String?
  public var originalLanguage: String?
  /// ISO 639-1 codes of the Indian release, e.g. ["te", "hi"].
  public var languages: [String]
  public var genres: [String]
  public var director: String?
  public var runtimeMin: Int?
  public var certificationIN: String?
  /// India theatrical release date, yyyy-MM-dd.
  public var releaseDateIN: String?
  public var releaseDateStatus: String?
  public var posterPath: String?
  public var textlessPosterPath: String?
  public var backdropPath: String?
  public var tintHex: String?
  public var popularity: Double?
  public var anticipation: Double?
  /// Latin spellings of an Indic title, for search.
  public var aliases: [String]
  public var formats: FilmFormats

  public init(
    id: String, tmdbID: Int? = nil, title: String, originalTitle: String? = nil,
    originalLanguage: String? = nil, languages: [String] = [], genres: [String] = [],
    director: String? = nil, runtimeMin: Int? = nil, certificationIN: String? = nil,
    releaseDateIN: String? = nil, releaseDateStatus: String? = nil, posterPath: String? = nil,
    textlessPosterPath: String? = nil, backdropPath: String? = nil, tintHex: String? = nil,
    popularity: Double? = nil, anticipation: Double? = nil, aliases: [String] = [],
    formats: FilmFormats = FilmFormats()
  ) {
    self.id = id
    self.tmdbID = tmdbID
    self.title = title
    self.originalTitle = originalTitle
    self.originalLanguage = originalLanguage
    self.languages = languages
    self.genres = genres
    self.director = director
    self.runtimeMin = runtimeMin
    self.certificationIN = certificationIN
    self.releaseDateIN = releaseDateIN
    self.releaseDateStatus = releaseDateStatus
    self.posterPath = posterPath
    self.textlessPosterPath = textlessPosterPath
    self.backdropPath = backdropPath
    self.tintHex = tintHex
    self.popularity = popularity
    self.anticipation = anticipation
    self.aliases = aliases
    self.formats = formats
  }

  enum CodingKeys: String, CodingKey {
    case id, title, languages, genres, director, popularity, anticipation, aliases, formats
    case tmdbID = "tmdb_id"
    case originalTitle = "original_title"
    case originalLanguage = "original_language"
    case runtimeMin = "runtime_min"
    case certificationIN = "certification_in"
    case releaseDateIN = "release_date_in"
    case releaseDateStatus = "release_date_status"
    case posterPath = "poster_path"
    case textlessPosterPath = "textless_poster_path"
    case backdropPath = "backdrop_path"
    case tintHex = "tint_hex"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    tmdbID = try c.decodeIfPresent(Int.self, forKey: .tmdbID)
    title = try c.decode(String.self, forKey: .title)
    originalTitle = try c.decodeIfPresent(String.self, forKey: .originalTitle)
    originalLanguage = try c.decodeIfPresent(String.self, forKey: .originalLanguage)
    languages = try c.decodeIfPresent([String].self, forKey: .languages) ?? []
    genres = try c.decodeIfPresent([String].self, forKey: .genres) ?? []
    director = try c.decodeIfPresent(String.self, forKey: .director)
    runtimeMin = try c.decodeIfPresent(Int.self, forKey: .runtimeMin)
    certificationIN = try c.decodeIfPresent(String.self, forKey: .certificationIN)
    releaseDateIN = try c.decodeIfPresent(String.self, forKey: .releaseDateIN)
    releaseDateStatus = try c.decodeIfPresent(String.self, forKey: .releaseDateStatus)
    posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
    textlessPosterPath = try c.decodeIfPresent(String.self, forKey: .textlessPosterPath)
    backdropPath = try c.decodeIfPresent(String.self, forKey: .backdropPath)
    tintHex = try c.decodeIfPresent(String.self, forKey: .tintHex)
    popularity = try c.decodeIfPresent(Double.self, forKey: .popularity)
    anticipation = try c.decodeIfPresent(Double.self, forKey: .anticipation)
    aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
    formats = try c.decodeIfPresent(FilmFormats.self, forKey: .formats) ?? FilmFormats()
  }
}

extension Film {
  /// The release date as a calendar day in India time.
  public func releaseDate(in calendar: Calendar = .india) -> Date? {
    guard let s = releaseDateIN else { return nil }
    return DayFormatter.date(from: s, calendar: calendar)
  }

  /// True once the India release date has arrived.
  public func isInCinemas(on today: Date, calendar: Calendar = .india) -> Bool {
    guard let release = releaseDate(in: calendar) else { return false }
    return calendar.startOfDay(for: release) <= calendar.startOfDay(for: today)
  }
}

extension Calendar {
  /// Gregorian calendar in Hyderabad's time zone.
  public static var india: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
    c.locale = Locale(identifier: "en_IN")
    return c
  }
}

/// Parses and formats yyyy-MM-dd days without time zone surprises.
public enum DayFormatter {
  public static func date(from string: String, calendar: Calendar = .india) -> Date? {
    let parts = string.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
  }
}
