// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rc2AppServer",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "Rc2AppServer", targets: ["Rc2AppServer", "servermodel"]),
        .library(name: "servermodel", targets: ["servermodel"]),
        .executable(name: "appserver", targets: ["appserver", "Rc2AppServer"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(path: "../MJLLogger"),
        .package(path: "../Freddy"),
//		.package(url: "https://github.com/mlilback/MJLLogger.git", .revision("c79a790")),
//		.package(url: "https://github.com/bignerdranch/Freddy.git", from: "3.0.2"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", from: "3.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-WebSockets.git", from: "3.0.0"),
		.package(url: "https://github.com/PerfectlySoft/PerfectLib.git", from: "3.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-HTTP.git", from: "3.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-Zip.git", from: "3.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-CURL.git", from: "3.0.0"),
//		.package(url: "https://github.com/PerfectlySoft/Perfect-Crypto.git", from: "3.0.0"),
//		.package(url: "https://github.com/PerfectlySoft/Perfect-CZlib-src.git", from: "0.0.1"),
		.package(url: "https://github.com/mlilback/postgresql.git", .revision("dae1219")),
		.package(url: "https://github.com/vapor/node.git", from: "2.1.1"),
        .package(path: "../appmodel"),
//		.package(url: "https://github.com/rc2server/appModelSwift.git", from: "0.1.1"),
		.package(url: "https://github.com/IBM-Swift/BlueSignals.git", from: "1.0.0"),
		.package(url: "https://github.com/rc2server/CommandLine.git", .revision("f15b41a")),
//        .package(url: "https://github.com/Thomvis/BrightFutures.git", from: "6.0.1"),
        .package(path: "../BrightFutures"),
        .package(url: "https://github.com/stencilproject/Stencil.git", from: "0.11.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "appserver",
            dependencies: ["Rc2AppServer"]),
        .target(
            name: "Rc2AppServer",
            dependencies: ["Freddy", "BrightFutures", "Stencil", "PerfectLib", "PerfectCURL", "PerfectHTTP", "PerfectHTTPServer", "PerfectWebSockets", "PerfectZip", "servermodel", "CommandLine", "Rc2Model", "Signals", "MJLLogger"]),
        .target(
        	name: "servermodel",
        	dependencies: ["Freddy", "Node", "PostgreSQL", "Rc2Model"]),
        .testTarget(
            name: "Rc2AppServerTests",
            dependencies: ["Rc2AppServer"]),
        .testTarget(
        	name: "servermodelTests",
        	dependencies: ["servermodel"]),
    ]
)
