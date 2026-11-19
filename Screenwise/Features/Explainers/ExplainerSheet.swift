import SwiftUI

/// "Explained simply" sheet for one term (spec 5.8).
struct ExplainerSheet: View {
  let term: Term
  let extra: ExplainerExtra?
  @Environment(AppModel.self) private var model

  var body: some View {
    ScrollView {
      ExplainerContent(term: term, extra: extra, hasOpenIMAX: model.hasOpenIMAX)
        .padding(.horizontal, Spacing.margin)
        .padding(.top, 28)
        .padding(.bottom, 34)
    }
    .scrollIndicators(.hidden)
    .background(Color.sw.background)
  }
}

struct ExplainerContent: View {
  let term: Term
  let extra: ExplainerExtra?
  let hasOpenIMAX: Bool

  var body: some View {
    let copy = Explainer.copy(for: term, hasOpenIMAX: hasOpenIMAX)
    VStack(alignment: .leading, spacing: 0) {
      Kicker(text: String(localized: "Explained simply"))
      Text(copy.title)
        .font(.title2.bold())
        .foregroundStyle(Color.sw.label)
        .padding(.top, 6)
        .accessibilityAddTraits(.isHeader)
      if let kind = copy.diagram {
        ExplainerDiagram(kind: kind)
          .frame(height: 132)
          .frame(maxWidth: .infinity)
          .background(Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          .padding(.top, 16)
      }
      Text(copy.what)
        .font(.body)
        .foregroundStyle(Color.sw.label)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 12)
      box(title: String(localized: "Why it matters"), text: copy.why)
      if extra?.isEstimate == true {
        box(title: String(localized: "Not confirmed yet"), text: estimateNote)
      }
      if term == .shape, let extra, let venue = extra.venue, let screen = extra.screenSize {
        let text =
          extra.pictureSize.map {
            String(localized: "The screen is \(screen) ft. This movie plays \($0) ft on it.")
          } ?? String(localized: "The screen is \(screen) ft.")
        box(title: String(localized: "At \(venue)"), text: text)
      }
    }
  }

  private func box(title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.sw.labelSecondary)
      Text(text)
        .font(.subheadline)
        .foregroundStyle(Color.sw.label)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: Radius.grouped, style: .continuous))
    .padding(.top, 16)
    .accessibilityElement(children: .combine)
  }
}

/// Small diagrams drawn with the tokens: screen shape, contrast, speakers, viewing angle.
struct ExplainerDiagram: View {
  enum Kind: Sendable { case shape, contrast, speakers, angle }
  let kind: Kind

  var body: some View {
    Group {
      switch kind {
      case .shape: shape
      case .contrast: contrast
      case .speakers: speakers
      case .angle: angle
      }
    }
    .padding(16)
  }

  private var shape: some View {
    HStack(spacing: 28) {
      VStack(spacing: 8) {
        Rectangle().fill(Color.sw.accent.opacity(0.9)).frame(width: 120, height: 50)
          .clipShape(RoundedRectangle(cornerRadius: 3))
        Text("Wide movie, wide screen").font(.caption).foregroundStyle(Color.sw.labelSecondary)
      }
      VStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 3).stroke(Color.sw.labelTertiary, lineWidth: 1.5)
            .frame(width: 118, height: 64)
          Rectangle().fill(Color.sw.accent.opacity(0.9)).frame(width: 116, height: 49)
        }
        Text("Wide movie, taller screen").font(.caption).foregroundStyle(Color.sw.labelSecondary)
      }
    }
    .accessibilityElement()
    .accessibilityLabel("A wide movie fills a wide screen. On a taller screen it gets bars above and below.")
  }

  private var contrast: some View {
    HStack(spacing: 28) {
      VStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 8)
          .fill(
            LinearGradient(colors: [Color(white: 0.27), Color(white: 0.73)], startPoint: .leading, endPoint: .trailing)
          )
          .frame(width: 120, height: 56)
        Text("Standard").font(.caption).foregroundStyle(Color.sw.labelSecondary)
      }
      VStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 8)
          .fill(LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing))
          .frame(width: 120, height: 56)
        Text("High contrast").font(.caption).foregroundStyle(Color.sw.labelSecondary)
      }
    }
    .accessibilityElement()
    .accessibilityLabel("A standard picture next to a high contrast picture with deeper blacks and brighter whites.")
  }

  private var speakers: some View {
    Canvas { ctx, size in
      let c = CGPoint(x: size.width / 2, y: size.height * 0.62)
      let spots: [CGPoint] = [
        CGPoint(x: c.x - 100, y: c.y), CGPoint(x: c.x + 100, y: c.y),
        CGPoint(x: c.x - 70, y: c.y - 40), CGPoint(x: c.x + 70, y: c.y - 40),
        CGPoint(x: c.x, y: c.y - 54), CGPoint(x: c.x - 50, y: c.y + 30), CGPoint(x: c.x + 50, y: c.y + 30),
      ]
      var arc = Path()
      arc.move(to: CGPoint(x: c.x - 90, y: c.y - 40))
      arc.addQuadCurve(to: CGPoint(x: c.x + 90, y: c.y - 40), control: CGPoint(x: c.x, y: c.y - 80))
      ctx.stroke(arc, with: .color(Color.sw.labelTertiary), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
      for p in spots {
        let r = CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)
        ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(Color.sw.label), lineWidth: 1.5)
      }
      ctx.fill(Path(ellipseIn: CGRect(x: c.x - 10, y: c.y - 10, width: 20, height: 20)), with: .color(Color.sw.accent))
    }
    .accessibilityLabel("Speakers around and above the audience.")
  }

  private var angle: some View {
    Canvas { ctx, size in
      let screen = CGRect(x: size.width / 2 - 120, y: 4, width: 240, height: 8)
      ctx.fill(Path(roundedRect: screen, cornerRadius: 2), with: .color(Color.sw.accent))
      let eye = CGPoint(x: size.width / 2, y: size.height - 12)
      var lines = Path()
      lines.move(to: CGPoint(x: screen.minX, y: screen.maxY))
      lines.addLine(to: eye)
      lines.addLine(to: CGPoint(x: screen.maxX, y: screen.maxY))
      ctx.stroke(lines, with: .color(Color.sw.labelTertiary), lineWidth: 1.5)
      var arc = Path()
      arc.addArc(center: eye, radius: 40, startAngle: .degrees(-144), endAngle: .degrees(-36), clockwise: false)
      ctx.stroke(arc, with: .color(Color.sw.accent), lineWidth: 2)
      ctx.fill(Path(ellipseIn: CGRect(x: eye.x - 6, y: eye.y - 6, width: 12, height: 12)), with: .color(Color.sw.label))
    }
    .accessibilityLabel("The viewing angle is how wide the screen looks from your seat.")
  }
}
