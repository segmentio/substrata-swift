// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Substrata",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Substrata",
            targets: ["Substrata"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SubstrataQuickJS"
            /*cSettings: [
                /*.unsafeFlags([
                    "-Wno-implicit-int-float-conversion",
                    "-Wno-conversion"
                ]),*/
                .define("CONFIG_BIGNUM"),
                .define("CONFIG_ATOMICS"),
                //.define("DUMP_LEAKS")
            ]*/
        ),
        .target(
            name: "Substrata", 
            dependencies: ["SubstrataQuickJS"]),
        .testTarget(
            name: "SubstrataTests",
            dependencies: ["Substrata"],
            resources: [
                .copy("Support/ConversionTestData.js")
            ])
    ]
)
