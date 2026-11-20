import Models
import Scoring
import SwiftUI
import UIKit

/// Movie (spec 5.3): see the best theatres for this movie and why, within 10 seconds.
struct MovieView: View {
  let film: Film
  @Environment(AppModel.self) private var model
  @State private var scrolledPast = false
  @State private var pull: CGFloat = 0
  @State private var showRankingBanner = false
  @State private var showTip = false
  @State private var sort: Sort = .best

  enum Sort: Hashable { case best, nearMe }

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
        sortPicker.padding(.top, 16)
        if showTip { tip.padding(.top, 14) }
        if sort == .nearMe {
          nearMeList(ranking)
        } else {
          cards(ranking, total: ranking.count)
        }
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
      #if DEBUG
        // Debug only, for screenshots: -debugSort near
        if UserDefaults.standard.string(forKey: "debugSort") == "near" {
          sort = .nearMe
          model.nearMe.locate()
        }
      #endif
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

  // MARK: Sort and Near me

  private var sortPicker: some View {
    VStack(alignment: .leading, spacing: 10) {
      Picker("Sort", selection: $sort) {
        Text("Best overall").tag(Sort.best)
        Text("Near me").tag(Sort.nearMe)
      }
      .pickerStyle(.segmented)
      .onChange(of: sort) { _, new in
        if new == .nearMe { model.nearMe.locate() }
      }
      Label("We don't check showtimes yet. Book tickets shows where it's playing.", systemImage: "clock")
        .font(.footnote)
        .foregroundStyle(Color.sw.labelSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, Spacing.margin)
  }

  private func cards(_ list: [RankedScreen], total: Int) -> some View {
    LazyVStack(spacing: 28) {
      ForEach(list) { ranked in
        TheatreCard(film: film, ranked: ranked, total: total)
      }
    }
    .padding(.horizontal, Spacing.margin)
    .padding(.top, 18)
  }

  @ViewBuilder
  private func nearMeList(_ ranking: [RankedScreen]) -> some View {
    switch model.nearMe.state {
    case .located:
      let near = model.nearMe.nearby(ranking) { model.venue(for: $0) }
      Text("Best within \(near.radiusKm) km of you. Ranks are for all of Hyderabad. Distances are straight line.")
        .font(.subheadline)
        .foregroundStyle(Color.sw.labelSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.margin)
        .padding(.top, 14)
      if near.list.isEmpty {
        nearMeMessage(String(localized: "No theatres we cover are within 25 km of you."), settings: false)
      } else {
        cards(near.list, total: ranking.count)
      }
    case .denied:
      nearMeMessage(
        String(localized: "Location is off for Screenwise. Turn it on to sort theatres by distance."), settings: true)
    case .unavailable:
      nearMeMessage(String(localized: "We couldn't find your location. Try again in a moment."), settings: false)
    case .idle, .locating:
      HStack(spacing: 10) {
        ProgressView()
        Text("Finding your location").foregroundStyle(Color.sw.labelSecondary)
      }
      .font(.subheadline)
      .frame(maxWidth: .infinity, minHeight: 120)
    }
  }

  private func nearMeMessage(_ text: String, settings: Bool) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(text)
        .font(.subheadline)
        .foregroundStyle(Color.sw.label)
        .fixedSize(horizontal: false, vertical: true)
      if settings, let url = URL(string: UIApplication.openSettingsURLString) {
        Link("Open Settings", destination: url)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.sw.accent)
          .frame(minHeight: Spacing.minHit)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: Radius.grouped, style: .continuous))
    .padding(.horizontal, Spacing.margin)
    .padding(.top, 14)
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
      Text("\(venue?.name ?? screen.name) · \(Copy.formatText(screen))")
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
