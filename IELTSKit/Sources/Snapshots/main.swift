import AppKit
import SwiftUI
@testable import IELTSKit

// Renders the main screens to PNG files so the interface can be reviewed without Xcode:
//   swift run Snapshots <output folder>
// The Mac draws navigation bars and lists in its own style, so these are layout previews,
// not pixel-exact iPhone screenshots. The app icon is drawn exactly.

// Everything touches views, so it all runs on the main actor.
@MainActor func run() {
    let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "snapshots")
    try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    func write(_ rep: NSBitmapImageRep, _ name: String) {
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: output.appendingPathComponent(name + ".png"))
        print("wrote \(name).png")
    }

    func snapshot<V: View>(_ name: String, height: CGFloat = 852, dark: Bool = false, _ view: V) {
        let size = CGSize(width: 393, height: height)
        let root = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: root)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        window.orderBack(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        write(rep, name)
        window.close()
    }

    // Sample data: a learner a few weeks into preparation.
    let store = AppStore(persistent: false)
    store.profile.targetBand = 7.0
    store.profile.examDate = Calendar.current.date(byAdding: .day, value: 34, to: Date())
    store.profile.onboarded = true

    let essay = Array(repeating: "Although opinions differ, I believe that universities should balance employment and curiosity because both matter. However, peoples often think informations are enough.", count: 14).joined(separator: " ")
    let prediction = BandPrediction(overall: 6.6, task: 6.2, coherence: 6.8, lexical: 6.4, grammar: 5.9, truncated: false)
    let evaluation = LocalExaminer.buildWritingEvaluation(task: SeedContent.writingTask2[0], response: essay, prediction: prediction)

    func attempt(_ skill: Skill, _ title: String, _ band: Double, daysAgo: Double, evaluation: Evaluation? = nil, raw: Int? = nil) -> Attempt {
        Attempt(date: Date().addingTimeInterval(-daysAgo * 86400), skill: skill, title: title, prompt: title,
                response: evaluation == nil ? "" : essay, band: band, evaluation: evaluation, rawScore: raw, total: raw == nil ? nil : 12)
    }
    store.attempts = [
        attempt(.writing, "Writing Task 2", 6.5, daysAgo: 0.1, evaluation: evaluation),
        attempt(.reading, "The Clockmaker and the Sea", 7.0, daysAgo: 1, raw: 9),
        attempt(.speaking, "Speaking mock test", 6.0, daysAgo: 2),
        attempt(.listening, "Nature Reserve Welcome Talk", 7.5, daysAgo: 3, raw: 10),
        attempt(.writing, "Writing Task 1", 6.0, daysAgo: 5),
        attempt(.reading, "The Hidden Life of Urban Soil", 6.0, daysAgo: 8, raw: 7),
        attempt(.speaking, "Speaking mock test", 5.5, daysAgo: 10),
        attempt(.listening, "Pottery Course Enquiry", 6.5, daysAgo: 12, raw: 8),
        attempt(.writing, "Writing Task 2", 5.5, daysAgo: 14),
    ]

    func screen<V: View>(_ view: V) -> some View {
        NavigationStack { view }.environmentObject(store).tint(Theme.accent)
    }

    snapshot("01-home", screen(HomeScreen()))
    snapshot("02-home-dark", dark: true, screen(HomeScreen()))
    snapshot("03-practice", screen(PracticeScreen()))
    snapshot("04-writing-hub", screen(WritingHub()))
    snapshot("05-writing-editor", height: 1100, screen(WritingEditor(task: SeedContent.writingTask1[0])))
    snapshot("06-report", height: 1500, ScrollView { EvaluationView(evaluation: evaluation, color: Skill.writing.color).padding(16) }.screenBackground())
    snapshot("07-reading-passage", screen(ReadingTestView(test: SeedContent.readingLongitude)))
    snapshot("08-questions", height: 1300, ScrollView {
        QuestionsView(questions: Array(SeedContent.readingLongitude.questions.prefix(2)) + Array(SeedContent.readingLongitude.questions[5...5])
                        + Array(SeedContent.readingLongitude.questions[8...8]) + Array(SeedContent.listeningReserve.questions[7...7]),
                      answers: .constant([1: "FALSE", 6: "A", 8: "Behind the visitor centre"]), submitted: false, color: Skill.reading.color).padding(16)
    }.screenBackground())
    snapshot("09-questions-marked", height: 1300, ScrollView {
        VStack(spacing: 16) {
            ScoreSummary(correct: 9, total: 12, band: 7.0, color: Skill.reading.color)
            QuestionsView(questions: Array(SeedContent.readingLongitude.questions.prefix(2)) + Array(SeedContent.readingLongitude.questions[8...8]),
                          answers: .constant([1: "FALSE", 2: "FALSE", 9: "15"]), submitted: true, color: Skill.reading.color)
        }.padding(16)
    }.screenBackground())
    snapshot("10-listening", screen(ListeningTestView(test: SeedContent.listeningReserve)))
    snapshot("11-speaking-intro", screen(SpeakingTestView(script: SeedContent.speaking)))
    snapshot("12-speaking-live", height: 760, VStack(alignment: .leading, spacing: 16) {
        PartProgress(part: 2)
        CueCardView(card: SeedContent.speaking.cueCard)
        CountdownRing(remaining: 42, total: 60, symbol: "hourglass", color: .orange).frame(maxWidth: .infinity).cardStyle(padding: 20)
        Spacer()
    }.padding(16).screenBackground())
    snapshot("13-tutor", screen(TutorScreen()))
    snapshot("14-guide", screen(GuideDetail(article: Guide.articles[3])))
    snapshot("15-progress", screen(ProgressScreen()))
    snapshot("16-settings", screen(SettingsScreen()))
    snapshot("17-onboarding", height: 900, OnboardingView().environmentObject(store).tint(Theme.accent))
    snapshot("18-onboarding-dark", height: 900, dark: true, OnboardingView().environmentObject(store).tint(Theme.accent))

    // App icon, exact: 1024 × 1024, no transparency, square (iOS rounds the corners itself).
    let renderer = ImageRenderer(content: AppMark(size: 1024, rounded: false))
    renderer.scale = 1
    if let image = renderer.cgImage {
        write(NSBitmapImageRep(cgImage: image), "AppIcon-1024")
    }
}

MainActor.assumeIsolated { run() }
exit(0)
