// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

let test = Context.environment["MOCKABLE_TEST"].flatMap(Bool.init) ?? false
let lint = Context.environment["MOCKABLE_LINT"].flatMap(Bool.init) ?? false
let doc = Context.environment["MOCKABLE_DOC"].flatMap(Bool.init) ?? false

func when<T>(_ condition: Bool, _ list: [T]) -> [T] { condition ? list : [] }

// xctest-dynamic-overlay was renamed to swift-issue-reporting. Both URLs declare an
// `IssueReporting` target and cannot coexist in one graph, and the Point-Free ecosystem
// only moves to the new URL from Swift 6.4 on, so follow the same split.
#if compiler(>=6.4)
let issueReportingPackage: Package.Dependency = .package(
    url: "https://github.com/pointfreeco/swift-issue-reporting", from: "2.1.0"
)
let issueReportingProduct: Target.Dependency = .product(
    name: "IssueReporting", package: "swift-issue-reporting"
)
#else
#if swift(>=6.0)
let xctestDynamicOverlayVersion: Range<Version> = "1.6.1"..<"2.0.0"
#else
let xctestDynamicOverlayVersion: Range<Version> = "1.6.1"..<"1.10.0"
#endif
let issueReportingPackage: Package.Dependency = .package(
    url: "https://github.com/pointfreeco/xctest-dynamic-overlay", xctestDynamicOverlayVersion
)
let issueReportingProduct: Target.Dependency = .product(
    name: "IssueReporting", package: "xctest-dynamic-overlay"
)
#endif

let devDependencies: [Package.Dependency] = when(test, [
    .package(url: "https://github.com/pointfreeco/swift-macro-testing", exact: "0.6.4")
]) + when(lint, [
    .package(url: "https://github.com/realm/SwiftLint", exact: "0.57.1"),
]) + when(doc, [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
])

let devPlugins: [Target.PluginUsage] = when(lint, [
    .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")
])

let devTargets: [Target] = when(test, [
    .testTarget(
        name: "MockableTests",
        dependencies: ["Mockable"],
        swiftSettings: [
            .define("MOCKING"),
            .enableExperimentalFeature("StrictConcurrency"),
            .enableUpcomingFeature("ExistentialAny")
        ],
        plugins: devPlugins
    ),
    .testTarget(
        name: "MockableMacroTests",
        dependencies: [
            "MockableMacro",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            .product(name: "MacroTesting", package: "swift-macro-testing"),
        ],
        swiftSettings: [.define("MOCKING")]
    )
])

let package = Package(
    name: "Mockable",
    platforms: [.macOS(.v12), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "Mockable",
            targets: ["Mockable"]
        )
    ],
    dependencies: devDependencies + [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.0.0"..<"604.0.0"),
        // xctest-dynamic-overlay 1.10.0 switched to `public import Foundation`, which Swift <6
        // rejects when mixed with plain `import Foundation` in the same target.
        issueReportingPackage
    ],
    targets: devTargets + [
        .target(
            name: "Mockable",
            dependencies: [
                "MockableMacro",
                issueReportingProduct
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ],
            plugins: devPlugins
        ),
        .macro(
            name: "MockableMacro",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ],
            plugins: devPlugins
        )
    ],
    swiftLanguageVersions: [.v5, .version("6")]
)

