import Models
import OSLog
import Scoring
import SwiftUI
import UIKit
import WebKit

/// Everything the hall scene needs for one screen and one movie (spec 10.2 `hallJSON`).
struct HallSceneConfig: Equatable {
  var screenID: String
  var filmID: String?
  var screenW: Double
  var screenH: Double
  var seats: Int?
  var geometry: HallGeometry
  var filmRatio: Double
  var pictureW: Double
  var pictureH: Double
  var tintHex: String
  var dark: Bool

  /// Bump when the scene code changes, so cached thumbnails are redrawn.
  static let sceneVersion = 1

  init?(screen: Screen, film: Film?, dark: Bool) {
    guard let w = screen.widthFt, let h = screen.heightFt else { return nil }
    screenID = screen.id
    filmID = film?.id
    screenW = w
    screenH = h
    seats = screen.seats
    geometry = HallGeometry.forScreen(screen)
    if let film {
      filmRatio = film.formats.scoringRatio
      let p = Scorer.picture(screenW: w, screenH: h, filmRatio: filmRatio)
      pictureW = p.w
      pictureH = p.h
      tintHex = film.tintHex ?? "#9FB7FF"
    } else {
      // Theatre without a movie: a neutral picture in the screen's own shape.
      filmRatio = w / h
      pictureW = w
      pictureH = h
      tintHex = "#B4BCCB"
    }
    self.dark = dark
  }

  var thumbnailKey: String {
    "\(screenID)_\(filmID ?? "none")_\(dark ? "d" : "l")_v\(Self.sceneVersion)"
  }

  /// `insets` are the points at the top and bottom of the live stage covered by the top bar and
  /// the controls. The hall is fitted into the band between them.
  func json(
    mode: String = "hall", row: Int = 0, reduceMotion: Bool = false, insets: (top: CGFloat, bottom: CGFloat) = (0, 0)
  ) -> [String: Any] {
    [
      "screen": ["w": screenW, "h": screenH, "seats": seats as Any? ?? NSNull()],
      "hall": [
        "rows": geometry.rows, "first": geometry.firstRowFt, "pitch": geometry.rowPitchFt,
        "rake": geometry.rakeFt,
      ],
      "film": ["ratio": filmRatio],
      "picture": [
        "w": pictureW, "h": pictureH, "tint": tintHex,
        "image": filmID.map { "picture/\($0).jpg" } ?? NSNull(),
      ],
      "theme": dark ? "dark" : "light",
      // The figure uses the accent token's value for each theme.
      "accent": dark ? "#FF6369" : "#D6363D",
      "reduceMotion": reduceMotion,
      "mode": mode,
      "row": row,
      "insets": ["top": insets.top, "bottom": insets.bottom],
    ]
  }
}

/// Owns the web views that render the hall scene (spec 10.2).
///
/// One interactive web view is pre-warmed after launch and reused by every Theatre page.
/// A second, hidden one renders card thumbnails one at a time.
@MainActor
final class HallHost: NSObject {
  static let shared = HallHost()
  private static let log = Logger(subsystem: "app.screenwise.ios", category: "hall")

  private let schemeHandler = HallSchemeHandler()
  private var live: SceneView?
  private var thumbs: SceneView?
  private var thumbTail: Task<UIImage?, Never>?
  private let memory = NSCache<NSString, UIImage>()

  /// Called when the user first touches the live scene.
  var onInteraction: (() -> Void)?
  /// True once WebGL has failed to start. Views then draw the 2D fallback.
  private(set) var webGLFailed = false

  var lowPower: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
  var useFallback: Bool { webGLFailed || lowPower }

  func prewarm(scheme: ColorScheme) {
    park(liveScene().webView)
    park(thumbScene().webView)
  }

  /// WebKit suspends web views that aren't in a window. While a scene isn't on screen it
  /// waits in a tiny, almost invisible holder inside the key window, so it stays warm.
  private var parking: UIView?

  /// Parks a web view. Without `force`, a web view that is on screen stays where it is.
  func park(_ webView: WKWebView, force: Bool = false) {
    guard let holder = parkingView() else { return }
    guard webView.superview !== holder else { return }
    if !force, webView.superview != nil { return }
    webView.removeFromSuperview()
    webView.translatesAutoresizingMaskIntoConstraints = true
    webView.frame = CGRect(x: 0, y: 0, width: 402, height: 430)
    holder.addSubview(webView)
  }

  private func parkingView() -> UIView? {
    if let parking, parking.window != nil { return parking }
    let window = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first
    guard let window else { return nil }
    let holder = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    holder.clipsToBounds = true
    holder.alpha = 0.02
    holder.isUserInteractionEnabled = false
    holder.accessibilityElementsHidden = true
    window.insertSubview(holder, at: 0)
    parking = holder
    return holder
  }

  // MARK: Live scene

  func liveScene() -> SceneView {
    if let live { return live }
    let scene = SceneView(handler: schemeHandler, thumbnail: false) { [weak self] message in
      self?.handle(message)
    }
    live = scene
    return scene
  }

  func buildLive(
    _ config: HallSceneConfig, mode: String, row: Int, reduceMotion: Bool,
    insets: (top: CGFloat, bottom: CGFloat) = (0, 0)
  ) async {
    let scene = liveScene()
    await preparePicture(for: config)
    do {
      let info = try await scene.call(
        "const r = await window.hall.build(config); r.size = [innerWidth, innerHeight]; return r;",
        ["config": config.json(mode: mode, row: row, reduceMotion: reduceMotion, insets: insets)])
      Self.log.debug(
        "live build \(config.screenID, privacy: .public): \(String(describing: info), privacy: .public), window: \(scene.webView.window != nil), frame: \(String(describing: scene.webView.frame), privacy: .public)"
      )
    } catch {
      Self.log.error("build failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  func setMode(_ mode: String, row: Int) {
    fire("window.hall.setMode(m, r)", ["m": mode, "r": row])
  }

  func setRow(_ row: Int) {
    fire("window.hall.setRow(r)", ["r": row])
  }

  func rotate(_ dx: Double) {
    fire("window.hall.rotate(dx)", ["dx": dx])
  }

  func zoom(_ scale: Double) {
    fire("window.hall.zoom(s)", ["s": scale])
  }

  func endGesture() {
    fire("window.hall.endGesture()", [:])
  }

  func setVisible(_ visible: Bool) {
    fire("window.hall.setVisible(v)", ["v": visible])
  }

  func setTheme(dark: Bool) {
    fire("return await window.hall.setTheme(t, a)", ["t": dark ? "dark" : "light", "a": dark ? "#FF6369" : "#D6363D"])
  }

  /// Calls the scene without waiting for a result.
  private func fire(_ js: String, _ arguments: [String: Any]) {
    let scene = liveScene()
    Task { @MainActor in _ = try? await scene.call(js, arguments) }
  }

  /// A PNG of the live scene, for the share card.
  func liveSnapshot() async -> UIImage? {
    guard let live else { return nil }
    let config = WKSnapshotConfiguration()
    return try? await live.webView.takeSnapshot(configuration: config)
  }

  private func handle(_ message: [String: Any]) {
    Self.log.debug("scene message: \(String(describing: message), privacy: .public)")
    switch message["type"] as? String {
    case "interactionStarted": onInteraction?()
    case "ready":
      if (message["webgl"] as? Bool) == false { webGLFailed = true }
    case "error":
      Self.log.error("scene: \(String(describing: message["message"]), privacy: .public)")
      if let text = message["message"] as? String, text.contains("WebGL") { webGLFailed = true }
    default: break
    }
  }

  // MARK: Thumbnails (spec 10.6)

  private func thumbScene() -> SceneView {
    if let thumbs { return thumbs }
    let scene = SceneView(handler: schemeHandler, thumbnail: true) { [weak self] message in
      self?.handle(message)
    }
    thumbs = scene
    return scene
  }

  /// The cached thumbnail, if there is one, without rendering.
  func cachedThumbnail(_ config: HallSceneConfig) -> UIImage? {
    let key = config.thumbnailKey as NSString
    if let image = memory.object(forKey: key) { return image }
    if let data = try? Data(contentsOf: Self.thumbURL(config.thumbnailKey)), let image = UIImage(data: data) {
      memory.setObject(image, forKey: key)
      return image
    }
    return nil
  }

  /// Renders The hall view at 960 × 600, one at a time, and caches it on disk.
  func thumbnail(_ config: HallSceneConfig) async -> UIImage? {
    if let cached = cachedThumbnail(config) { return cached }
    guard !useFallback else { return nil }
    let previous = thumbTail
    let task = Task<UIImage?, Never> { @MainActor in
      _ = await previous?.value
      if let cached = self.cachedThumbnail(config) { return cached }
      return await self.renderThumbnail(config)
    }
    thumbTail = task
    return await task.value
  }

  private func renderThumbnail(_ config: HallSceneConfig) async -> UIImage? {
    let scene = thumbScene()
    park(scene.webView)
    Self.log.debug("thumbnail start \(config.thumbnailKey, privacy: .public), parked: \(scene.webView.window != nil)")
    await preparePicture(for: config)
    do {
      let result = try await scene.call(
        "await window.hall.build(config); return window.hall.snapshot(960, 600);",
        ["config": config.json()])
      guard let url = result as? String, let comma = url.firstIndex(of: ","),
        let data = Data(base64Encoded: String(url[url.index(after: comma)...])),
        let image = UIImage(data: data)
      else { return nil }
      memory.setObject(image, forKey: config.thumbnailKey as NSString)
      Self.storeThumb(data, key: config.thumbnailKey)
      Self.log.debug("thumbnail done \(config.thumbnailKey, privacy: .public)")
      return image
    } catch {
      Self.log.error("thumbnail failed: \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }

  private static var thumbDir: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "hall-thumbs")
  }

  private static func thumbURL(_ key: String) -> URL { thumbDir.appending(path: "\(key).jpg") }

  /// Keeps up to 200 thumbnails, removing the oldest.
  private static func storeThumb(_ data: Data, key: String) {
    let fm = FileManager.default
    try? fm.createDirectory(at: thumbDir, withIntermediateDirectories: true)
    try? data.write(to: thumbURL(key), options: .atomic)
    guard
      let files = try? fm.contentsOfDirectory(
        at: thumbDir, includingPropertiesForKeys: [.contentModificationDateKey]), files.count > 200
    else { return }
    let sorted = files.sorted {
      let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return a < b
    }
    for file in sorted.prefix(files.count - 200) { try? fm.removeItem(at: file) }
  }

  // MARK: Movie pictures

  private func preparePicture(for config: HallSceneConfig) async {
    guard let filmID = config.filmID, !schemeHandler.hasPicture(filmID) else { return }
    guard let film = HallPictures.film(filmID) else { return }
    if let data = await HallPictures.jpeg(for: film) {
      schemeHandler.setPicture(data, for: filmID)
    }
  }
}

/// Provides the movie image shown on the hall's screen.
@MainActor
enum HallPictures {
  static var lookup: ((String) -> Film?)?

  static func film(_ id: String) -> Film? { lookup?(id) }

  /// The TMDB backdrop at w1280, or the generated artwork when there is none.
  static func jpeg(for film: Film) async -> Data? {
    if let path = film.backdropPath {
      let url = AppConfig.tmdbImageBase.appending(path: "w1280\(path)")
      if let (data, response) = try? await URLSession.shared.data(from: url),
        (response as? HTTPURLResponse)?.statusCode == 200
      {
        return data
      }
    }
    let renderer = ImageRenderer(content: GeneratedArt(film: film).frame(width: 1200, height: 700))
    renderer.scale = 1
    return renderer.uiImage?.jpegData(compressionQuality: 0.85)
  }
}

/// One WKWebView running hall.html, with a typed call helper.
@MainActor
final class SceneView: NSObject, WKScriptMessageHandler {
  let webView: WKWebView
  private var ready = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private let onMessage: ([String: Any]) -> Void

  init(handler: HallSchemeHandler, thumbnail: Bool, onMessage: @escaping ([String: Any]) -> Void) {
    self.onMessage = onMessage
    let config = WKWebViewConfiguration()
    config.setURLSchemeHandler(handler, forURLScheme: HallSchemeHandler.scheme)
    config.suppressesIncrementalRendering = true
    config.allowsInlineMediaPlayback = true
    config.dataDetectorTypes = []
    let controller = WKUserContentController()
    // Forward console output and unhandled errors to the app log.
    let bridge = """
      ['log','warn','error'].forEach(function (k) {
        var o = console[k];
        console[k] = function () {
          try { webkit.messageHandlers.hall.postMessage({ type: 'console', level: k,
            message: Array.prototype.map.call(arguments, String).join(' ') }); } catch (e) {}
          o.apply(console, arguments);
        };
      });
      window.addEventListener('unhandledrejection', function (e) {
        try { webkit.messageHandlers.hall.postMessage({ type: 'error', message: 'unhandled: ' + e.reason }); } catch (x) {}
      });
      """
    controller.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    config.userContentController = controller
    webView = WKWebView(
      frame: CGRect(x: 0, y: 0, width: thumbnail ? 2 : 402, height: thumbnail ? 2 : 430), configuration: config)
    super.init()
    controller.add(WeakMessageHandler(self), name: "hall")
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.bounces = false
    webView.scrollView.pinchGestureRecognizer?.isEnabled = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.allowsLinkPreview = false
    webView.isInspectable = true
    let query = thumbnail ? "?mode=thumbnail" : ""
    webView.load(URLRequest(url: URL(string: "\(HallSchemeHandler.scheme)://app/hall.html\(query)")!))
  }

  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let body = message.body as? [String: Any] else { return }
    if body["type"] as? String == "ready" {
      ready = true
      waiters.forEach { $0.resume() }
      waiters = []
    }
    onMessage(body)
  }

  private func waitUntilReady() async {
    if ready { return }
    await withCheckedContinuation { waiters.append($0) }
  }

  @discardableResult
  func call(_ js: String, _ arguments: [String: Any]) async throws -> Any? {
    await waitUntilReady()
    return try await webView.callAsyncJavaScript(js, arguments: arguments, in: nil, contentWorld: .page)
  }
}

/// Avoids a retain cycle between WKUserContentController and its handler.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
  weak var target: (any WKScriptMessageHandler)?
  init(_ target: any WKScriptMessageHandler) { self.target = target }

  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
    target?.userContentController(controller, didReceive: message)
  }
}
