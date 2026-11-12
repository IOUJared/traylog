// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TrayLogCore",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(name: "TrayLogCore", targets: ["TrayLogCore"])
  ],
  targets: [
    .target(name: "TrayLogCore"),
    .testTarget(name: "TrayLogCoreTests", dependencies: ["TrayLogCore"]),
  ]
)
