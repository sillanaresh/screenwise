import Foundation
import Models
import Testing

@testable import Scoring

@Suite("Hall geometry and viewing angles")
struct HallMathTests {
  @Test func estimateFollowsSpec() {
    // Allu: 75 ft wide, 644 seats, no recliner data.
    let g = HallGeometry.estimate(widthFt: 75, seats: 644, recliners: false)
    #expect(g.rows == 20)  // round(644 / 31.5) = 20
    #expect(g.firstRowFt == 24)  // max(18, 0.32 * 75)
    #expect(g.rowPitchFt == 3.6)
    #expect(g.isEstimated)
  }

  @Test func estimateClampsRowsAndDefaultsSeats() {
    #expect(HallGeometry.estimate(widthFt: 30, seats: 40, recliners: false).rows == 8)
    #expect(HallGeometry.estimate(widthFt: 40, seats: 5000, recliners: false).rows == 30)
    #expect(HallGeometry.estimate(widthFt: 60, seats: nil, recliners: true).rows == 24)  // 600 seats
    #expect(HallGeometry.estimate(widthFt: 60, seats: nil, recliners: true).rowPitchFt == 5.0)
    #expect(HallGeometry.estimate(widthFt: 40, seats: 300, recliners: false).firstRowFt == 18)
  }

  @Test func angleMaths() {
    // A picture as wide as twice the distance covers 90 degrees.
    #expect(abs(HallGeometry.angle(size: 60, distance: 30) - 90) < 1e-9)
    let g = HallGeometry(rows: 10, firstRowFt: 20, rowPitchFt: 4, isEstimated: true)
    #expect(g.distance(row: 0) == 20)
    #expect(g.distance(row: 3) == 32)
    let expected = 2 * atan(37.5 / 32) * 180 / Double.pi
    #expect(abs(g.angle(row: 3, pictureWidth: 75) - expected) < 1e-9)
  }

  @Test func defaultRowIsNearestSixtyDegrees() {
    let g = HallGeometry.estimate(widthFt: 75, seats: 644, recliners: false)
    let row = g.defaultRow(pictureWidth: 75)
    let diff = abs(g.angle(row: row, pictureWidth: 75) - 60)
    for r in 0..<g.rows {
      #expect(diff <= abs(g.angle(row: r, pictureWidth: 75) - 60))
    }
  }

  @Test func feelLabels() {
    #expect(ViewFeel(angle: 81) == .veryClose)
    #expect(ViewFeel(angle: 80) == .immersive)
    #expect(ViewFeel(angle: 50) == .immersive)
    #expect(ViewFeel(angle: 49.9) == .balanced)
    #expect(ViewFeel(angle: 40) == .balanced)
    #expect(ViewFeel(angle: 39) == .relaxed)
  }

  @Test func rowLetters() {
    #expect(HallGeometry.letter(row: 0) == "A")
    #expect(HallGeometry.letter(row: 25) == "Z")
    #expect(HallGeometry.letter(row: 26) == "AA")
    #expect(HallGeometry.letter(row: 29) == "AD")
  }
}
