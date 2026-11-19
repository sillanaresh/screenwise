import Foundation
import Models

/// Hall geometry and viewing angles (spec 10.5). The readout uses this maths, never pixels.
public struct HallGeometry: Sendable, Hashable, Codable {
  public var rows: Int
  public var firstRowFt: Double
  public var rowPitchFt: Double
  /// Rise per row in feet.
  public var rakeFt: Double
  /// True when any part was estimated rather than published.
  public var isEstimated: Bool

  public init(rows: Int, firstRowFt: Double, rowPitchFt: Double, rakeFt: Double = 1.0, isEstimated: Bool) {
    self.rows = rows
    self.firstRowFt = firstRowFt
    self.rowPitchFt = rowPitchFt
    self.rakeFt = rakeFt
    self.isEstimated = isEstimated
  }

  /// Published geometry when the screen has it, otherwise the spec's estimate.
  public static func forScreen(_ screen: Screen) -> HallGeometry {
    let width = screen.widthFt ?? 60
    if let rows = screen.rowsCount, let first = screen.firstRowFt, let pitch = screen.rowPitchFt {
      return HallGeometry(rows: rows, firstRowFt: first, rowPitchFt: pitch, isEstimated: false)
    }
    return estimate(widthFt: width, seats: screen.seats, recliners: screen.recliners ?? false)
  }

  public static func estimate(widthFt: Double, seats: Int?, recliners: Bool) -> HallGeometry {
    let seatCount = Double(seats ?? 600)
    let rows = min(30, max(8, Int((seatCount / (widthFt * 0.42)).rounded())))
    return HallGeometry(
      rows: rows, firstRowFt: max(18, 0.32 * widthFt), rowPitchFt: recliners ? 5.0 : 3.6,
      isEstimated: true)
  }

  /// Distance from the screen to a row, in feet. Row 0 is the front row (A).
  public func distance(row: Int) -> Double {
    firstRowFt + Double(row) * rowPitchFt
  }

  /// Horizontal angle in degrees that a picture of this width covers from a row.
  public func angle(row: Int, pictureWidth: Double) -> Double {
    Self.angle(size: pictureWidth, distance: distance(row: row))
  }

  public static func angle(size: Double, distance: Double) -> Double {
    2 * atan((size / 2) / distance) * 180 / .pi
  }

  /// The row whose angle is nearest 60 degrees.
  public func defaultRow(pictureWidth: Double) -> Int {
    var best = 0
    var bestDiff = Double.infinity
    for row in 0..<rows {
      let diff = abs(angle(row: row, pictureWidth: pictureWidth) - 60)
      if diff < bestDiff {
        bestDiff = diff
        best = row
      }
    }
    return best
  }

  /// Rows are lettered from A at the front: A to Z, then AA, AB and so on.
  public static func letter(row: Int) -> String {
    let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    if row < 26 { return String(letters[row]) }
    return String(letters[row / 26 - 1]) + String(letters[row % 26])
  }
}

/// How a viewing angle feels. Product choices, not an industry standard (spec 10.5).
public enum ViewFeel: String, Sendable {
  case veryClose, immersive, balanced, relaxed

  public init(angle: Double, thresholds: Thresholds = .default) {
    if angle > thresholds.veryClose {
      self = .veryClose
    } else if angle >= thresholds.immersive {
      self = .immersive
    } else if angle >= thresholds.balanced {
      self = .balanced
    } else {
      self = .relaxed
    }
  }

  public struct Thresholds: Sendable, Hashable, Codable {
    public var veryClose: Double
    public var immersive: Double
    public var balanced: Double

    public static let `default` = Thresholds(veryClose: 80, immersive: 50, balanced: 40)
  }

  public var label: String {
    switch self {
    case .veryClose: "Very close"
    case .immersive: "Immersive"
    case .balanced: "Balanced"
    case .relaxed: "Relaxed"
    }
  }
}
