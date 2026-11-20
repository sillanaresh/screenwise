import Models
import Scoring
import SwiftUI

/// One theatre in the ranking, in an Airbnb listing style (spec 5.3).
struct TheatreCard: View {
  let film: Film
  let ranked: RankedScreen
  let total: Int
  @Environment(AppModel.self) private var model

  /// "6 km" once the user has turned on Near me. Straight line, so it's approximate.
  private func distanceText(_ venue: Venue?) -> String? {
    guard let km = model.nearMe.distanceKm(to: venue) else { return nil }
    return String(localized: "\(Int(km.rounded())) km")
  }

  var body: some View {
    let screen = ranked.screen
    let venue = model.venue(for: screen)
    let saved = model.isSaved(screen.id)

    VStack(alignment: .leading, spacing: 0) {
      HallThumbnail(screen: screen, film: film)
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Radius.theatreImage, style: .continuous))
        .swShadowSmall()
        .overlay(alignment: .topLeading) { rankBadge.padding(12) }

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          Text(venue?.name ?? screen.name)
            .font(.headline)
            .foregroundStyle(Color.sw.label)
          Spacer(minLength: 0)
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(ranked.shown)").font(.headline.bold())
            Text(verbatim: "/100").font(.caption).foregroundStyle(Color.sw.labelSecondary)
          }
          .monospacedDigit()
          .foregroundStyle(Color.sw.label)
        }
        Text(
          [screen.hall, venue?.area, distanceText(venue), ranked.band.label].compactMap { $0 }.joined(separator: " · ")
        )
        .font(.subheadline)
        .foregroundStyle(Color.sw.labelSecondary)
        Text(Copy.reason(ranked.mainReason, screen: screen, formats: film.formats))
          .font(.subheadline)
          .foregroundStyle(Color.sw.label)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 2)
        PillRow(spacing: 6) {
          ForEach(Copy.facts(screen)) { fact in
            Pill(
              text: fact.text, style: fact.term == nil ? .outlined : .confirmed, term: fact.term,
              onExplain: { model.explain($0) })
          }
        }
        .padding(.top, 8)
        if screen.isLowConfidence {
          HStack(spacing: 6) {
            ProvenanceMarker(status: .unverified, size: 7)
            Text("Some specs not confirmed yet")
          }
          .font(.footnote)
          .foregroundStyle(Color.sw.labelSecondary)
          .padding(.top, 4)
        }
      }
      .padding(.horizontal, 2)
      .padding(.top, 12)
    }
    .contentShape(Rectangle())
    .onTapGesture { model.openTheatre(screen, film: film) }
    // The card reads as one element. The heart stays a separate control (spec 13.6).
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText(venue: venue))
    .accessibilityAddTraits(.isButton)
    .accessibilityIdentifier("theatreCard.\(ranked.rank)")
    .accessibilityAction { model.openTheatre(screen, film: film) }
    .overlay(alignment: .topTrailing) {
      GlassIconButton(
        systemImage: saved ? "heart.fill" : "heart", label: saved ? "Remove from saved" : "Save theatre",
        tint: saved ? Color.sw.accent : nil
      ) { model.toggleSaved(screen.id) }
      .padding(8)
    }
  }

  private var rankBadge: some View {
    Group {
      if ranked.rank == 1 {
        Text("Best pick")
          .foregroundStyle(Color.sw.onAccent)
          .padding(.horizontal, 12)
          .frame(minHeight: 30)
          .background(Color.sw.accent, in: Capsule())
      } else {
        Text(verbatim: "#\(ranked.rank)")
          .monospacedDigit()
          .foregroundStyle(Color.sw.label)
          .padding(.horizontal, 12)
          .frame(minHeight: 30)
          .swGlass(in: Capsule())
      }
    }
    .font(.footnote.bold())
    .accessibilityHidden(true)
  }

  private func accessibilityText(venue: Venue?) -> String {
    let screen = ranked.screen
    var parts = [
      String(localized: "Rank \(ranked.rank)"),
      venue?.name ?? screen.name,
      screen.hall,
      venue?.area ?? "",
      String(localized: "score \(ranked.shown) out of 100, \(ranked.band.label)"),
      Copy.reason(ranked.mainReason, screen: screen, formats: film.formats),
    ]
    if screen.isLowConfidence { parts.append(String(localized: "Some specs not confirmed yet")) }
    return parts.filter { !$0.isEmpty }.joined(separator: ", ")
  }
}
