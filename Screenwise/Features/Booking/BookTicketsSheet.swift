import Models
import SwiftUI

/// Book tickets (spec 5.5). Plain outbound links to the booking apps.
/// If the app is installed and claims the link, iOS opens it. Otherwise Safari does.
struct BookTicketsSheet: View {
  let film: Film
  let screen: Screen
  @Environment(AppModel.self) private var model
  @Environment(\.openURL) private var openURL

  private var venue: Venue? { model.venue(for: screen) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Kicker(text: String(localized: "Book tickets"))
        Text(film.title)
          .font(.title2.bold())
          .foregroundStyle(Color.sw.label)
          .padding(.top, 6)
        Text([venue?.name, screen.hall].compactMap { $0 }.joined(separator: " · "))
          .font(.subheadline)
          .foregroundStyle(Color.sw.labelSecondary)
          .padding(.top, 4)
        option(
          title: String(localized: "Open BookMyShow"), venueURL: venue?.bookmyshowURL,
          fallback: AppConfig.bookMyShowHome
        )
        .padding(.top, 16)
        option(
          title: String(localized: "Open District"), venueURL: venue?.districtURL, fallback: AppConfig.districtHome
        )
        .padding(.top, 10)
        Text("Screenwise doesn't sell tickets. Prices and showtimes are on the booking app.")
          .font(.footnote)
          .foregroundStyle(Color.sw.labelSecondary)
          .padding(.top, 16)
      }
      .padding(.horizontal, Spacing.margin)
      .padding(.top, 28)
      .padding(.bottom, 24)
    }
    .background(Color.sw.background)
  }

  private func option(title: String, venueURL: URL?, fallback: URL) -> some View {
    let detail =
      venueURL != nil
      ? String(localized: "Opens this theatre's page")
      : String(localized: "Search for this theatre there")
    return Button {
      openURL(venueURL ?? fallback)
    } label: {
      HStack(spacing: 14) {
        IconTile(systemImage: "ticket", size: 44, background: Color.sw.card)
          .overlay(RoundedRectangle(cornerRadius: Radius.iconTile).stroke(Color.sw.separator, lineWidth: 0.5))
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.headline).foregroundStyle(Color.sw.label)
          Text(detail).font(.subheadline).foregroundStyle(Color.sw.labelSecondary)
        }
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right").foregroundStyle(Color.sw.labelTertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: Radius.grouped, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(PressableStyle(scale: 0.98))
    .accessibilityLabel(title)
    .accessibilityHint(detail)
  }
}
