import Foundation
import Models
import OSLog

/// App settings that are not secret. The app holds no API keys.
enum AppConfig {
  /// Where the daily data files (`catalogue.json`, `screens.json`) are published: the `data`
  /// folder of the public repo's main branch. If it can't be reached, the app uses the copies
  /// bundled at build time.
  static let dataBaseURL: URL? = URL(string: "https://raw.githubusercontent.com/sillanaresh/screenwise/main/data/")
  /// Corrections and feedback go to this address by email, always with the same subject line,
  /// so the owner can filter them.
  static let feedbackEmail = "silla.naresh@gmail.com"
  static let feedbackSubject = "Feedback: Screenwise"
  static let tmdbImageBase = URL(string: "https://image.tmdb.org/t/p/")!
  static let bookMyShowHome = URL(string: "https://in.bookmyshow.com/explore/home/hyderabad")!
  static let districtHome = URL(string: "https://www.district.in/movies/")!
}

/// Loads the movie list and the theatre data.
///
/// Order: the copy downloaded last time (if any), else the bundled copy. Then, when a data URL
/// is set, it downloads fresh files in the background and keeps them for next time.
struct DataStore: Sendable {
  private static let log = Logger(subsystem: "app.screenwise.ios", category: "data")

  struct Loaded: Sendable {
    var catalogue: Catalogue
    var theatres: TheatreData
    var updatedAt: Date?
  }

  private var cacheDir: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appending(path: "data", directoryHint: .isDirectory)
  }

  /// Fast, synchronous load for launch. Never fails: the bundle always has a copy.
  /// Uses whichever copy is newer, so an app update with fresher bundled data wins over an
  /// older download.
  func loadLocal() -> Loaded {
    let bundledCatalogue: Catalogue = bundled("catalogue")
    let bundledTheatres: TheatreData = bundled("screens")
    var catalogue = bundledCatalogue
    if let c: Catalogue = cached("catalogue.json"), c.generatedAt > bundledCatalogue.generatedAt { catalogue = c }
    var theatres = bundledTheatres
    if let t: TheatreData = cached("screens.json"), t.updatedOn > bundledTheatres.updatedOn { theatres = t }
    let attrs = try? FileManager.default.attributesOfItem(atPath: cacheDir.appending(path: "catalogue.json").path)
    return Loaded(catalogue: catalogue, theatres: theatres, updatedAt: attrs?[.modificationDate] as? Date)
  }

  /// Downloads fresh files. Returns nil when there is no data URL or the network fails.
  func refresh() async -> Loaded? {
    guard let base = AppConfig.dataBaseURL else { return nil }
    do {
      async let c: Catalogue = download(base.appending(path: "catalogue.json"), saveAs: "catalogue.json")
      async let t: TheatreData = download(base.appending(path: "screens.json"), saveAs: "screens.json")
      return Loaded(catalogue: try await c, theatres: try await t, updatedAt: .now)
    } catch {
      Self.log.error("refresh failed: \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }

  private func download<T: Decodable>(_ url: URL, saveAs name: String) async throws -> T {
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadRevalidatingCacheData
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    let value = try JSONDecoder().decode(T.self, from: data)
    try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    try data.write(to: cacheDir.appending(path: name), options: .atomic)
    return value
  }

  private func cached<T: Decodable>(_ name: String) -> T? {
    guard let data = try? Data(contentsOf: cacheDir.appending(path: name)) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }

  private func bundled<T: Decodable>(_ name: String) -> T {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { fatalError("Missing bundled \(name).json") }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      fatalError("Bundled \(name).json does not decode: \(error)")
    }
  }
}
