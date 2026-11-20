import Models
import Scoring
import SwiftUI
import UIKit

/// Theatre for this movie (spec 5.4): see the hall and your view, trust the score, and book.
/// With no movie (from Saved theatres or a /screen/ link) it shows "Best for" instead.
struct TheatreView: View {
  let screen: Screen
  let film: Film?
  @Environment(AppModel.self) private var model
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var mode: StageMode = .hall
  @State private var row = 0
  @State private var interacted = false
  @State private var sheetCovers = false
  @State private var lastDrag: CGFloat = 0
  @State private var rowFeedback = 0

  /// Spec says 430. It is 470 so the whole hall fits between the top buttons and the hint (D-37).
  private let stageHeight: CGFloat = 470
  private let overlap: CGFloat = 30

  enum StageMode: String { case hall, seat }

  private var venue: Venue? { model.venue(for: screen) }
  private var ranking: [RankedScreen] { film.map { model.ranking(for: $0) } ?? [] }
  private var ranked: RankedScreen? { ranking.first { $0.screen.id == screen.id } }
  private var config: HallSceneConfig? { HallSceneConfig(screen: screen, film: film, dark: scheme == .dark) }
  private var geometry: HallGeometry { HallGeometry.forScreen(screen) }

  var body: some View {
    ZStack(alignment: .top) {
      stage
      ScrollView {
        VStack(spacing: 0) {
          stageControls
          TheatreSheet(screen: screen, film: film, ranked: ranked, total: ranking.count)
        }
      }
      .scrollIndicators(.hidden)
      // The soft band iOS draws under the top buttons is only needed once the sheet covers the
      // stage. Over the hall it just hides the top of it. iOS 27 needs this on the scroll view.
      .scrollEdgeEffectHidden(!sheetCovers, for: .top)
      .debugInitialScroll()
      .onScrollGeometryChange(for: CGFloat.self) {
        $0.contentOffset.y + $0.contentInsets.top
      } action: { _, y in
        let covers = y > stageHeight - overlap - 64
        if covers != sheetCovers { withAnimation(Motion.select) { sheetCovers = covers } }
        HallHost.shared.setVisible(y < stageHeight)
      }
    }
    .ignoresSafeArea(edges: .top)
    .background(Color.sw.background)
    .safeAreaInset(edge: .bottom, spacing: 0) { bookingBar }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text(venue?.name ?? screen.name)
          .font(.headline)
          .lineLimit(1)
          .opacity(sheetCovers ? 1 : 0)
      }
      ToolbarItemGroup(placement: .topBarTrailing) {
        ShareLink(item: DeepLink.theatre(screen.id, film: film?.id), message: Text(shareText)) {
          Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Share")
        Button {
          model.toggleSaved(screen.id)
        } label: {
          Image(systemName: model.isSaved(screen.id) ? "heart.fill" : "heart")
            .foregroundStyle(model.isSaved(screen.id) ? Color.sw.accent : Color.sw.label)
        }
        .accessibilityLabel(model.isSaved(screen.id) ? "Remove from saved" : "Save theatre")
      }
    }
    .sensoryFeedback(.selection, trigger: rowFeedback)
    .task(id: config?.thumbnailKey) { await buildScene() }
    .onAppear {
      HallHost.shared.onInteraction = { withAnimation(.easeOut(duration: 0.4)) { interacted = true } }
      HallHost.shared.setVisible(true)
    }
    .onDisappear { HallHost.shared.setVisible(false) }
  }

  private var shareText: String {
    let name = [venue?.name, screen.hall].compactMap { $0 }.joined(separator: " ")
    guard let film, let ranked else { return name }
    let angle = Int(geometry.angle(row: row, pictureWidth: ranked.parts.pictureW ?? 0).rounded())
    return String(
      localized:
        "\(film.title) at \(name): \(ranked.shown)/100. Row \(HallGeometry.letter(row: row)) fills \(angle)° of your view."
    )
  }

  // MARK: Stage

  private var stage: some View {
    ZStack {
      StageBackground()
      if let config {
        if HallHost.shared.useFallback {
          HallDrawing(config: config, row: mode == .seat ? row : nil)
            .padding(.top, 90)
            .padding(.bottom, 120)
        } else {
          HallWebView()
        }
      } else {
        NoHallSize()
      }
    }
    .frame(height: stageHeight)
    .frame(maxWidth: .infinity)
    .accessibilityElement()
    .accessibilityLabel(stageLabel)
    .accessibilityAdjustableAction { direction in
      guard mode == .seat else { return }
      switch direction {
      case .increment: selectRow(min(row + 1, geometry.rows - 1))
      case .decrement: selectRow(max(row - 1, 0))
      @unknown default: break
      }
    }
  }

  private var stageLabel: String {
    let name = [venue?.name, screen.hall].compactMap { $0 }.joined(separator: " ")
    let w = Copy.feet(screen.widthFt ?? 0)
    let h = Copy.feet(screen.heightFt ?? 0)
    if mode == .seat, let pw = config?.pictureW {
      let angle = Int(geometry.angle(row: row, pictureWidth: pw).rounded())
      let estimated = geometry.isEstimated ? String(localized: "Estimated view") : String(localized: "View")
      return String(
        localized:
          "\(estimated) from row \(HallGeometry.letter(row: row)). The picture fills \(angle) degrees of your view.")
    }
    return String(localized: "3D model of \(name). The screen is \(w) by \(h) feet.")
  }

  /// The controls over the stage. They sit in the scroll content, pinned in place, so the
  /// sheet slides over them. Dragging here turns the hall.
  private var stageControls: some View {
    ZStack {
      Color.clear
        .contentShape(Rectangle())
        .simultaneousGesture(
          DragGesture(minimumDistance: 4)
            .onChanged { value in
              guard mode == .hall else { return }
              let dx = value.translation.width - lastDrag
              lastDrag = value.translation.width
              HallHost.shared.rotate(dx)
            }
            .onEnded { _ in
              lastDrag = 0
              HallHost.shared.endGesture()
            }
        )
        .simultaneousGesture(
          MagnifyGesture()
            .onChanged { HallHost.shared.zoom($0.magnification) }
            .onEnded { _ in HallHost.shared.endGesture() }
        )
        .accessibilityHidden(true)

      VStack(spacing: 0) {
        if mode == .seat { readout.padding(.top, 108).transition(.opacity) }
        Spacer(minLength: 0)
        if config == nil {
          // No hall to turn or sit in when the size isn't published.
          EmptyView()
        } else if mode == .hall {
          Text("Drag to turn · the red figure is 6 ft tall")
            .font(.footnote)
            .foregroundStyle(Color.sw.labelSecondary)
            .opacity(interacted ? 0 : 1)
            .padding(.bottom, 14)
            .accessibilityHidden(true)
        } else {
          rowChips.padding(.bottom, 10).transition(.opacity)
        }
        segmented.padding(.bottom, 28 + overlap).opacity(config == nil ? 0 : 1)
          .allowsHitTesting(config != nil)
      }
    }
    .frame(height: stageHeight)
    .padding(.bottom, -overlap)
    .visualEffect { content, proxy in
      content.offset(y: max(0, -proxy.frame(in: .scrollView).minY))
    }
    .zIndex(0)
  }

  private var segmented: some View {
    HStack(spacing: 0) {
      segment(.hall, String(localized: "The hall"))
      segment(.seat, String(localized: "From your seat"))
    }
    .padding(3)
    .frame(width: 280)
    .swGlass(in: Capsule())
    .accessibilityElement(children: .contain)
    .accessibilityLabel("View")
  }

  private func segment(_ value: StageMode, _ title: String) -> some View {
    Button {
      setMode(value)
    } label: {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(mode == value ? Color.sw.label : Color.sw.labelSecondary)
        .frame(maxWidth: .infinity, minHeight: 34)
        .background {
          if mode == value {
            Capsule().fill(Color.sw.card).shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
          }
        }
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .frame(minHeight: Spacing.minHit)
    .accessibilityAddTraits(mode == value ? [.isSelected] : [])
  }

  private var readout: some View {
    let pw = config?.pictureW ?? 0
    let angle = geometry.angle(row: row, pictureWidth: pw)
    let distance = Int(geometry.distance(row: row).rounded())
    let feel = ViewFeel(angle: angle).label
    let detail =
      geometry.isEstimated
      ? String(localized: "\(feel) · about \(distance) ft from the screen · estimated")
      : String(localized: "\(feel) · about \(distance) ft from the screen")
    return Button {
      model.explain(.angle)
    } label: {
      VStack(spacing: 1) {
        Text("Row \(HallGeometry.letter(row: row)) · \(Int(angle.rounded()))° of your view")
          .font(.subheadline.bold())
          .monospacedDigit()
          .foregroundStyle(Color.sw.label)
        Text(detail)
          .font(.footnote)
          .foregroundStyle(Color.sw.labelSecondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .swGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: true)
    }
    .buttonStyle(.plain)
    .accessibilityHint("Explains the viewing angle")
  }

  private var rowChips: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        HStack(spacing: 6) {
          ForEach(0..<geometry.rows, id: \.self) { i in
            Button {
              selectRow(i)
            } label: {
              Text(HallGeometry.letter(row: i))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(i == row ? Color.sw.onAccent : Color.sw.label)
                .frame(width: 36, height: 36)
                .background {
                  if i == row { Circle().fill(Color.sw.accent) }
                }
                .swGlass(in: Circle())
                .frame(width: Spacing.minHit, height: Spacing.minHit)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .id(i)
            .accessibilityLabel("Row \(HallGeometry.letter(row: i))")
            .accessibilityAddTraits(i == row ? [.isSelected] : [])
          }
        }
        .padding(.horizontal, Spacing.margin - 4)
      }
      .scrollIndicators(.hidden)
      .onAppear { proxy.scrollTo(row, anchor: .center) }
      .onChange(of: row) { _, new in
        withAnimation(reduceMotion ? nil : Motion.select) { proxy.scrollTo(new, anchor: .center) }
      }
    }
  }

  // MARK: Behaviour

  /// The parts of the stage the hall must stay clear of: the status bar and top buttons at the
  /// top, and the sheet edge, the view switch and the hint at the bottom.
  private var stageInsets: (top: CGFloat, bottom: CGFloat) {
    let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
    return (top: (window?.safeAreaInsets.top ?? 59) + 52, bottom: overlap + 28 + 52 + 30)
  }

  private func buildScene() async {
    guard let config, !HallHost.shared.useFallback else { return }
    row = geometry.defaultRow(pictureWidth: config.pictureW)
    await HallHost.shared.buildLive(
      config, mode: mode.rawValue, row: row, reduceMotion: reduceMotion, insets: stageInsets)
    #if DEBUG
      if UserDefaults.standard.string(forKey: "debugStageMode") == "seat" {
        try? await Task.sleep(for: .seconds(1.2))
        setMode(.seat)
      }
    #endif
  }

  private func setMode(_ new: StageMode) {
    guard new != mode else { return }
    rowFeedback += 1
    withAnimation(Motion.select) { mode = new }
    if new == .seat, let pw = config?.pictureW, row == 0 {
      row = geometry.defaultRow(pictureWidth: pw)
    }
    HallHost.shared.setMode(new.rawValue, row: row)
  }

  private func selectRow(_ i: Int) {
    guard i != row else { return }
    row = i
    rowFeedback += 1
    HallHost.shared.setRow(i)
  }

  // MARK: Booking bar

  private var bookingBar: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 1) {
        Text(film?.title ?? String(localized: "No movie picked"))
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
          .foregroundStyle(Color.sw.label)
        Text([venue?.name, screen.hall].compactMap { $0 }.joined(separator: " · "))
          .font(.footnote)
          .lineLimit(1)
          .foregroundStyle(Color.sw.labelSecondary)
      }
      Spacer(minLength: 0)
      if let film {
        Button("Book tickets") { model.sheet = .book(filmID: film.id, screenID: screen.id) }
          .buttonStyle(AccentButtonStyle())
      } else {
        Button("Pick a movie") { model.showSearch = true }
          .buttonStyle(AccentButtonStyle())
      }
    }
    .padding(.horizontal, Spacing.margin)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background {
      Rectangle().fill(.clear).swGlass(in: Rectangle()).ignoresSafeArea(edges: .bottom)
    }
    .overlay(alignment: .top) { Rectangle().fill(Color.sw.separator).frame(height: 0.5) }
  }
}
