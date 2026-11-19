import Models
import Scoring
import SwiftUI

/// Movie (spec 5.3): see the best theatres for this movie and why, within 10 seconds.
struct MovieView: View {
  let film: Film
  @Environment(AppModel.self) private var model
  @State private var scrolledPast = false
  @State private var pull: CGFloat = 0
  @State private var showRankingBanner = false
  @State private var showTip = false

  private let heroHeight: CGFloat = 520

  var body: some View {
    let ranking = model.ranking(for: film)
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        hero
        if showRankingBanner { rankingBanner.padding(.top, 16) }
        pills.padding(.top, 16)
        SectionTitle(
          title: String(localized: "Best theatres for this movie"),
          subtitle: String(localized: "Ranked by picture quality, sound and screen size for \(film.title).")
        )
        .padding(.horizontal, Spacing.margin)
        .padding(.top, 22)
        if showTip { tip.padding(.top, 14) }
        LazyVStack(spacing: 28) {
          ForEach(ranking) { ranked in
            TheatreCard(film: film, ranked: ranked, total: ranking.count)
          }
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, 18)
        if let soon = model.openingSoon(for: film) {
          OpeningSoonCard(screen: soon, venue: model.venue(for: soon))
            .padding(.horizontal, Spacing.margin)
            .padding(.top, 28)
        }
        footnote
      }
    }
    .scrollIndicators(.hidden)
    .debugInitialScroll()
    .ignoresSafeArea(edges: .top)
    .background(Color.sw.background)
    .onScrollGeometryChange(for: CGFloat.self) {
      $0.contentOffset.y + $0.contentInsets.top
    } action: { _, y in
      pull = min(0, y)
      let past = y > heroHeight - 120
      if past != scrolledPast { withAnimation(Motion.select) { scrolledPast = past } }
    }
    .scrollEdgeEffectHidden(!scrolledPast, for: .top)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text(film.title)
          .font(.headline)
          .lineLimit(1)
          .opacity(scrolledPast ? 1 : 0)
          .accessibilityHidden(!scrolledPast)
      }
      ToolbarItem(placement: .topBarTrailing) {
        ShareLink(item: DeepLink.film(film.id), subject: Text(film.title), message: Text(shareMessage(ranking))) {
          Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Share")
      }
    }
    .onAppear {
      showRankingBanner = model.noteFormatsSeen(film)
      showTip = !model.user.hasSeenScoreTip
    }
  }

  private func shareMessage(_ ranking: [RankedScreen]) -> String {
    guard let top = ranking.first, let venue = model.venue(for: top.screen) else { return film.title }
    return String(
      localized: "Best theatre in Hyderabad for \(film.title): \(venue.name) \(top.screen.hall), \(top.shown)/100.")
  }

  // MARK: Hero

  private var hero: some View {
    let source = ArtworkSource(film: film)
    return ZStack(alignment: .bottomLeading) {
      FilmArtwork(film: film, posterWidth: 780)
        .frame(height: heroHeight - pull)
        .offset(y: pull)
        .overlay(alignment: .bottom) {
          LinearGradient(
            stops: [
              .init(color: .black.opacity(0.25), location: 0),
              .init(color: .clear, location: 0.25),
              .init(color: .clear, location: 0.45),
              .init(color: .black.opacity(0.8), location: 1),
            ], startPoint: .top, endPoint: .bottom
          )
          .frame(height: heroHeight - pull)
          .offset(y: pull)
        }
      VStack(alignment: .leading, spacing: 8) {
        StatusChip(film: film, today: model.today)
        if source.showsOwnTitle {
          Text(film.title)
            .font(.largeTitle.bold())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
        }
        if let original = film.originalTitle, original != film.title {
          Text(original).font(.subheadline)
        }
        Text(Copy.meta(film))
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.84))
      }
      .foregroundStyle(.white)
      .padding(.horizontal, Spacing.margin)
      .padding(.bottom, 24)
    }
    .frame(height: heroHeight)
    .clipped()
  }

  // MARK: Pills, tip and banner

  private var pills: some View {
    PillRow {
      ForEach(Copy.formatPills(film.formats)) { pill in
        Pill(
          text: pill.text, style: pill.isEstimate ? .outlined : .confirmed, term: pill.term,
          onExplain: { term in
            model.explain(term, extra: pill.isEstimate ? ExplainerExtra(isEstimate: true) : nil)
          })
      }
    }
    .padding(.horizontal, Spacing.margin)
  }

  private var tip: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "lightbulb")
        .foregroundStyle(Color.sw.labelSecondary)
      Text("The score is for this movie. The same theatre can rank differently for another one.")
        .font(.subheadline)
        .foregroundStyle(Color.sw.label)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      Button {
        withAnimation(Motion.select) { showTip = false }
        model.user.hasSeenScoreTip = true
      } label: {
        Image(systemName: "xmark")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Color.sw.labelSecondary)
          .frame(width: Spacing.minHit, height: Spacing.minHit)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.top, -12)
      .padding(.trailing, -12)
      .accessibilityLabel("Dismiss tip")
    }
    .padding(14)
    .background(Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: Radius.grouped, style: .continuous))
    .padding(.horizontal, Spacing.margin)
  }

  private var rankingBanner: some View {
    Label(rankingBannerText, systemImage: "arrow.triangle.2.circlepath")
      .font(.subheadline)
      .foregroundStyle(Color.sw.label)
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: Radius.grouped, style: .continuous))
      .padding(.horizontal, Spacing.margin)
  }

  private var rankingBannerText: String {
    let f = film.formats
    if f.imax == .confirmed { return String(localized: "Ranking updated: the studio confirmed the IMAX version.") }
    if f.dolbyVision == .confirmed {
      return String(localized: "Ranking updated: the studio confirmed the Dolby Vision version.")
    }
    return String(localized: "Ranking updated: this movie's formats changed.")
  }

  private var footnote: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Scores use public reports of screen size and equipment. Some specs aren't confirmed yet and are marked.")
      Button("How we rank") { model.explain(.score) }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.sw.accent)
        .frame(minHeight: Spacing.minHit)
    }
    .font(.footnote)
    .foregroundStyle(Color.sw.labelSecondary)
    .padding(.horizontal, Spacing.margin)
    .padding(.top, 24)
    .padding(.bottom, 32)
  }
}

/// Dashed card for a known upcoming screen that could change the ranking.
struct OpeningSoonCard: View {
  let screen: Screen
  let venue: Venue?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Opening soon")
        .font(.caption.weight(.bold))
        .textCase(.uppercase)
        .foregroundStyle(Color.sw.accent)
      Text("\(venue?.name ?? screen.name) · \(screen.formatLabel)")
        .font(.headline)
        .foregroundStyle(Color.sw.label)
      Text([venue?.area, screen.openingNote].compactMap { $0 }.joined(separator: ". "))
        .font(.subheadline)
        .foregroundStyle(Color.sw.labelSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(
      RoundedRectangle(cornerRadius: Radius.theatreImage, style: .continuous)
        .strokeBorder(Color.sw.fill2, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
    )
    .accessibilityElement(children: .combine)
  }
}

/// Deep links (spec 4.3). The web domain is an open question, so shares use the app scheme.
enum DeepLink {
  static func film(_ id: String) -> URL { URL(string: "screenwise://film/\(id)")! }
  static func theatre(_ screenID: String, film: String?) -> URL {
    if let film { return URL(string: "screenwise://film/\(film)/screen/\(screenID)")! }
    return URL(string: "screenwise://screen/\(screenID)")!
  }
}
