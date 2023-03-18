// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let dependencies: [Package.Dependency]

let env = Context.environment["USER"]
let isDevelop = env == "K-o-D-e-N"
if isDevelop {
    dependencies = [
        .package(name: "CoreUI", path: "../CoreUI"),
    ]
} else {
    dependencies = []
}

let package = Package(
    name: "TerminalUI",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "TerminalUI", targets: ["TerminalUI"])
    ],
    dependencies: dependencies,
    targets: [
        .systemLibrary(name: "Curses"),
        .executableTarget(name: "TerminalUI", dependencies: [.product(name: "CoreUI", package: "CoreUI"), "Curses"])
    ]
)
