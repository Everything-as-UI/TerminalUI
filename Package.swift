// swift-tools-version: 5.7

import PackageDescription

let dependencies: [Package.Dependency]

if Context.environment["ALLUI_ENV"] == "LOCAL" {
    dependencies = [
        .package(name: "CoreUI", path: "../CoreUI"),
    ]
} else {
    dependencies = [
        .package(url: "https://github.com/Everything-as-UI/CoreUI.git", branch: "main")
    ]
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
        .executableTarget(name: "TerminalUI",
                          dependencies: [
                            .product(name: "CoreUI", package: "CoreUI"),
                            "Curses"
                          ])
    ]
)
