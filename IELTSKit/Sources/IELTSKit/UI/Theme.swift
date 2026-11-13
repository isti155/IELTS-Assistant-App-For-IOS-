import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// One place for colours and shapes, so every screen looks like part of the same app.
/// All colours are system colours, so light mode, dark mode and high contrast work automatically.
enum Theme {
    static let accent = Color.indigo
    static let cornerRadius: CGFloat = 16

    static func color(for skill: Skill) -> Color {
        switch skill {
        case .listening: return .purple
        case .reading: return .teal
        case .writing: return .orange
        case .speaking: return .pink
        }
    }

    #if os(iOS)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let fill = Color(uiColor: .tertiarySystemFill)
    #else
    static let background = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let fill = Color.gray.opacity(0.14)
    #endif

    static let success = Color.green
    static let warning = Color.orange
    static let failure = Color.red
}

extension Skill {
    var color: Color { Theme.color(for: self) }

    var tagline: String {
        switch self {
        case .listening: return "Recordings with form, note and multiple-choice questions"
        case .reading: return "Academic passages with True/False/Not Given, matching and completion"
        case .writing: return "Task 1 reports and Task 2 essays, marked on your iPhone"
        case .speaking: return "A three-part mock test and a conversation partner"
        }
    }

    var format: String {
        switch self {
        case .listening: return "4 recordings · 40 questions · about 30 min"
        case .reading: return "3 passages · 40 questions · 60 min"
        case .writing: return "Task 1 (150 words) and Task 2 (250 words) · 60 min"
        case .speaking: return "3 parts · 11–14 min"
        }
    }
}

extension View {
    /// A rounded, grouped-style card, like the cells in the Health and Fitness apps.
    func cardStyle(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    /// The standard grey background behind cards and grouped lists.
    func screenBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }

    @ViewBuilder func groupedList() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.inset)
        #endif
    }

    @ViewBuilder func inlineTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Text field look used for typed answers.
    @ViewBuilder func answerField() -> some View {
        #if os(iOS)
        self.textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(12)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        #else
        self.textFieldStyle(.plain)
            .autocorrectionDisabled()
            .padding(12)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        #endif
    }

    @ViewBuilder func dismissKeyboardOnScroll() -> some View {
        #if os(iOS)
        self.scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }

    /// Full-width primary action, as used at the bottom of most screens.
    func primaryAction(_ color: Color = Theme.accent) -> some View {
        self.buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(color)
    }
}
