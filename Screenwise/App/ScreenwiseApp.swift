import SwiftUI

@main
struct ScreenwiseApp: App {
  @State private var model = AppModel()
  @AppStorage("appearance") private var appearance: Appearance = .system

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
        .preferredColorScheme(appearance.colorScheme)
        .onOpenURL { model.handle(url: $0) }
        .task {
          #if DEBUG
            // Debug only: `-openURL screenwise://...` opens a screen at launch, for screenshots.
            if let i = CommandLine.arguments.firstIndex(of: "-openURL"), i + 1 < CommandLine.arguments.count,
              let url = URL(string: CommandLine.arguments[i + 1])
            {
              model.handle(url: url)
            }
          #endif
          await model.refresh()
        }
    }
  }
}

/// One NavigationStack and no tab bar (spec 4.1). Sheets and Search hang off the root.
struct RootView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    @Bindable var model = model
    NavigationStack(path: $model.path) {
      HomeView()
        .navigationDestination(for: Route.self) { route in
          switch route {
          case .movie(let id):
            if let film = model.film(id) {
              if let ns = model.zoomNamespace, model.zoomSourceID == id {
                MovieView(film: film).navigationTransition(.zoom(sourceID: id, in: ns))
              } else {
                MovieView(film: film)
              }
            } else {
              MissingView()
            }
          case .theatre(let screenID, let filmID):
            if let screen = model.screen(screenID) {
              TheatreView(screen: screen, film: filmID.flatMap(model.film))
            } else {
              MissingView()
            }
          case .you:
            YouView()
          }
        }
    }
    .tint(Color.sw.label)
    .sheet(item: $model.sheet) { sheet in
      SheetHost(route: sheet)
    }
    .fullScreenCover(isPresented: $model.showSearch) {
      SearchView()
    }
    .overlay(alignment: .top) { ToastView() }
    .sensoryFeedback(.success, trigger: model.savedFeedback)
    .sensoryFeedback(.selection, trigger: model.removedFeedback)
    .task {
      HallPictures.lookup = { [model] id in model.film(id) }
      // Pre-warm the hall scene after the first frame, off the critical path (spec 10.2).
      try? await Task.sleep(for: .milliseconds(600))
      HallHost.shared.prewarm(scheme: scheme)
    }
    .onChange(of: scheme) { _, new in HallHost.shared.setTheme(dark: new == .dark) }
    .onChange(of: model.path) { _, path in
      if !path.contains(where: { if case .movie = $0 { true } else { false } }) { model.zoomSourceID = nil }
    }
  }
}

/// Routes a `SheetRoute` to its view.
struct SheetHost: View {
  let route: SheetRoute
  @Environment(AppModel.self) private var model

  var body: some View {
    Group {
      switch route {
      case .explainer(let term, let extra):
        ExplainerSheet(term: term, extra: extra)
          .presentationDetents([.medium, .large])
      case .book(let filmID, let screenID):
        if let film = model.film(filmID), let screen = model.screen(screenID) {
          BookTicketsSheet(film: film, screen: screen)
            .presentationDetents([.medium])
        }
      case .sources(let screenID):
        if let screen = model.screen(screenID) {
          SourcesSheet(screen: screen)
            .presentationDetents([.large])
        }
      case .allScreens:
        AllScreensSheet().presentationDetents([.large])
      case .cinemaTech:
        CinemaTechSheet().presentationDetents([.large])
      case .about:
        AboutSheet().presentationDetents([.large])
      case .city:
        CitySheet().presentationDetents([.height(280)])
      case .feedback(let draft):
        FeedbackSheet(draft: draft).presentationDetents([.large])
      }
    }
    .presentationCornerRadius(Radius.sheetTop)
    .presentationDragIndicator(.visible)
  }
}

struct MissingView: View {
  var body: some View {
    ContentUnavailableView(
      "Not found", systemImage: "questionmark.circle",
      description: Text("This page isn't available any more."))
  }
}
