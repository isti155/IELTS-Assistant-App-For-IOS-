import Charts
import SwiftUI

func bandText(_ band: Double) -> String {
    String(format: "%.1f", band)
}

/// Inline markdown (bold, italics, code) while keeping line breaks.
func markdown(_ text: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
}

// MARK: - Icons and marks

/// A white symbol on a coloured rounded square, as in the Settings app.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct SkillIcon: View {
    let skill: Skill
    var size: CGFloat = 30

    var body: some View {
        IconTile(symbol: skill.symbol, color: skill.color, size: size)
    }
}

/// The app's mark: a nearly closed ring around rising bars. Drawn with shapes only,
/// so it can also be rendered as the app icon.
struct AppMark: View {
    var size: CGFloat = 88
    /// The app icon is full-bleed (iOS applies the corner mask); in-app the mark is rounded.
    var rounded = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.33, blue: 0.93), Color(red: 0.56, green: 0.28, blue: 0.91)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle()
                .trim(from: 0, to: 0.8)
                .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.072, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.62, height: size * 0.62)
            HStack(alignment: .bottom, spacing: size * 0.045) {
                ForEach([0.15, 0.24, 0.33], id: \.self) { height in
                    RoundedRectangle(cornerRadius: size * 0.022, style: .continuous)
                        .fill(Color.white)
                        .frame(width: size * 0.075, height: size * height)
                }
            }
            .offset(y: size * 0.025)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: rounded ? size * 0.225 : 0, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Bands

/// Circular gauge filled to band / 9, with an optional tick at the target band.
struct BandRing: View {
    let band: Double?
    var target: Double?
    var color: Color = Theme.accent
    var size: CGFloat = 96
    var lineWidth: CGFloat = 10
    var caption: String?

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat((band ?? 0) / 9))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let target {
                Capsule()
                    .fill(Color.primary.opacity(0.65))
                    .frame(width: 3, height: lineWidth + 6)
                    .offset(y: -size / 2 + lineWidth / 2)
                    .rotationEffect(.degrees(target / 9 * 360))
            }
            VStack(spacing: 0) {
                Text(band.map(bandText) ?? "–")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(band == nil ? Color.secondary : Color.primary)
                if let caption {
                    Text(caption)
                        .font(.system(size: max(10, size * 0.115), weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption ?? "Band") \(band.map(bandText) ?? "not available")")
    }
}

/// Horizontal bar filled to band / 9, with an optional target tick.
struct BandBar: View {
    let band: Double?
    var target: Double?
    var color: Color = Theme.accent

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.16))
                Capsule()
                    .fill(color.gradient)
                    .frame(width: geometry.size.width * CGFloat((band ?? 0) / 9))
                if let target {
                    Capsule()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 2, height: geometry.size.height + 6)
                        .offset(x: geometry.size.width * CGFloat(target / 9) - 1)
                }
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

struct BandPill: View {
    let band: Double
    var color: Color = Theme.accent

    var body: some View {
        Text(bandText(band))
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .accessibilityLabel("Band \(bandText(band))")
    }
}

struct Tag: View {
    let text: String
    var symbol: String?
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Layout pieces

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.weight(.bold))
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }
}

/// Bar pinned to the bottom of a screen for its main action.
struct ActionBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) { content }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .background(.bar)
    }
}

/// A row with an icon tile, title, subtitle and optional trailing content.
struct RowLabel<Trailing: View>: View {
    let title: String
    var subtitle: String?
    let icon: IconTile
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).foregroundStyle(.primary).lineLimit(2)
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

extension RowLabel where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, icon: IconTile) {
        self.init(title: title, subtitle: subtitle, icon: icon) { EmptyView() }
    }
}

struct ErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Theme.failure)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BusyCard: View {
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(label).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 20)
    }
}

/// Counts down from `minutes` starting at `start`; turns red when time is up.
struct TimerLabel: View {
    let start: Date
    let minutes: Int

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            let remaining = minutes * 60 - Int(context.date.timeIntervalSince(start))
            let shown = abs(remaining)
            Label(String(format: "%@%d:%02d", remaining < 0 ? "+" : "", shown / 60, shown % 60), systemImage: "timer")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(remaining < 0 ? Theme.failure : Color.primary)
        }
    }
}

// MARK: - Writing Task 1 visual

struct ChartSpecView: View {
    let spec: ChartSpec

    private struct Point: Identifiable {
        let id: String
        let series: String
        let category: String
        let value: Double
    }

    private var points: [Point] {
        spec.series.flatMap { series in
            zip(spec.categories, series.values).map { category, value in
                Point(id: series.name + "|" + category, series: series.name, category: category, value: value)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(spec.title).font(.subheadline.weight(.semibold))
            switch spec.kind {
            case "line": lineChart
            case "pie": pieChart
            case "table": EmptyView()
            default: barChart
            }
            table
            Text("\(spec.xLabel) · \(spec.yLabel)").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var barChart: some View {
        Chart(points) { point in
            BarMark(x: .value(spec.xLabel, point.category), y: .value(spec.yLabel, point.value))
                .foregroundStyle(by: .value("Series", point.series))
                .position(by: .value("Series", point.series))
                .cornerRadius(3)
        }
        .frame(height: 220)
    }

    private var lineChart: some View {
        Chart(points) { point in
            LineMark(x: .value(spec.xLabel, point.category), y: .value(spec.yLabel, point.value))
                .foregroundStyle(by: .value("Series", point.series))
                .interpolationMethod(.monotone)
            PointMark(x: .value(spec.xLabel, point.category), y: .value(spec.yLabel, point.value))
                .foregroundStyle(by: .value("Series", point.series))
        }
        .frame(height: 220)
    }

    private var pieChart: some View {
        Chart(points.filter { $0.series == spec.series.first?.name }) { point in
            SectorMark(angle: .value(spec.yLabel, point.value), innerRadius: .ratio(0.5), angularInset: 1.5)
                .foregroundStyle(by: .value(spec.xLabel, point.category))
                .cornerRadius(3)
        }
        .frame(height: 220)
    }

    /// The exact figures, so the candidate can quote data accurately.
    private var table: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    ForEach(spec.categories, id: \.self) { Text($0).fontWeight(.semibold) }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(spec.series, id: \.name) { series in
                    GridRow {
                        Text(series.name).fontWeight(.semibold)
                        ForEach(Array(series.values.enumerated()), id: \.offset) { _, value in
                            Text(value.formatted())
                        }
                    }
                }
            }
            .font(.caption)
            .monospacedDigit()
            .padding(10)
        }
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Examiner report

struct EvaluationView: View {
    let evaluation: Evaluation
    var color: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                BandRing(band: evaluation.band, color: color, size: 104, lineWidth: 11, caption: "Band")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Estimated band").font(.headline)
                    Text(evaluation.summary).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 4) {
                Text("Criteria").font(.headline).padding(.bottom, 6)
                ForEach(Array(evaluation.criteria.enumerated()), id: \.element.id) { index, criterion in
                    if index > 0 { Divider().padding(.vertical, 6) }
                    CriterionRow(criterion: criterion, color: color)
                }
            }
            .cardStyle()

            feedbackList("What went well", evaluation.strengths, symbol: "checkmark.circle.fill", tint: Theme.success)
            feedbackList("How to raise your band", evaluation.improvements, symbol: "arrow.up.circle.fill", tint: Theme.warning)

            if !evaluation.corrections.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Corrections").font(.headline)
                    ForEach(Array(evaluation.corrections.enumerated()), id: \.offset) { index, item in
                        if index > 0 { Divider() }
                        CorrectionRow(correction: item)
                    }
                }
                .cardStyle()
            }

            if !evaluation.caveats.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("About this score", systemImage: "info.circle").font(.subheadline.weight(.semibold))
                    ForEach(evaluation.caveats, id: \.self) { caveat in
                        Text(caveat).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .cardStyle()
            }
        }
    }

    @ViewBuilder private func feedbackList(_ title: String, _ items: [String], symbol: String, tint: Color) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.headline)
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: symbol).foregroundStyle(tint)
                        Text(item).font(.subheadline)
                    }
                }
            }
            .cardStyle()
        }
    }
}

struct CriterionRow: View {
    let criterion: CriterionScore
    let color: Color
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(criterion.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Spacer()
                        Text("\(Int(criterion.band))")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(color)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                    BandBar(band: criterion.band, color: color)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(criterion.name), band \(Int(criterion.band))")
            .accessibilityHint(expanded ? "Hides details" : "Shows details")

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text(criterion.justification).font(.subheadline)
                    ForEach(criterion.evidence, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("•").foregroundStyle(.secondary)
                            Text(item).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

struct CorrectionRow: View {
    let correction: Correction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(correction.original)
                    .strikethrough(color: Theme.failure)
                    .foregroundStyle(Theme.failure)
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                Text(correction.corrected)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.success)
            }
            .font(.subheadline)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Tag(text: correction.category.capitalized)
                Text(correction.explanation).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Questions (Reading and Listening)

struct QuestionsView: View {
    let questions: [Question]
    @Binding var answers: [Int: String]
    let submitted: Bool
    var color: Color = Theme.accent

    /// Consecutive questions of the same type, as the test groups them.
    private var groups: [[Question]] {
        var result: [[Question]] = []
        for question in questions {
            if let last = result.last?.last, last.kind == question.kind {
                result[result.count - 1].append(question)
            } else {
                result.append([question])
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(groups, id: \.first!.id) { group in
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(range(of: group)).font(.headline)
                        Text(instructions(for: group[0].kind)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                    ForEach(group) { question in
                        QuestionCard(question: question, answer: binding(for: question.id), submitted: submitted, color: color)
                    }
                }
            }
        }
    }

    private func range(of group: [Question]) -> String {
        guard let first = group.first?.id, let last = group.last?.id else { return "" }
        return first == last ? "Question \(first)" : "Questions \(first)–\(last)"
    }

    private func instructions(for kind: String) -> String {
        switch kind {
        case "true_false_not_given":
            return "Do the statements agree with the information in the passage? Choose TRUE, FALSE or NOT GIVEN."
        case "matching":
            return "Which paragraph contains the following information?"
        case "multiple_choice":
            return "Choose the correct answer."
        default:
            return "Complete the gaps. Keep to the word limit given."
        }
    }

    private func binding(for id: Int) -> Binding<String> {
        Binding(get: { answers[id] ?? "" }, set: { answers[id] = $0 })
    }
}

struct QuestionCard: View {
    let question: Question
    @Binding var answer: String
    let submitted: Bool
    let color: Color

    private var isCorrect: Bool { Marking.isCorrect(answer, for: question) }
    private var resultColor: Color { isCorrect ? Theme.success : Theme.failure }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(question.id)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(submitted ? Color.white : color)
                    .frame(width: 28, height: 28)
                    .background(submitted ? resultColor : color.opacity(0.14), in: Circle())
                Text(question.prompt)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
            }
            options
            if submitted { result }
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(submitted ? resultColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }

    @ViewBuilder private var options: some View {
        if question.options.isEmpty {
            TextField("Type your answer", text: $answer)
                .answerField()
                .disabled(submitted)
        } else if question.options.allSatisfy({ $0.count <= 10 }) {
            HStack(spacing: 8) {
                ForEach(question.options, id: \.self) { option in
                    Button {
                        answer = option
                    } label: {
                        Text(option)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(minWidth: 40, minHeight: 36)
                            .foregroundStyle(chipForeground(option))
                            .background(chipBackground(option), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(submitted)
                    .accessibilityAddTraits(answer == option ? .isSelected : [])
                }
            }
        } else {
            VStack(spacing: 8) {
                ForEach(question.options, id: \.self) { option in
                    Button {
                        answer = option
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: answer == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(answer == option ? chipBackground(option) : Color.secondary)
                                .font(.title3)
                            Text(option).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(answer == option ? chipBackground(option).opacity(0.12) : Theme.fill)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(submitted)
                    .accessibilityAddTraits(answer == option ? .isSelected : [])
                }
            }
        }
    }

    private func chipBackground(_ option: String) -> Color {
        if submitted {
            if option == question.answer { return Theme.success }
            if option == answer { return Theme.failure }
            return Theme.fill
        }
        return answer == option ? color : Theme.fill
    }

    private func chipForeground(_ option: String) -> Color {
        if submitted { return option == question.answer || option == answer ? .white : .secondary }
        return answer == option ? .white : .primary
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(isCorrect ? "Correct" : "Answer: \(question.answer)",
                  systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(resultColor)
            Text(question.explanation).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// Score summary for Reading and Listening practice sets.
struct ScoreSummary: View {
    let correct: Int
    let total: Int
    let band: Double
    var color: Color = Theme.accent

    var body: some View {
        HStack(spacing: 18) {
            BandRing(band: band, color: color, size: 84, lineWidth: 9, caption: "Band")
            VStack(alignment: .leading, spacing: 4) {
                Text("\(correct) of \(total) correct").font(.title3.weight(.bold))
                Text("Scaled to the 40-question paper, so treat the band as a rough guide.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }
}

// MARK: - Text and chat

/// Renders a guide body: paragraphs, "- " bullets and "1. " numbered steps, with inline markdown.
struct GuideText: View {
    let text: String

    private enum Block: Hashable {
        case paragraph(String)
        case bullet(String)
        case step(String, String)
    }

    private var blocks: [Block] {
        text.components(separatedBy: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { return nil }
            if line.hasPrefix("- ") { return .bullet(String(line.dropFirst(2))) }
            if let dot = line.firstIndex(of: "."), line[..<dot].allSatisfy(\.isNumber), !line[..<dot].isEmpty,
               line.index(after: dot) < line.endIndex, line[line.index(after: dot)] == " " {
                return .step(String(line[..<dot]), String(line[line.index(dot, offsetBy: 2)...]))
            }
            return .paragraph(line)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let line):
                    Text(markdown(line))
                case .bullet(let line):
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle().fill(Theme.accent).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                        Text(markdown(line))
                    }
                case .step(let number, let line):
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(number).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent).frame(width: 18)
                        Text(markdown(line))
                    }
                }
            }
        }
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ChatBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            Text(markdown(text.isEmpty ? "…" : text))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .background(
                    isUser ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(Theme.card),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .textSelection(.enabled)
            if !isUser { Spacer(minLength: 48) }
        }
    }
}
