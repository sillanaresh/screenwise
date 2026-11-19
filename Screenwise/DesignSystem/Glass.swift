import SwiftUI

extension View {
  /// Liquid Glass for floating controls only (spec 7.8). Becomes solid `card` with
  /// Reduce Transparency or Increase Contrast.
  func swGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
    modifier(GlassModifier(shape: shape, interactive: interactive))
  }

  /// Glass over artwork: the same, but tinted dark so white text stays readable.
  func swGlassOnImage<S: Shape>(in shape: S) -> some View {
    modifier(GlassOnImageModifier(shape: shape))
  }
}

private struct GlassModifier<S: Shape>: ViewModifier {
  let shape: S
  let interactive: Bool
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast

  func body(content: Content) -> some View {
    if reduceTransparency || contrast == .increased {
      content.background(Color.sw.card, in: shape)
        .overlay(shape.stroke(Color.sw.separator, lineWidth: 0.5))
    } else {
      content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
    }
  }
}

private struct GlassOnImageModifier<S: Shape>: ViewModifier {
  let shape: S
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast

  func body(content: Content) -> some View {
    if reduceTransparency || contrast == .increased {
      content.background(Color.black.opacity(0.72), in: shape)
    } else {
      content.glassEffect(.regular.tint(.black.opacity(0.12)), in: shape)
    }
  }
}

/// A round glass button for use over images and the stage: 40 pt visible, 44 pt hit area.
struct GlassIconButton: View {
  let systemImage: String
  let label: LocalizedStringKey
  var tint: Color? = nil
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.body.weight(.semibold))
        .foregroundStyle(tint ?? Color.sw.label)
        .frame(width: 40, height: 40)
        .swGlass(in: Circle(), interactive: true)
        .frame(width: Spacing.minHit, height: Spacing.minHit)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}
