import Models
import SwiftUI

/// Search (spec 5.6), as a full-screen cover. Searches the downloaded movie list on the
/// phone as you type, so it is instant and works offline.
struct SearchView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  @FocusState private var focused: Bool

  var body: some View {
    let results = MovieSearch.search(query, in: model.catalogue.films)
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass").foregroundStyle(Color.sw.labelSecondary)
          TextField("Movies in any language", text: $query)
            .font(.body)
            .focused($focused)
            .submitLabel(.search)
            .autocorrectionDisabled()
          if !query.isEmpty {
            Button {
              query = ""
            } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(Color.sw.labelTertiary)
            }
            .accessibilityLabel("Clear")
          }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 40)
        .background(Color.sw.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        Button("Cancel") { dismiss() }
          .font(.body)
          .foregroundStyle(Color.sw.accent)
          .frame(minHeight: Spacing.minHit)
      }
      .padding(.horizontal, Spacing.barMargin)
      .padding(.top, 12)
      .padding(.bottom, 10)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          let list = query.isEmpty ? model.popularFilms : results
          if !list.isEmpty {
            Text(query.isEmpty ? "Popular now" : "Movies")
              .font(.footnote.weight(.medium))
              .textCase(.uppercase)
              .foregroundStyle(Color.sw.labelSecondary)
              .padding(.horizontal, Spacing.margin)
              .padding(.top, 12)
              .padding(.bottom, 4)
          }
          ForEach(list) { film in
            Button {
              open(film)
            } label: {
              resultRow(film)
            }
            .buttonStyle(.plain)
          }
          if !query.trimmingCharacters(in: .whitespaces).isEmpty && results.isEmpty {
            notFound.padding(.top, 24)
          }
        }
        .padding(.bottom, 40)
      }
      .scrollDismissesKeyboard(.immediately)
    }
    .background(Color.sw.background)
    .onAppear { focused = true }
  }

  private func resultRow(_ film: Film) -> some View {
    HStack(spacing: 14) {
      FilmArtwork(film: film, posterWidth: 185)
        .frame(width: 52, height: 65)
        .clipShape(RoundedRectangle(cornerRadius: Radius.thumbnail, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        Text(film.title).font(.headline).foregroundStyle(Color.sw.label)
        Text(
          "\(Copy.languageName(film.originalLanguage ?? film.languages.first ?? "")) · \(Copy.status(film, today: model.today))"
        )
        .font(.subheadline)
        .foregroundStyle(Color.sw.labelSecondary)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, Spacing.margin)
    .padding(.vertical, 10)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  /// No match. v1 has no live research, so we say it isn't here yet and offer to tell us.
  private var notFound: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Not on Screenwise yet: “\(query.trimmingCharacters(in: .whitespaces))”")
        .font(.title2.bold())
        .foregroundStyle(Color.sw.label)
      Text(
        "We add movies with an India cinema release every day. If this one is coming to theatres here, it should show up soon."
      )
      .font(.subheadline)
      .foregroundStyle(Color.sw.labelSecondary)
      .fixedSize(horizontal: false, vertical: true)
      Button("Tell us about this movie") {
        let q = query.trimmingCharacters(in: .whitespaces)
        dismiss()
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(350))
          model.sheet = .feedback(FeedbackDraft(kind: .missingMovie, subject: q, field: nil))
        }
      }
      .buttonStyle(AccentButtonStyle())
      .padding(.top, 4)
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .padding(.horizontal, Spacing.margin)
  }

  private func open(_ film: Film) {
    dismiss()
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(300))
      model.openMovie(film)
    }
  }
}

/// Prefix and fuzzy matching over titles, original titles and Latin spellings (spec 11.3).
enum MovieSearch {
  static func normalize(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .init(identifier: "en"))
      .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
      .map(String.init).joined()
  }

  static func search(_ query: String, in films: [Film]) -> [Film] {
    let q = normalize(query)
    guard !q.isEmpty else { return [] }
    let scored = films.compactMap { film -> (Film, Int)? in
      let names = [film.title, film.originalTitle].compactMap { $0 } + film.aliases
      var best: Int?
      for name in names {
        let n = normalize(name)
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { normalize(String($0)) }
        let score: Int? =
          if n.hasPrefix(q) { 0 } else if words.contains(where: { $0.hasPrefix(q) }) { 1 } else if n.contains(q) {
            2
          } else if q.count >= 4,
            words.contains(where: { distance($0.prefix(q.count + 1).description, q) <= (q.count >= 7 ? 2 : 1) })
          { 3 } else { nil }
        if let score { best = min(best ?? score, score) }
      }
      return best.map { (film, $0) }
    }
    return scored.sorted { a, b in
      a.1 != b.1 ? a.1 < b.1 : (a.0.anticipation ?? a.0.popularity ?? 0) > (b.0.anticipation ?? b.0.popularity ?? 0)
    }.map(\.0)
  }

  /// Edit distance, for small typos such as "ramayan" or "pushpa2".
  static func distance(_ a: String, _ b: String) -> Int {
    let a = Array(a)
    let b = Array(b)
    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }
    var prev = Array(0...b.count)
    for i in 1...a.count {
      var cur = [i] + Array(repeating: 0, count: b.count)
      for j in 1...b.count {
        cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
      }
      prev = cur
    }
    return prev[b.count]
  }
}
