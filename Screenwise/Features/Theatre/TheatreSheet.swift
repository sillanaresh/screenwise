import Models
import Scoring
import SwiftUI

/// The content that scrolls up over the stage on a Theatre page (spec 5.4).
struct TheatreSheet: View {
  let screen: Screen
  let film: Film?
  let ranked: RankedScreen?
  let total: Int
  @Environment(AppModel.self) private var model

  private var venue: Venue? { model.venue(for: screen) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Capsule()
        .fill(Color.sw.fill2)
        .frame(width: 36, height: 5)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(venue?.name ?? screen.name)
          .font(.title.bold())
          .foregroundStyle(Color.sw.label)
          .accessibilityAddTraits(.isHeader)
        Text(Copy.hallLine(screen, venue: venue))
          .font(.subheadline)
          .foregroundStyle(Color.sw.labelSecondary)
      }
      .padding(.horizontal, Spacing.margin)

      if let film, let ranked {
        ScoreBox(ranked: ranked, total: total, filmTitle: film.title) { model.explain(.score) }
          .padding(.horizontal, Spacing.margin)
          .padding(.top, 16)
      } else {
        bestFor.padding(.top, 16)
      }

      StatsRow(screen: screen, film: film, ranked: ranked, venue: venue)
        .padding(.horizontal, Spacing.margin)
        .padding(.top, 14)

      if let film, let ranked {
        SectionTitle(title: String(localized: "Why it suits this movie"))
          .padding(.horizontal, Spacing.margin)
          .padding(.top, 24)
        WhyList(ranked: ranked, formats: film.formats)
          .padding(.horizontal, Spacing.margin)
          .padding(.top, 10)
      }

      SectionTitle(title: String(localized: "The tech, in plain English"))
        .padding(.horizontal, Spacing.margin)
        .padding(.top, 24)
      VStack(spacing: 0) {
        ForEach(Array(Copy.techRows(screen).enumerated()), id: \.element.id) { i, row in
          if i > 0 { Divider().overlay(Color.sw.separator) }
          TechRowView(row: row) { model.explain(row.term, extra: shapeExtra(row.term)) }
        }
      }
      .padding(.horizontal, Spacing.margin)
      .padding(.top, 10)

      if let ranked {
        SectionTitle(
          title: String(localized: "How it scores"), subtitle: String(localized: "Out of 100, for this movie.")
        )
        .padding(.horizontal, Spacing.margin)
        .padding(.top, 24)
        ScoreBars(parts: ranked.parts)
          .padding(.horizontal, Spacing.margin)
          .padding(.top, 12)
      }

      Button {
        model.sheet = .sources(screenID: screen.id)
      } label: {
        HStack(spacing: 14) {
          IconTile(systemImage: "doc.text")
          VStack(alignment: .leading, spacing: 2) {
            Text("Specs and sources").font(.headline).foregroundStyle(Color.sw.label)
            Text(screen.isLowConfidence ? "Some specs not confirmed yet" : "All key specs sourced")
              .font(.subheadline)
              .foregroundStyle(Color.sw.labelSecondary)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right").foregroundStyle(Color.sw.labelTertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.horizontal, Spacing.margin)
      .padding(.top, 18)
      .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(minHeight: 700, alignment: .top)
    .background {
      UnevenRoundedRectangle(topLeadingRadius: Radius.sheetTop, topTrailingRadius: Radius.sheetTop, style: .continuous)
        .fill(Color.sw.background)
        .shadow(color: .black.opacity(0.08), radius: 15, y: -10)
        .overlay(alignment: .top) {
          UnevenRoundedRectangle(
            topLeadingRadius: Radius.sheetTop, topTrailingRadius: Radius.sheetTop, style: .continuous
          )
          .stroke(Color.sw.separator, lineWidth: 0.5)
          .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center))
        }
    }
    .zIndex(1)
  }

  private func shapeExtra(_ term: Term) -> ExplainerExtra? {
    guard term == .shape, let w = screen.widthFt, let h = screen.heightFt else { return nil }
    var extra = ExplainerExtra(venue: venue?.name, screenSize: "\(Copy.feet(w)) × \(Copy.feet(h))")
    if let pw = ranked?.parts.pictureW, let ph = ranked?.parts.pictureH {
      extra.pictureSize = "\(Int(pw.rounded())) × \(Int(ph.rounded()))"
    }
    return extra
  }

  /// "Best for": up to 3 movies where this screen ranks in the top 3.
  @ViewBuilder private var bestFor: some View {
    let list = model.bestFor(screenID: screen.id)
    GroupedBox(radius: Radius.scoreBox) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Best for").font(.headline).foregroundStyle(Color.sw.label)
        if list.isEmpty {
          Text("This theatre isn't in the top 3 for any current movie.")
            .font(.subheadline)
            .foregroundStyle(Color.sw.labelSecondary)
        }
        ForEach(list, id: \.film.id) { item in
          Button {
            model.openTheatre(screen, film: item.film)
          } label: {
            HStack(spacing: 12) {
              FilmArtwork(film: item.film, posterWidth: 185)
                .frame(width: 40, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
              VStack(alignment: .leading, spacing: 1) {
                Text(item.film.title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.sw.label)
                Text("#\(item.ranked.rank) · \(item.ranked.shown)/100")
                  .font(.footnote)
                  .monospacedDigit()
                  .foregroundStyle(Color.sw.labelSecondary)
              }
              Spacer(minLength: 0)
              Image(systemName: "chevron.right").foregroundStyle(Color.sw.labelTertiary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.horizontal, Spacing.margin)
  }
}

/// Score box (spec 5.4): the score, the band and the rank, with a "?" for How we rank.
struct ScoreBox: View {
  let ranked: RankedScreen
  let total: Int
  let filmTitle: String
  let onExplain: () -> Void

  var body: some View {
    Button(action: onExplain) {
      HStack(spacing: 14) {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text("\(ranked.shown)").font(.largeTitle.bold())
          Text(verbatim: " /100").font(.subheadline.weight(.semibold)).foregroundStyle(Color.sw.labelSecondary)
        }
        .monospacedDigit()
        .foregroundStyle(Color.sw.label)
        .fixedSize()
        VStack(alignment: .leading, spacing: 2) {
          Text(ranked.band.label).font(.headline).foregroundStyle(Color.sw.label)
          Text("#\(ranked.rank) of \(total) theatres for \(filmTitle)")
            .font(.subheadline)
            .foregroundStyle(Color.sw.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
        QuestionMark(size: 22)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: Radius.scoreBox, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Score \(ranked.shown) out of 100, \(ranked.band.label). Number \(ranked.rank) of \(total) theatres for \(filmTitle)."
    )
    .accessibilityHint("Explains how we rank")
  }
}

/// Three columns: screen width, screen shape and seats.
struct StatsRow: View {
  let screen: Screen
  let film: Film?
  let ranked: RankedScreen?
  let venue: Venue?
  @Environment(AppModel.self) private var model

  var body: some View {
    HStack(spacing: 0) {
      stat(value: screen.widthFt.map { "\(Copy.feet($0)) ft" } ?? "?", label: String(localized: "screen width"))
      Divider().overlay(Color.sw.separator)
      Button {
        var extra = ExplainerExtra(venue: venue?.name)
        if let w = screen.widthFt, let h = screen.heightFt { extra.screenSize = "\(Copy.feet(w)) × \(Copy.feet(h))" }
        if let pw = ranked?.parts.pictureW, let ph = ranked?.parts.pictureH {
          extra.pictureSize = "\(Int(pw.rounded())) × \(Int(ph.rounded()))"
        }
        model.explain(.shape, extra: extra)
      } label: {
        stat(
          value: screen.shapeRatio.map { ScreenShape(ratio: $0).label } ?? "?",
          label: String(localized: "screen shape"), question: true)
      }
      .buttonStyle(.plain)
      Divider().overlay(Color.sw.separator)
      stat(
        value: screen.seats.map { $0.formatted(.number.locale(Locale(identifier: "en_IN"))) } ?? "?",
        label: String(localized: "seats"))
    }
    .fixedSize(horizontal: false, vertical: true)
    .overlay(alignment: .top) { Rectangle().fill(Color.sw.separator).frame(height: 0.5) }
    .overlay(alignment: .bottom) { Rectangle().fill(Color.sw.separator).frame(height: 0.5) }
  }

  private func stat(value: String, label: String, question: Bool = false) -> some View {
    VStack(spacing: 3) {
      Text(value)
        .font(.title3.bold())
        .monospacedDigit()
        .foregroundStyle(Color.sw.label)
      HStack(spacing: 4) {
        Text(label)
        if question { QuestionMark(size: 14) }
      }
      .font(.footnote)
      .foregroundStyle(Color.sw.labelSecondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

/// Pros with a red check, then cons with a grey dash. Built from reason codes.
struct WhyList: View {
  let ranked: RankedScreen
  let formats: FilmFormats

  /// "We don't have details yet" isn't a reason to pick a screen, so it gets no check mark.
  private var pros: [Reason] {
    let s = ranked.screen
    guard s.techTier == .unknown && s.soundTier == .unknown else { return ranked.pros }
    return ranked.pros.filter { $0 != .techAndSound }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(pros.enumerated()), id: \.offset) { _, reason in
        line(Copy.reason(reason, screen: ranked.screen, formats: formats), pro: true)
      }
      ForEach(Array(ranked.cons.enumerated()), id: \.offset) { _, reason in
        line(Copy.reason(reason, screen: ranked.screen, formats: formats), pro: false)
      }
    }
  }

  private func line(_ text: String, pro: Bool) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: pro ? "checkmark" : "minus")
        .font(.body.weight(.semibold))
        .foregroundStyle(pro ? Color.sw.accent : Color.sw.labelTertiary)
        .frame(width: 24)
        .accessibilityHidden(true)
      Text(text)
        .font(.body)
        .foregroundStyle(Color.sw.label)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(pro ? text : String(localized: "Downside: \(text)"))
  }
}

struct TechRowView: View {
  let row: Copy.TechRow
  let onExplain: () -> Void

  var body: some View {
    Button(action: onExplain) {
      HStack(spacing: 14) {
        IconTile(systemImage: row.icon.rawValue)
        VStack(alignment: .leading, spacing: 2) {
          Text(row.title).font(.headline).foregroundStyle(Color.sw.label)
          Text(row.detail).font(.subheadline).foregroundStyle(Color.sw.labelSecondary)
        }
        Spacer(minLength: 0)
        QuestionMark(size: 22)
      }
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityHint("Explains this term")
  }
}

/// How it scores: four bars in a fixed order.
struct ScoreBars: View {
  let parts: ScoreParts

  var body: some View {
    VStack(spacing: 14) {
      bar(String(localized: "Picture quality"), parts.tech, 35)
      bar(String(localized: "Sound"), parts.sound, 25)
      bar(String(localized: "Picture size for this movie"), parts.size, 25)
      bar(String(localized: "Right shape and special version"), parts.format, 15)
    }
  }

  private func bar(_ label: String, _ value: Double, _ max: Double) -> some View {
    VStack(spacing: 6) {
      HStack {
        Text(label).foregroundStyle(Color.sw.label)
        Spacer()
        Text("\(Int(value.rounded())) / \(Int(max))")
          .monospacedDigit()
          .foregroundStyle(Color.sw.labelSecondary)
      }
      .font(.subheadline)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.sw.fill)
          Capsule().fill(Color.sw.label).frame(width: proxy.size.width * min(1, value / max))
        }
      }
      .frame(height: 6)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(label): \(Int(value.rounded())) out of \(Int(max))")
  }
}
