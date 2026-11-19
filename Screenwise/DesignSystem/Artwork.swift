import Models
import SwiftUI
import UIKit

/// Which TMDB image to use (spec 5.2 artwork rule).
enum ArtworkSource: Equatable {
  /// No language tag, so we place our own title over it.
  case textless(URL)
  /// A backdrop cropped to the card. We place our title over it.
  case backdrop(URL)
  /// A poster with the title painted on. We never add our own title over it.
  case titled(URL)
  /// No artwork yet (sample data, or TMDB has none). We draw a soft colour field.
  case generated

  init(film: Film, posterWidth: Int = 780, backdropWidth: Int = 1280) {
    let base = AppConfig.tmdbImageBase
    if let p = film.textlessPosterPath {
      self = .textless(base.appending(path: "w\(posterWidth)\(p)"))
    } else if let b = film.backdropPath {
      self = .backdrop(base.appending(path: "w\(backdropWidth)\(b)"))
    } else if let p = film.posterPath {
      self = .titled(base.appending(path: "w\(posterWidth)\(p)"))
    } else {
      self = .generated
    }
  }

  var showsOwnTitle: Bool {
    if case .titled = self { return false }
    return true
  }
}

/// Movie artwork, filling its frame and weighted to the top.
struct FilmArtwork: View {
  let film: Film
  var posterWidth = 780

  var body: some View {
    let source = ArtworkSource(film: film, posterWidth: posterWidth)
    Color.clear
      .overlay(alignment: .top) {
        switch source {
        case .textless(let url), .backdrop(let url), .titled(let url):
          AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
            if let image = phase.image {
              image.resizable().scaledToFill()
            } else {
              GeneratedArt(film: film)
            }
          }
        case .generated:
          GeneratedArt(film: film)
        }
      }
      .clipped()
      .accessibilityHidden(true)
  }
}

/// A soft colour field from the movie's tint. Stand-in artwork, never a fake poster.
struct GeneratedArt: View {
  let film: Film

  var body: some View {
    let base = UIColor(Color(hex: film.tintHex) ?? Color(hex: "#9FB7FF")!)
    let seed = film.id.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
    let wobble = { (i: UInt32) -> Float in Float((seed >> (i % 24)) & 0xFF) / 255 * 0.24 - 0.12 }
    MeshGradient(
      width: 3, height: 3,
      points: [
        [0, 0], [0.5 + wobble(1), 0], [1, 0],
        [0, 0.45 + wobble(3)], [0.5 + wobble(5), 0.4 + wobble(7)], [1, 0.5 + wobble(9)],
        [0, 1], [0.5 + wobble(11), 1], [1, 1],
      ],
      colors: [
        Color(base.adjusted(brightness: 0.55, saturation: 1.1)),
        Color(base.adjusted(brightness: 0.85, saturation: 1.05)),
        Color(base.adjusted(brightness: 0.45, saturation: 1.2)),
        Color(base.adjusted(brightness: 0.75, saturation: 1.0)),
        Color(base.adjusted(brightness: 1.05, saturation: 0.9)),
        Color(base.adjusted(brightness: 0.6, saturation: 1.15)),
        Color(base.adjusted(brightness: 0.18, saturation: 1.0)),
        Color(base.adjusted(brightness: 0.28, saturation: 1.1)),
        Color(base.adjusted(brightness: 0.14, saturation: 1.0)),
      ]
    )
    .overlay {
      RadialGradient(
        colors: [.white.opacity(0.28), .clear], center: UnitPoint(x: 0.62, y: 0.32),
        startRadius: 0, endRadius: 260
      )
      .blendMode(.softLight)
    }
  }
}

extension UIColor {
  /// A brighter or darker, more or less saturated copy. For generated artwork only.
  func adjusted(brightness b: CGFloat, saturation s: CGFloat) -> UIColor {
    var h: CGFloat = 0
    var sat: CGFloat = 0
    var bri: CGFloat = 0
    var a: CGFloat = 0
    getHue(&h, saturation: &sat, brightness: &bri, alpha: &a)
    return UIColor(hue: h, saturation: min(1, sat * s), brightness: min(1, bri * b), alpha: a)
  }
}

/// The glass status chip: "In cinemas" with a green dot, or "In cinemas 18 Dec".
struct StatusChip: View {
  let film: Film
  let today: Date

  var body: some View {
    HStack(spacing: 6) {
      if film.isInCinemas(on: today) {
        Circle().fill(Color.sw.success).frame(width: 6, height: 6)
      }
      Text(Copy.status(film, today: today))
        .font(.footnote.weight(.semibold))
        .monospacedDigit()
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 11)
    .frame(minHeight: 28)
    .swGlassOnImage(in: Capsule())
  }
}
