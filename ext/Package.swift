// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "audiotee",
  platforms: [
    .macOS("14.2")
  ],
  products: [
    // Library that can be imported by other packages
    .library(
      name: "AudioTeeCore",
      targets: ["AudioTeeCore"]
    ),
    // Static library product producing libAudioTee.a
    .library(
      name: "AudioTee",
      type: .static,
      targets: ["AudioTee"]
    ),
  ],
  targets: [
    // Core library with all business logic
    .target(
      name: "AudioTeeCore",
      path: "AudioTeeCore"
    ),
    .target(
      name: "AudioTee",
      dependencies: ["AudioTeeCore"],
      path: "AudioTee"
    ),
  ]
)
