// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PomodoroApp",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PomodoroApp",
            path: "PomodoroApp",
            exclude: [
                "Info.plist",
                "PomodoroApp.entitlements",
            ],
            resources: [
                .process("Resources/"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "PomodoroAppTests",
            dependencies: ["PomodoroApp"],
            path: "PomodoroAppTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                ]),
            ]
        ),
    ]
)
