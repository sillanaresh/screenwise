import Models
import Scoring
import SwiftUI

/// Home (spec 5.2): say what the app does, then pick a movie in one tap.
struct HomeView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
  @Namespace private var zoom
  @State private var page: String?
  @State private var lastTouch = Date.distantPast
  @State private var width: CGFloat = 402

  var body: some View {
    let films = model.carouselFilms
    let current = films.first { $0.id == page } ?? films.first

    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header
        headline.padding(.top, 18)
        if films.isEmpty {
          emptyCard.padding(.top, 22)
        } else {
          carousel(films).padding(.top, 22)
        }
        searchBar.padding(.top, 22)
        Text("Screenwise doesn't stream movies. It tells you where in Hyderabad to watch them best.")
          .font(.footnote)
          .foregroundStyle(Color.sw.labelSecondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
          .padding(.horizontal, Spacing.margin)
          .padding(.top, 16)
          .padding(.bottom, 40)
      }
    }
    .scrollIndicators(.hidden)
    .background(alignment: .top) {
      AmbientTint(tint: Color(hex: current?.tintHex) ?? Color(hex: "#9FB7FF")!)
        .ignoresSafeArea()
    }
    .background(Color.sw.background)
    .toolbar(.hidden, for: .navigationBar)
    .onGeometryChange(for: CGFloat.self) {
      $0.size.width
    } action: {
      width = $0
    }
    .onAppear { model.zoomNamespace = zoom }
    .task(id: autoAdvanceKey(films)) { await autoAdvance(films) }
  }

  // MARK: Header and headline

  private var header: some View {
    HStack {
      Button {
        model.sheet = .city
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "mappin").font(.subheadline)
          Text("Hyderabad").font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Color.sw.label)
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(minHeight: 36)
        .swGlass(in: Capsule(), interactive: true)
        .frame(minHeight: Spacing.minHit)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("City: Hyderabad")

      Spacer()

      Button {
        model.open(.you)
      } label: {
        Group {
          if let initial = model.user.details.name.trimmingCharacters(in: .whitespaces).first {
            Text(String(initial).uppercased()).font(.subheadline.weight(.semibold))
          } else {
            Image(systemName: "person").font(.subheadline.weight(.medium))
          }
        }
        .foregroundStyle(Color.sw.labelSecondary)
        .frame(width: 36, height: 36)
        .swGlass(in: Circle(), interactive: true)
        .frame(width: Spacing.minHit, height: Spacing.minHit)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("You: saved theatres and settings")
    }
    .padding(.horizontal, Spacing.margin - 4)
    .frame(minHeight: 44)
  }

  private var headline: some View {
    VStack(alignment: .leading, spacing: 10) {
      (Text("Pick a movie.\n").foregroundStyle(Color.sw.label)
        + Text("We'll pick the theatre.").foregroundStyle(Color.sw.labelSecondary))
        .font(.largeTitle.bold())
        .accessibilityAddTraits(.isHeader)
      Text("Hyderabad's top cinemas, ranked for your movie by picture, sound and size.")
        .font(.callout)
        .foregroundStyle(Color.sw.labelSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, Spacing.margin)
  }

  // MARK: Carousel

  private func carousel(_ films: [Film]) -> some View {
    let index = films.firstIndex { $0.id == page } ?? 0
    return ScrollView(.horizontal) {
      LazyHStack(spacing: 0) {
        ForEach(Array(films.enumerated()), id: \.element.id) { i, film in
          CarouselCard(
            film: film, best: model.ranking(for: film).first, minHeight: (width - 40) * 1.25,
            position: i + 1, count: films.count
          )
          .matchedTransitionSource(id: film.id, in: zoom)
          .padding(.horizontal, Spacing.margin)
          .containerRelativeFrame(.horizontal)
          .id(film.id)
        }
      }
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.paging)
    .scrollIndicators(.hidden)
    .scrollClipDisabled()
    .scrollPosition(id: $page)
    .onScrollPhaseChange { _, phase in
      if phase != .idle { lastTouch = .now }
    }
    .overlay(alignment: .bottom) {
      PageDots(count: min(films.count, 8), index: index)
        .padding(.bottom, 16)
        .allowsHitTesting(false)
    }
    .onAppear { if page == nil { page = films.first?.id } }
  }

  private var emptyCard: some View {
    GroupedBox(radius: Radius.carouselCard, padding: 24) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Movies will show here once you're online.")
          .font(.headline)
          .foregroundStyle(Color.sw.label)
        Button("Retry") { Task { await model.refresh() } }
          .buttonStyle(AccentButtonStyle())
      }
    }
    .padding(.horizontal, Spacing.margin)
  }

  // MARK: Search bar

  private var searchBar: some View {
    Button {
      model.showSearch = true
    } label: {
      HStack(spacing: 14) {
        Image(systemName: "magnifyingglass")
          .font(.title3)
          .foregroundStyle(Color.sw.label)
        VStack(alignment: .leading, spacing: 1) {
          Text("Search any movie")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.sw.label)
          Text("Telugu, Hindi, English, Tamil and more")
            .font(.footnote)
            .foregroundStyle(Color.sw.labelSecondary)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 20)
      .frame(minHeight: 62)
      .background(Color.sw.card, in: Capsule())
      .overlay(Capsule().strokeBorder(Color.sw.separator, lineWidth: 0.5))
      .swShadowSmall()
      .contentShape(Capsule())
    }
    .buttonStyle(PressableStyle(scale: 0.98))
    .padding(.horizontal, Spacing.margin)
    .accessibilityLabel("Search any movie")
    .accessibilityHint("Telugu, Hindi, English, Tamil and more")
  }

  // MARK: Auto-advance (spec 5.2)

  private func autoAdvanceKey(_ films: [Film]) -> String {
    let visible = model.path.isEmpty && !model.showSearch && model.sheet == nil
    return "\(films.count)-\(visible)-\(reduceMotion)-\(voiceOver)"
  }

  private func autoAdvance(_ films: [Film]) async {
    guard films.count > 1, !reduceMotion, !voiceOver,
      model.path.isEmpty, !model.showSearch, model.sheet == nil
    else { return }
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(6))
      guard !Task.isCancelled else { return }
      if Date.now.timeIntervalSince(lastTouch) < 9 { continue }
      let i = films.firstIndex { $0.id == page } ?? 0
      withAnimation(.smooth(duration: 0.6)) { page = films[(i + 1) % films.count].id }
    }
  }
}

/// One hero card: artwork, status chip, title, meta and the best theatre strip.
struct CarouselCard: View {
  let film: Film
  let best: RankedScreen?
  let minHeight: CGFloat
  let position: Int
  let count: Int
  @Environment(AppModel.self) private var model

  var body: some View {
    let source = ArtworkSource(film: film)
    Button {
      model.zoomSourceID = film.id
      model.openMovie(film)
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        StatusChip(film: film, today: model.today)
        Spacer(minLength: 120)
        VStack(alignment: .leading, spacing: 6) {
          if source.showsOwnTitle {
            Text(film.title)
              .font(.largeTitle.bold())
              .lineLimit(2)
              .minimumScaleFactor(0.85)
          }
          Text(Copy.meta(film))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.82))
          if let best {
            bestStrip(best).padding(.top, 10)
          }
        }
        .padding(.bottom, 48 - 20)
      }
      .foregroundStyle(.white)
      .padding(20)
      .padding(.top, -4)
      .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
      .background {
        FilmArtwork(film: film)
          .overlay(scrim)
      }
      .clipShape(RoundedRectangle(cornerRadius: Radius.carouselCard, style: .continuous))
      .swShadowCard()
      .contentShape(RoundedRectangle(cornerRadius: Radius.carouselCard, style: .continuous))
    }
    .buttonStyle(PressableStyle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
    .accessibilityHint("Shows the best theatres for this movie")
    .accessibilityAddTraits(.isButton)
  }

  private var accessibilityText: String {
    var parts = [film.title, Copy.status(film, today: model.today)]
    if let best, let venue = model.venue(for: best.screen) {
      parts.append(String(localized: "Best theatre: \(venue.name), \(Copy.formatText(best.screen))"))
    }
    parts.append(String(localized: "\(position) of \(count)"))
    return parts.joined(separator: ". ")
  }

  private var scrim: some View {
    LinearGradient(
      stops: [
        .init(color: .black.opacity(0.22), location: 0),
        .init(color: .clear, location: 0.22),
        .init(color: .clear, location: 0.42),
        .init(color: .black.opacity(0.72), location: 0.78),
        .init(color: .black.opacity(0.86), location: 1),
      ], startPoint: .top, endPoint: .bottom)
  }

  private func bestStrip(_ best: RankedScreen) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 1) {
        Text("Best theatre for this movie")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.72))
        Text("\(model.venue(for: best.screen)?.name ?? "") · \(Copy.formatText(best.screen))")
          .font(.headline)
          .lineLimit(2)
      }
      Spacer(minLength: 0)
      HStack(spacing: 4) {
        Text("See all")
        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
      }
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(Color(white: 0.07))
      .padding(.horizontal, 14)
      .frame(minHeight: 36)
      .background(.white, in: Capsule())
    }
    .padding(.leading, 14)
    .padding(.trailing, 10)
    .padding(.vertical, 10)
    .swGlassOnImage(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

/// Page dots: up to 8. The active dot stretches to 18 × 6.
struct PageDots: View {
  let count: Int
  let index: Int

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0..<count, id: \.self) { i in
        Capsule()
          .fill(.white.opacity(i == index ? 1 : 0.45))
          .frame(width: i == index ? 18 : 6, height: 6)
      }
    }
    .animation(.spring(duration: 0.35, bounce: 0), value: index)
    .accessibilityHidden(true)
  }
}

/// A soft wash of the current movie's colour behind the header and headline (spec 7.3).
struct AmbientTint: View {
  let tint: Color
  @Environment(\.colorScheme) private var scheme
  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    let bg = Color.sw.background
    let strength: (Double, Double) = scheme == .dark ? (0.34, 0.12) : (0.24, 0.09)
    let factor = contrast == .increased ? 0.5 : 1
    let height: CGFloat = 620
    GeometryReader { proxy in
      RadialGradient(
        stops: [
          .init(color: bg.mix(with: tint, by: strength.0 * factor, in: .perceptual), location: 0),
          .init(color: bg.mix(with: tint, by: strength.1 * factor, in: .perceptual), location: 0.52),
          .init(color: bg, location: 1),
        ],
        center: .top, startRadius: 0, endRadius: height * 0.8
      )
      .scaleEffect(x: (proxy.size.width * 1.5) / (height * 0.8), y: 1, anchor: .top)
      .frame(width: proxy.size.width, height: height)
    }
    .frame(height: 620)
    .animation(.easeInOut(duration: 1), value: tint)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
