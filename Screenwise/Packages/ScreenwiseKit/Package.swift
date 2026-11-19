// swift-tools-version: 6.2
// Pure logic for Screenwise: data models, the Screen Score v2 and the hall maths.
// No UI imports, so `swift test` runs on the Mac without a simulator.
import PackageDescription

let package = Package(
  name: "ScreenwiseKit",
  platforms: [.iOS(.v26), .macOS(.v15)],
  products: [
    .library(name: "Models", targets: ["Models"]),
    .library(name: "Scoring", targets: ["Scoring"]),
  ],
  targets: [
    .target(name: "Models"),
    .target(name: "Scoring", dependencies: ["Models"]),
    .testTarget(name: "ModelsTests", dependencies: ["Models"]),
    .testTarget(name: "ScoringTests", dependencies: ["Scoring", "Models"]),
  ],
  swiftLanguageModes: [.v6]
)
