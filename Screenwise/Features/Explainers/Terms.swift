import Foundation

/// Every technical term that has a "?" in the app (spec 5.8).
enum Term: String, CaseIterable, Identifiable, Sendable, Hashable {
  case dolbyCinema, dolbyVision, atmos, laser, rgbLaser, hdrBarco, imax, imax143, threeD, epiq
  case led, pcx, dtsx, shape, score, angle

  var id: String { rawValue }

  /// The order used in "Cinema tech explained".
  static let glossaryOrder: [Term] = [
    .dolbyCinema, .dolbyVision, .atmos, .laser, .rgbLaser, .hdrBarco, .imax, .imax143, .threeD,
    .epiq, .led, .pcx, .dtsx, .shape, .score, .angle,
  ]
}

/// Plain-English copy for one term. Each explainer stays under 60 words.
/// Diagrams are drawn in SwiftUI (`ExplainerDiagram`).
struct Explainer: Sendable {
  let title: String
  let what: String
  let why: String
  let diagram: ExplainerDiagram.Kind?

  /// The first sentence, for the glossary list.
  var summary: String {
    let first = what.split(separator: ".", maxSplits: 1).first.map(String.init) ?? what
    return first + "."
  }

  // swiftlint:disable line_length
  static func copy(for term: Term, hasOpenIMAX: Bool = false) -> Explainer {
    switch term {
    case .dolbyCinema:
      Explainer(
        title: String(localized: "Dolby Cinema"),
        what: String(
          localized:
            "Dolby's complete premium cinema. It pairs Dolby Vision picture with Dolby Atmos sound, in a room designed to stay dark."
        ),
        why: String(
          localized:
            "You get the best contrast and sound in one place. A movie released in Dolby Vision looks its best here."),
        diagram: .contrast)
    case .dolbyVision:
      Explainer(
        title: String(localized: "Dolby Vision projection"),
        what: String(
          localized:
            "Two laser projectors work together, so the picture can be very bright and very dark at the same time. Night scenes look black instead of grey."
        ),
        why: String(
          localized:
            "Dark movies and bright action both look better. It's the biggest picture upgrade you can get in Hyderabad today."
        ),
        diagram: .contrast)
    case .atmos:
      Explainer(
        title: String(localized: "Dolby Atmos"),
        what: String(
          localized:
            "Speakers surround you and hang from the ceiling, so sounds can move around and over your head. \"64 channels\" means up to 64 separate speaker feeds."
        ),
        why: String(localized: "Most premium halls here have Atmos, so it rarely decides the ranking on its own."),
        diagram: .speakers)
    case .laser:
      Explainer(
        title: String(localized: "4K laser projection"),
        what: String(
          localized:
            "The projector uses lasers instead of a lamp. The picture is brighter, colours stay steady, and 4K shows four times the detail of older 2K projectors."
        ),
        why: String(
          localized: "It's the modern standard for a good hall. Dolby Vision and HDR by Barco go a step further."),
        diagram: nil)
    case .rgbLaser:
      Explainer(
        title: String(localized: "RGB laser projection"),
        what: String(
          localized:
            "Separate red, green and blue lasers make the picture. Colours are richer and the image is brighter than with a standard laser projector."
        ),
        why: String(
          localized: "It's a step above standard 4K laser, but it doesn't reach the contrast of Dolby Vision."),
        diagram: nil)
    case .hdrBarco:
      Explainer(
        title: String(localized: "HDR by Barco"),
        what: String(
          localized:
            "Barco's projector moves light away from the dark parts of the picture into the bright parts. Highlights such as sunlight can be over six times brighter than normal."
        ),
        why: String(
          localized: "Bright, colourful movies look their best here. AMB Cinemas and Prasads have it in Hyderabad."),
        diagram: .contrast)
    case .imax:
      Explainer(
        title: String(localized: "IMAX"),
        what: String(
          localized:
            "IMAX's own projection, sound and screen design. Movies shot or formatted for IMAX can show extra picture at the top and bottom, but only on IMAX screens."
        ),
        why: hasOpenIMAX
          ? String(localized: "On a movie page, IMAX screens rank higher for movies that have an IMAX version.")
          : String(
            localized: "Hyderabad has no IMAX screen open yet. A movie page shows any IMAX screen that is due to open."),
        diagram: nil)
    case .imax143:
      Explainer(
        title: String(localized: "IMAX 1.43 scenes"),
        what: String(
          localized:
            "The tallest IMAX picture, almost square. Only some IMAX screens can show it, and these scenes fill far more of your view."
        ),
        why: String(
          localized:
            "A movie with 1.43 scenes looks most dramatic on a 1.43 IMAX screen. Hyderabad doesn't have one open yet."),
        diagram: nil)
    case .threeD:
      Explainer(
        title: String(localized: "3D"),
        what: String(localized: "The movie has a 3D version. You watch with glasses, and the picture gains depth."),
        why: String(
          localized:
            "Not every hall plays the 3D version, and our scores don't count it yet. Check the format when you book."),
        diagram: nil)
    case .epiq:
      Explainer(
        title: String(localized: "EPIQ"),
        what: String(
          localized:
            "Qube's premium large format brand. It means a bigger screen, laser projection and Atmos, set up by the theatre."
        ),
        why: String(
          localized: "The name alone doesn't promise one specific projector, so we score the actual equipment."),
        diagram: nil)
    case .led:
      Explainer(
        title: String(localized: "LED cinema screen"),
        what: String(localized: "The screen is made of LEDs that give off their own light. There is no projector."),
        why: String(
          localized:
            "Blacks are deep and colours are bright. These screens are usually smaller than projection screens, so they score lower on size."
        ),
        diagram: .contrast)
    case .pcx:
      Explainer(
        title: String(localized: "PCX"),
        what: String(localized: "Prasads' own premium large format, with one of the biggest screens in India."),
        why: String(
          localized: "Its size is the main draw. We score the projector and sound it actually has, not the name."),
        diagram: nil)
    case .dtsx:
      Explainer(
        title: String(localized: "DTS:X"),
        what: String(localized: "A surround sound format with speakers around and above you."),
        why: String(localized: "It is a good sound system. In our ranking it scores a little below Dolby Atmos."),
        diagram: .speakers)
    case .shape:
      Explainer(
        title: String(localized: "Screen shape"),
        what: String(
          localized:
            "Movies come in shapes. Wide scope movies are 2.39 times wider than they are tall. Flat movies are taller, at 1.85. A screen built for one shape shows the other with black bars."
        ),
        why: String(
          localized:
            "A wide movie fills a scope screen completely. On a flat screen it keeps the full width but leaves bars above and below."
        ),
        diagram: .shape)
    case .score:
      Explainer(
        title: String(localized: "Screen score"),
        what: String(
          localized:
            "Our 0 to 100 rating of how well this theatre shows this movie. Picture quality counts most (35), then sound (25), then picture size for the movie's shape (25), then the right shape and any special version (15)."
        ),
        why: String(
          localized:
            "A huge screen with ordinary projection can't beat a premium hall. The same theatre can score differently for another movie."
        ),
        diagram: nil)
    case .angle:
      Explainer(
        title: String(localized: "Viewing angle"),
        what: String(
          localized:
            "How much of your view the picture fills from your seat. Around 40° feels relaxed, 50° to 60° feels immersive, and above 80° you'll turn your head."
        ),
        why: String(localized: "Pick a row that feels right for you. Big action movies reward a more immersive seat."),
        diagram: .angle)
    }
  }
  // swiftlint:enable line_length
}

/// The note added to an explainer when the fact is expected or estimated (spec 5.3).
let estimateNote = String(
  localized: "The studio hasn't confirmed this yet. The ranking uses our best estimate and updates when they do.")
