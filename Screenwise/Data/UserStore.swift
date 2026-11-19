import Foundation

/// What the user keeps on this phone: saved theatres, history and optional details.
/// Never sent anywhere in v1 (spec 13.4 and 13.7).
struct UserData: Codable, Sendable, Equatable {
  struct Saved: Codable, Sendable, Equatable, Hashable {
    var screenID: String
    var savedAt: Date
  }

  struct HistoryItem: Codable, Sendable, Equatable, Hashable {
    enum Kind: String, Codable, Sendable { case film, theatre }
    var kind: Kind
    /// Film id for movies, screen id for theatres.
    var id: String
    /// For theatres: the movie it was viewed for.
    var filmID: String?
    var at: Date
  }

  struct Details: Codable, Sendable, Equatable {
    var name = ""
    var mobile = ""
    var email = ""
  }

  var saved: [Saved] = []
  var history: [HistoryItem] = []
  var details = Details()
  var hasSeenScoreTip = false
  /// Film formats seen last time, to show "Ranking updated" when they change.
  var seenFormats: [String: String] = [:]
}

/// Saves `UserData` as a small JSON file in Application Support.
struct UserStore: Sendable {
  private var url: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appending(path: "user.json")
  }

  func load() -> UserData {
    guard let data = try? Data(contentsOf: url),
      let value = try? JSONDecoder().decode(UserData.self, from: data)
    else { return UserData() }
    return value
  }

  func save(_ value: UserData) {
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtection])
    } catch {
      assertionFailure("Could not save user data: \(error)")
    }
  }
}
