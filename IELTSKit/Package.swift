// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "IELTSKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "IELTSKit", targets: ["IELTSKit"]),
    ],
    targets: [
        // All app logic and UI. The Xcode app target is a thin shell around RootView.
        .target(
            name: "IELTSKit",
            resources: [
                // Produced by ml/scripts/prepare_data.py and ml/scripts/train_scorer.py.
                .copy("Resources/question_bank.json"),
                .copy("Resources/IELTSScorer.mlmodelc"),
                .copy("Resources/scorer_vocab.txt"),
                .copy("Resources/scorer_reference.json"),
                .copy("Resources/grammar.json"),
                .copy("Resources/vocabulary.json"),
                .copy("Resources/course.json"),
                .copy("Resources/reading_bank.json"),
                .copy("Resources/speaking_bank.json"),
                .copy("Resources/writing_bank.json"),
                .copy("Resources/Task1"),
                .copy("Resources/GrammarCourse"),
            ]
        ),
        // `swift run SelfCheck` — assertion-based checks that run without Xcode/XCTest.
        .executableTarget(name: "SelfCheck", dependencies: ["IELTSKit"]),
        // `swift run Snapshots <folder>` — renders the screens and the app icon to PNG files.
        .executableTarget(name: "Snapshots", dependencies: ["IELTSKit"]),
    ]
)
