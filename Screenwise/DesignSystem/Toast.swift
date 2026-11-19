import SwiftUI

/// A short message at the top, e.g. "Saved. Find it under You."
struct ToastView: View {
  @Environment(AppModel.self) private var model
  @State private var visible: ToastMessage?

  var body: some View {
    ZStack {
      if let toast = visible {
        Text(toast.text)
          .font(.subheadline)
          .foregroundStyle(Color.sw.label)
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .swGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          .padding(.horizontal, Spacing.barMargin)
          .padding(.top, 6)
          .transition(.move(edge: .top).combined(with: .opacity))
          .accessibilityAddTraits(.isStaticText)
          .id(toast.id)
      }
    }
    .animation(Motion.push, value: visible)
    .onChange(of: model.toast) { _, new in
      guard let new else { return }
      visible = new
      AccessibilityNotification.Announcement(new.text).post()
      Task {
        try? await Task.sleep(for: .seconds(2.2))
        if visible?.id == new.id { visible = nil }
      }
    }
  }
}
