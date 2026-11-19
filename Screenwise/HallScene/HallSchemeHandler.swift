import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serves the bundled hall scene files and the movie pictures to the web view.
///
/// A custom scheme, rather than `loadFileURL`, because WebKit refuses ES module imports from
/// file URLs. Everything is local, so the scene needs no network (spec 10.2).
@MainActor
final class HallSchemeHandler: NSObject, WKURLSchemeHandler {
  static let scheme = "hallscene"

  private let root: URL? = Bundle.main.url(forResource: "HallScene", withExtension: nil)
  private var pictures: [String: Data] = [:]

  func hasPicture(_ filmID: String) -> Bool { pictures[filmID] != nil }
  func setPicture(_ data: Data, for filmID: String) { pictures[filmID] = data }

  func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
    guard let url = task.request.url else { return fail(task) }
    let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    if path.hasPrefix("picture/") {
      let id = String(path.dropFirst("picture/".count).dropLast(".jpg".count))
      guard let data = pictures[id] else { return fail(task) }
      return respond(task, url: url, data: data, mime: "image/jpeg")
    }

    guard let root, !path.contains(".."), let data = try? Data(contentsOf: root.appending(path: path)) else {
      return fail(task)
    }
    respond(task, url: url, data: data, mime: Self.mime(for: path))
  }

  func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}

  private func respond(_ task: any WKURLSchemeTask, url: URL, data: Data, mime: String) {
    let response = HTTPURLResponse(
      url: url, statusCode: 200, httpVersion: "HTTP/1.1",
      headerFields: [
        "Content-Type": mime, "Content-Length": "\(data.count)", "Access-Control-Allow-Origin": "*",
        "Cache-Control": "no-cache",
      ])!
    task.didReceive(response)
    task.didReceive(data)
    task.didFinish()
  }

  private func fail(_ task: any WKURLSchemeTask) {
    task.didFailWithError(URLError(.fileDoesNotExist))
  }

  static func mime(for path: String) -> String {
    switch (path as NSString).pathExtension {
    case "html": "text/html; charset=utf-8"
    case "js", "mjs": "text/javascript; charset=utf-8"
    case "json": "application/json"
    case "jpg", "jpeg": "image/jpeg"
    case "png": "image/png"
    default: "application/octet-stream"
    }
  }
}
