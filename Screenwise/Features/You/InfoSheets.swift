import Models
import Scoring
import SwiftUI

/// Every screen on Screenwise side by side (spec 5.7). The dense table lives here, not on hero pages.
struct AllScreensSheet: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Kicker(text: String(localized: "All screens"))
        Text("Side by side")
          .font(.title2.bold())
          .foregroundStyle(Color.sw.label)
          .padding(.top, 6)
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 0) {
          GridRow {
            ForEach(["Theatre", "Screen", "Picture", "Sound"], id: \.self) { h in
              Text(LocalizedStringKey(h))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sw.labelSecondary)
            }
          }
          .padding(.vertical, 6)
          Divider().overlay(Color.sw.separator).gridCellUnsizedAxes(.horizontal)
          ForEach(model.theatres.openScreens) { screen in
            GridRow(alignment: .top) {
              VStack(alignment: .leading, spacing: 1) {
                Text(model.venue(for: screen)?.name ?? "").foregroundStyle(Color.sw.label)
                Text(screen.hall).foregroundStyle(Color.sw.labelSecondary)
              }
              Text(sizeText(screen)).monospacedDigit().foregroundStyle(Color.sw.label)
              Text(Copy.formatText(screen)).foregroundStyle(Color.sw.label)
              Text(Copy.soundName(screen.soundTier)).foregroundStyle(Color.sw.label)
            }
            .font(.footnote)
            .padding(.vertical, 9)
            .accessibilityElement(children: .combine)
            Divider().overlay(Color.sw.separator).gridCellUnsizedAxes(.horizontal)
          }
        }
        .padding(.top, 12)
        Text("* Some specs not confirmed yet. Tap a theatre's Specs and sources to see where each value comes from.")
          .font(.footnote)
          .foregroundStyle(Color.sw.labelSecondary)
          .padding(.top, 12)

        SectionTitle(title: String(localized: "Coming up"))
          .padding(.top, 24)
        ForEach(model.theatres.venues.filter { $0.status == .upcoming }) { venue in
          let screen = model.theatres.upcomingScreens.first { $0.venueID == venue.id }
          VStack(alignment: .leading, spacing: 2) {
            Text([venue.name, screen?.formatLabel].compactMap { $0 }.joined(separator: " · "))
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Color.sw.label)
            Text([venue.area, venue.expectedOpen].compactMap { $0 }.joined(separator: " · "))
              .font(.footnote)
              .foregroundStyle(Color.sw.labelSecondary)
          }
          .padding(.vertical, 8)
          .accessibilityElement(children: .combine)
        }
      }
      .padding(.horizontal, Spacing.margin)
      .padding(.top, 28)
      .padding(.bottom, 34)
    }
    .background(Color.sw.background)
  }

  private func sizeText(_ screen: Screen) -> String {
    guard let w = screen.widthFt, let h = screen.heightFt else { return "?" }
    let star = screen.fields.widthFt.status == .sourced && screen.fields.heightFt.status == .sourced ? "" : " *"
    return "\(Copy.feet(w)) × \(Copy.feet(h)) ft\(star)"
  }
}

/// Cinema tech explained: every explainer in one list.
struct CinemaTechSheet: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(Term.glossaryOrder) { term in
            let copy = Explainer.copy(for: term, hasOpenIMAX: model.hasOpenIMAX)
            NavigationLink(value: term) {
              VStack(alignment: .leading, spacing: 2) {
                Text(copy.title).font(.headline).foregroundStyle(Color.sw.label)
                Text(copy.summary).font(.subheadline).foregroundStyle(Color.sw.labelSecondary).lineLimit(2)
              }
              .padding(.vertical, 2)
            }
          }
        } header: {
          VStack(alignment: .leading, spacing: 6) {
            Kicker(text: String(localized: "Cinema tech explained"))
            Text("The words on a ticket").font(.title2.bold()).foregroundStyle(Color.sw.label)
          }
          .textCase(nil)
          .padding(.bottom, 8)
        }
      }
      .listStyle(.insetGrouped)
      .navigationDestination(for: Term.self) { term in
        ScrollView {
          ExplainerContent(term: term, extra: nil, hasOpenIMAX: model.hasOpenIMAX)
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, 16)
        }
        .background(Color.sw.background)
        .navigationBarTitleDisplayMode(.inline)
      }
    }
  }
}

/// About and data sources (spec 5.7 and 14).
struct AboutSheet: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Kicker(text: String(localized: "About"))
        Text("Data and sources")
          .font(.title2.bold())
          .foregroundStyle(Color.sw.label)
          .padding(.top, 6)

        paragraph(
          "Screen specs come from public sources and our research. They can be wrong. Tap any spec to see its source, and report fixes."
        )

        SectionTitle(title: String(localized: "How we get our data")).padding(.top, 24)
        item(
          "film", String(localized: "Movies"),
          String(localized: "We update the list of movies every day from TMDB, with India release dates and artwork."))
        item(
          "sparkles.tv", String(localized: "IMAX, Dolby Vision and screen shape"),
          String(
            localized:
              "We check these by hand for big releases. Anything the studio hasn't confirmed is marked expected or est., and the ranking uses our best estimate until they do."
          ))
        item(
          "building.2", String(localized: "Theatres"),
          String(
            localized:
              "We review screen sizes, projectors and sound every week or two. Every value has a source, and values we couldn't confirm are marked."
          ))
        item(
          "ticket", String(localized: "Showtimes and prices"),
          String(localized: "We don't show these. Book on BookMyShow or District to see them."))
        item(
          "magnifyingglass", String(localized: "Missing movies"),
          String(
            localized:
              "If a movie isn't here yet, it usually appears within a day of TMDB adding its India release. You can also tell us about it."
          ))

        SectionTitle(title: String(localized: "Movie data")).padding(.top, 24)
        paragraph(
          "Movie details and artwork come from TMDB. This product uses the TMDB API but is not endorsed or certified by TMDB."
        )
        if model.catalogue.isSample {
          paragraph("This build uses a sample movie list and stand-in artwork until the TMDB connection is set up.")
        }

        SectionTitle(title: String(localized: "Privacy")).padding(.top, 24)
        paragraph(
          "Screenwise has no accounts and no tracking. Your saved theatres, history and details stay on this phone and are never sent anywhere."
        )

        SectionTitle(title: String(localized: "Credits")).padding(.top, 24)
        paragraph(
          "The 3D halls use three.js, released under the MIT License. Copyright 2010 to 2023 three.js authors. IMAX, Dolby Cinema, Dolby Vision, Dolby Atmos, HDR by Barco, EPIQ and PCX are trademarks of their owners."
        )

        SectionTitle(title: String(localized: "Versions")).padding(.top, 24)
        paragraph(versionText)

        Button {
          model.sheet = .feedback(FeedbackDraft(kind: .general, subject: String(localized: "A problem"), field: nil))
        } label: {
          Label("Report a problem", systemImage: "exclamationmark.bubble")
            .font(.headline)
            .foregroundStyle(Color.sw.label)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
              Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 24)
      }
      .padding(.horizontal, Spacing.margin)
      .padding(.top, 28)
      .padding(.bottom, 34)
    }
    .background(Color.sw.background)
  }

  private var versionText: String {
    let info = Bundle.main.infoDictionary
    let app = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return String(
      localized: "App \(app) (\(build)) · Theatre data \(model.theatres.updatedOn) · Score \(Scorer.version)")
  }

  private func paragraph(_ text: LocalizedStringKey) -> some View {
    Text(text)
      .font(.body)
      .foregroundStyle(Color.sw.label)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 10)
  }

  private func paragraph(_ text: String) -> some View {
    Text(text)
      .font(.body)
      .foregroundStyle(Color.sw.label)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 10)
  }

  private func item(_ icon: String, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      IconTile(systemImage: icon)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.headline).foregroundStyle(Color.sw.label)
        Text(text)
          .font(.subheadline)
          .foregroundStyle(Color.sw.labelSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.top, 14)
    .accessibilityElement(children: .combine)
  }
}

/// The city pill opens this in v1.
struct CitySheet: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let cinemas = model.theatres.venues.filter { $0.status == .open }.count
    VStack(alignment: .leading, spacing: 10) {
      Kicker(text: String(localized: "City"))
      Text("Hyderabad").font(.title2.bold()).foregroundStyle(Color.sw.label)
      Text(
        "Screenwise covers \(cinemas) cinemas in Hyderabad, including every premium screen we know of. We add more every week or two. More cities are coming."
      )
      .font(.body)
      .foregroundStyle(Color.sw.label)
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, Spacing.margin)
    .padding(.top, 28)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.sw.background)
  }
}
