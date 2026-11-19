import Models
import Scoring
import SwiftUI
import WebKit

/// The stage background behind the hall scene: a soft radial gradient (spec 7.2 `stage`).
struct StageBackground: View {
  var body: some View {
    RadialGradient(
      stops: [
        .init(color: Color.sw.stageCenter, location: 0),
        .init(color: Color.sw.stageMid, location: 0.6),
        .init(color: Color.sw.stageEdge, location: 1),
      ],
      center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 420)
  }
}

/// Hosts the shared live web view. SwiftUI owns the gestures, so this view takes no touches.
struct HallWebView: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let container = UIView()
    container.backgroundColor = .clear
    container.isUserInteractionEnabled = false
    attach(to: container)
    return container
  }

  func updateUIView(_ container: UIView, context: Context) {
    attach(to: container)
  }

  static func dismantleUIView(_ container: UIView, coordinator: ()) {
    let web = HallHost.shared.liveScene().webView
    if web.superview === container { HallHost.shared.park(web, force: true) }
  }

  @MainActor private func attach(to container: UIView) {
    let web = HallHost.shared.liveScene().webView
    guard web.superview !== container else { return }
    web.removeFromSuperview()
    web.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(web)
    NSLayoutConstraint.activate([
      web.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      web.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      web.topAnchor.constraint(equalTo: container.topAnchor),
      web.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
  }
}

/// The card image on the Movie page: a snapshot of The hall view, cached per screen,
/// movie and theme. Shows a `fill` placeholder until it's ready, and the 2D drawing when
/// WebGL isn't available.
struct HallThumbnail: View {
  let screen: Screen
  let film: Film?
  @Environment(\.colorScheme) private var scheme
  @State private var image: UIImage?

  var body: some View {
    let config = HallSceneConfig(screen: screen, film: film, dark: scheme == .dark)
    ZStack {
      Color.sw.fill
      if let image {
        Image(uiImage: image).resizable().scaledToFill().transition(.opacity)
      } else if let config, HallHost.shared.useFallback {
        HallDrawing(config: config, row: nil).padding(12)
      }
    }
    .animation(.easeOut(duration: 0.4), value: image)
    .accessibilityHidden(true)
    .task(id: config?.thumbnailKey) {
      guard let config else { return }
      if let cached = HallHost.shared.cachedThumbnail(config) {
        image = cached
        return
      }
      image = nil
      image = await HallHost.shared.thumbnail(config)
    }
  }
}

/// The 2D fallback (spec 10.7): the screen outline to scale, the picture for this movie
/// inside it and a 6 ft figure. Used when WebGL fails or in Low Power Mode.
struct HallDrawing: View {
  let config: HallSceneConfig
  /// When set, a line under the screen shows the viewing angle from this row.
  let row: Int?

  var body: some View {
    Canvas { ctx, size in
      let margin: CGFloat = 16
      let scale = min((size.width - margin * 2) / config.screenW, (size.height * 0.62) / config.screenH)
      let sw = config.screenW * scale
      let sh = config.screenH * scale
      let origin = CGPoint(x: (size.width - sw) / 2, y: size.height * 0.12)
      let screenRect = CGRect(origin: origin, size: CGSize(width: sw, height: sh))
      ctx.stroke(Path(screenRect), with: .color(Color.sw.labelSecondary), lineWidth: 1.5)

      let pw = config.pictureW * scale
      let ph = config.pictureH * scale
      let pictureRect = CGRect(x: screenRect.midX - pw / 2, y: screenRect.midY - ph / 2, width: pw, height: ph)
      let tint = Color(hex: config.tintHex) ?? .gray
      ctx.fill(
        Path(pictureRect),
        with: .linearGradient(
          Gradient(colors: [tint.opacity(0.95), tint.opacity(0.6)]),
          startPoint: pictureRect.origin, endPoint: CGPoint(x: pictureRect.maxX, y: pictureRect.maxY)))

      // A 6 ft figure standing on the floor line, 36% of the picture width left of centre.
      let floorY = screenRect.maxY + 3 * scale
      let figureH = 6 * scale
      let fx = screenRect.midX - pw * 0.36
      let head = CGRect(x: fx - figureH * 0.08, y: floorY - figureH, width: figureH * 0.16, height: figureH * 0.16)
      ctx.fill(Path(ellipseIn: head), with: .color(Color.sw.accent))
      let body = CGRect(
        x: fx - figureH * 0.11, y: floorY - figureH * 0.82, width: figureH * 0.22, height: figureH * 0.82)
      ctx.fill(Path(roundedRect: body, cornerRadius: figureH * 0.11), with: .color(Color.sw.accent))
      ctx.stroke(
        Path { p in
          p.move(to: CGPoint(x: margin, y: floorY))
          p.addLine(to: CGPoint(x: size.width - margin, y: floorY))
        }, with: .color(Color.sw.separator), lineWidth: 1)
    }
    .accessibilityHidden(true)
  }
}
