// swift-tools-version:5.3

import PackageDescription

#if canImport(JavaScriptCore)
let targets: [Target] = [
    .target(name: "Substrata")
]
#elseif os(Windows)
// Windows iTunes installs JSC at: C:/Program Files/iTunes/JavaScriptCore.dll
// See also: https://pub.dev/packages/flutter_jscore#windows
let targets: [Target] = [
    .target(name: "Substrata", 
        linkerSettings: [
            .linkedLibrary("Kernel32", .when(platforms: [.windows])),
            .linkedLibrary("JavaScriptCore", .when(platforms: [.windows])),
            .linkedLibrary("CoreFoundation", .when(platforms: [.windows])),
            .linkedLibrary("WTF", .when(platforms: [.windows])),
            .linkedLibrary("ASL", .when(platforms: [.windows])),
        ])
]
#else // no native JavaScriptCore falls back to javascriptcoregtk
let targets: [Target] = [
    .systemLibrary(name: "CJavaScriptCore",
        pkgConfig: "javascriptcoregtk-4.0", 
        providers: [.apt(["libjavascriptcoregtk-4.0-dev"]), .yum(["webkit2gtk"])]),
    .target(name: "Substrata", dependencies: ["CJavaScriptCore"], cSettings: [.headerSearchPath("../CJavaScriptCore/header_maps")])
]
#endif

let package = Package(
    name: "Substrata",
    platforms: [
        .macOS("10.15"),
        .iOS("13.0"),
        .tvOS("11.0"),
    ],
    products: [
        .library(name: "Substrata", targets: ["Substrata"]),
    ],
    targets: targets + [
        .testTarget(
            name: "SubstrataTests",
            dependencies: ["Substrata"],
            resources: [
                .copy("TestHelpers/ConversionTestData.js"),
                .copy("TestHelpers/BundleTest.js")
            ])
    ]
)
