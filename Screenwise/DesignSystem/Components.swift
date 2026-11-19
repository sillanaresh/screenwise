import Models
import SwiftUI

/// The "?" glyph: a 1.3 pt ring in `labelTertiary` with a bold "?" in `labelSecondary`.
struct QuestionMark: View {
  var size: CGFloat = 16
  @ScaledMetric(relativeTo: .caption2) private var scale: CGFloat = 1

  var body: some View {
    Text(verbatim: "?")
      .font(.caption2.bold())
      .foregroundStyle(Color.sw.labelSecondary)
      .frame(width: size * scale, height: size * scale)
      .overlay(Circle().stroke(Color.sw.labelTertiary, lineWidth: 1.3))
      .accessibilityHidden(true)
  }
}

/// A pill for one fact. Confirmed facts use `fill`; expected or estimated facts are outlined.
struct Pill: View {
  enum Style { case confirmed, outlined }

  let text: String
  var style: Style = .confirmed
  /// When set, the pill ends with "?" and opens this explainer.
  var term: Term? = nil
  var onExplain: ((Term) -> Void)? = nil

  var body: some View {
    let content = HStack(spacing: 6) {
      Text(text)
        .font(.footnote.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(Color.sw.label)
        .lineLimit(1)
      if term != nil { QuestionMark() }
    }
    .padding(.horizontal, 12)
    .frame(minHeight: 32)
    .background {
      Capsule().fill(style == .confirmed ? Color.sw.fill : .clear)
    }
    .overlay {
      if style == .outlined { Capsule().strokeBorder(Color.sw.separator, lineWidth: 1) }
    }

    if let term, let onExplain {
      Button {
        onExplain(term)
      } label: {
        content.frame(minHeight: Spacing.minHit).contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(text)
      .accessibilityHint("Explains this term")
    } else {
      content.accessibilityElement(children: .combine)
    }
  }
}

/// A wrapping row of pills. 8 pt between pills.
struct PillRow<Content: View>: View {
  var spacing: CGFloat = 8
  @ViewBuilder let content: Content

  var body: some View {
    FlowLayout(spacing: spacing, lineSpacing: spacing - 6) { content }
  }
}

/// Wraps children onto new lines when they don't fit.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8
  var lineSpacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    var maxX: CGFloat = 0
    for view in subviews {
      let size = view.sizeThatFits(.unspecified)
      if x > 0 && x + size.width > width {
        x = 0
        y += lineHeight + lineSpacing
        lineHeight = 0
      }
      x += size.width + spacing
      maxX = max(maxX, x - spacing)
      lineHeight = max(lineHeight, size.height)
    }
    return CGSize(width: min(maxX, width), height: y + lineHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    // Lay out line by line, centring each item vertically in its line.
    var lines: [[(index: Int, size: CGSize)]] = [[]]
    var x: CGFloat = 0
    for (i, view) in subviews.enumerated() {
      let size = view.sizeThatFits(.unspecified)
      if x > 0 && x + size.width > bounds.width {
        lines.append([])
        x = 0
      }
      lines[lines.count - 1].append((i, size))
      x += size.width + spacing
    }
    var y = bounds.minY
    for line in lines {
      let height = line.map(\.size.height).max() ?? 0
      var x = bounds.minX
      for item in line {
        let point = CGPoint(x: x, y: y + (height - item.size.height) / 2)
        subviews[item.index].place(at: point, proposal: ProposedViewSize(item.size))
        x += item.size.width + spacing
      }
      y += height + lineSpacing
    }
  }
}

/// Provenance marker (spec 7.6). Never the only signal: callers also show text.
struct ProvenanceMarker: View {
  let status: Provenance
  var size: CGFloat = 8

  var body: some View {
    Group {
      switch status {
      case .sourced:
        Circle().fill(Color.sw.label)
      case .unverified, .unknown:
        Circle().strokeBorder(Color.sw.labelSecondary, lineWidth: 1.5)
      case .conflicting:
        ZStack {
          Circle().strokeBorder(Color.sw.label, lineWidth: 1.5)
          Circle().fill(Color.sw.label).mask(
            HStack(spacing: 0) {
              Rectangle()
              Color.clear
            })
        }
      }
    }
    .frame(width: size, height: size)
    .accessibilityLabel(status.accessibilityText)
  }
}

extension Provenance {
  var accessibilityText: String {
    switch self {
    case .sourced: "Sourced"
    case .unverified: "Not confirmed"
    case .conflicting: "Sources differ"
    case .unknown: "Not known"
    }
  }

  /// "Sourced", "Not confirmed" or "Sources differ" for the sources sheet.
  var label: String {
    switch self {
    case .sourced: "Sourced"
    case .unverified, .unknown: "Not confirmed"
    case .conflicting: "Sources differ"
    }
  }
}

/// A grouped box: the score box, explainer boxes, You cards.
struct GroupedBox<Content: View>: View {
  var radius: CGFloat = Radius.grouped
  var padding: CGFloat = 16
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
  }
}

/// A 40 pt icon tile with an SF Symbol.
struct IconTile: View {
  let systemImage: String
  var size: CGFloat = 40
  var background: Color = Color.sw.fill
  var foreground: Color = Color.sw.label

  var body: some View {
    Image(systemName: systemImage)
      .font(.body)
      .foregroundStyle(foreground)
      .frame(width: size, height: size)
      .background(background, in: RoundedRectangle(cornerRadius: Radius.iconTile, style: .continuous))
      .accessibilityHidden(true)
  }
}

/// Section title (Title 2 bold) with an optional subtitle.
struct SectionTitle: View {
  let title: String
  var subtitle: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.title2.bold())
        .foregroundStyle(Color.sw.label)
        .accessibilityAddTraits(.isHeader)
      if let subtitle {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(Color.sw.labelSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The small red kicker above sheet titles, e.g. "Explained simply".
struct Kicker: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(Color.sw.accent)
  }
}

/// The main red action button (Book tickets, Find this movie).
struct AccentButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .foregroundStyle(Color.sw.onAccent)
      .padding(.horizontal, 22)
      .frame(minHeight: 50)
      .background(Color.sw.accent, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(Motion.select, value: configuration.isPressed)
  }
}

/// Scales slightly while pressed, for big tappable cards.
struct PressableStyle: ButtonStyle {
  var scale: CGFloat = 0.975

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? scale : 1)
      .animation(Motion.select, value: configuration.isPressed)
  }
}

extension View {
  /// Debug only: `-debugScrollY 900` starts scroll views scrolled, for screenshots.
  func debugInitialScroll() -> some View { modifier(DebugScrollModifier()) }
}

private struct DebugScrollModifier: ViewModifier {
  @State private var position = ScrollPosition(edge: .top)

  func body(content: Content) -> some View {
    #if DEBUG
      let y = UserDefaults.standard.double(forKey: "debugScrollY")
      if y > 0 {
        content
          .scrollPosition($position)
          .task {
            try? await Task.sleep(for: .milliseconds(800))
            position.scrollTo(y: y)
          }
      } else {
        content
      }
    #else
      content
    #endif
  }
}
