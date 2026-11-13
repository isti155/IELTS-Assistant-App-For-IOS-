import Foundation

/// Deterministic band arithmetic. The AI never computes an overall band; it only
/// awards per-criterion bands, and everything else is calculated here.
public enum BandMath {
    /// Writing/Speaking task band: mean of the criterion bands, rounded DOWN to a half band
    /// (e.g. 7, 6, 7, 7 → 6.75 → 6.5).
    public static func taskBand(_ criteria: [Double]) -> Double {
        guard !criteria.isEmpty else { return 0 }
        let mean = criteria.reduce(0, +) / Double(criteria.count)
        return floor(mean * 2 + 1e-9) / 2
    }

    /// Overall test band: mean of the four skills, rounded to the nearest half band,
    /// with .25 rounding up to .5 and .75 rounding up to the next whole band.
    public static func overall(_ skills: [Double]) -> Double {
        guard !skills.isEmpty else { return 0 }
        let mean = skills.reduce(0, +) / Double(skills.count)
        return floor(mean * 2 + 0.5 + 1e-9) / 2
    }

    /// Writing band from the two tasks. Task 2 carries twice the weight of Task 1.
    /// IELTS does not publish the exact rounding; nearest half band is the usual convention.
    public static func writing(task1: Double, task2: Double) -> Double {
        overall([task1, task2, task2])
    }

    // Published approximate conversions for a 40-question paper. Real cut-offs move
    // by a mark or so between test versions.
    private static let listeningTable: [(Int, Double)] = [
        (39, 9), (37, 8.5), (35, 8), (32, 7.5), (30, 7), (26, 6.5), (23, 6),
        (18, 5.5), (16, 5), (13, 4.5), (10, 4), (8, 3.5), (6, 3), (4, 2.5), (2, 2), (1, 1),
    ]
    private static let academicReadingTable: [(Int, Double)] = [
        (39, 9), (37, 8.5), (35, 8), (33, 7.5), (30, 7), (27, 6.5), (23, 6),
        (19, 5.5), (15, 5), (13, 4.5), (10, 4), (8, 3.5), (6, 3), (4, 2.5), (2, 2), (1, 1),
    ]

    public static func listeningBand(raw: Int) -> Double { lookup(raw, listeningTable) }
    public static func academicReadingBand(raw: Int) -> Double { lookup(raw, academicReadingTable) }

    /// Scale a short practice set to the 40-mark paper. The result is only an estimate.
    public static func scaledRaw(correct: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(correct) * 40 / Double(total)).rounded())
    }

    private static func lookup(_ raw: Int, _ table: [(Int, Double)]) -> Double {
        for (minimum, band) in table where raw >= minimum { return band }
        return 0
    }
}

public enum Marking {
    /// Normalise an answer for comparison: case, punctuation, spacing and a leading article.
    public static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let kept = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        var words = String(kept).split(separator: " ").map(String.init)
        if let first = words.first, ["the", "a", "an"].contains(first), words.count > 1 {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    public static func isCorrect(_ response: String, for question: Question) -> Bool {
        let given = normalize(response)
        guard !given.isEmpty else { return false }
        return ([question.answer] + question.accepted).contains { normalize($0) == given }
    }

    public static func score(_ questions: [Question], answers: [Int: String]) -> Int {
        questions.filter { isCorrect(answers[$0.id] ?? "", for: $0) }.count
    }

    public static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }
}
