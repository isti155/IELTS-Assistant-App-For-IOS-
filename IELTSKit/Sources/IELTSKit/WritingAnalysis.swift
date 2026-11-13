import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Deterministic measurements of an essay. These explain the trained model's band
/// with facts about the candidate's own text, and supply concrete corrections.
public struct WritingAnalysis {
    public let words: Int
    public let paragraphs: Int
    public let sentences: [String]
    public let averageSentenceLength: Double
    /// Share of sentences containing a subordinating or relative structure.
    public let complexShare: Double
    /// Moving-average type–token ratio over 50-word windows (vocabulary variety, 0–1).
    public let lexicalVariety: Double
    public let linkersUsed: [String: Int]
    public let overusedLinkers: [String]
    public let repeatedWords: [(word: String, count: Int)]
    public let informalItems: [String]
    public let hasOverview: Bool
    public let hasOpinion: Bool
    public let hasConclusion: Bool
    public let figureCount: Int
    public let corrections: [Correction]

    static let linkers = [
        "however", "moreover", "furthermore", "in addition", "therefore", "consequently", "as a result",
        "for example", "for instance", "on the other hand", "in contrast", "whereas", "while", "although",
        "even though", "despite", "nevertheless", "nonetheless", "firstly", "secondly", "finally",
        "in conclusion", "to conclude", "to sum up", "overall", "similarly", "likewise", "thus", "hence",
        "in particular", "such as", "because", "since", "so that", "in other words", "by contrast", "meanwhile",
    ]
    static let subordinators: Set<String> = [
        "because", "although", "though", "while", "whereas", "which", "who", "whom", "whose", "that", "if",
        "unless", "since", "when", "whenever", "where", "after", "before", "until", "despite", "once",
    ]
    static let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "at", "for", "with", "by", "from", "as",
        "is", "are", "was", "were", "be", "been", "being", "it", "its", "this", "that", "these", "those", "they",
        "their", "them", "there", "have", "has", "had", "not", "can", "could", "will", "would", "should", "may",
        "might", "do", "does", "did", "more", "most", "than", "also", "such", "which", "who", "what", "when",
        "where", "how", "if", "so", "some", "many", "much", "other", "one", "two", "people", "i", "we", "you",
        "he", "she", "my", "our", "your", "his", "her", "all", "any", "about", "into", "over", "between", "while",
        "because", "however", "very", "only", "just", "both", "each", "no", "nor", "up", "out", "then", "them",
    ]
    static let informal = [
        "kids", "a lot of", "lots of", "stuff", "gonna", "wanna", "kind of", "sort of", "nowadays people",
        "etc", "and so on", "guys", "really really", "big problem", "things like that", "you know",
    ]

    /// Frequent learner errors: pattern, replacement, explanation.
    static let errorPatterns: [(String, String, String, String)] = [
        (#"\binformations\b"#, "information", "'Information' is uncountable.", "grammar"),
        (#"\badvices\b"#, "advice", "'Advice' is uncountable.", "grammar"),
        (#"\bknowledges\b"#, "knowledge", "'Knowledge' is uncountable.", "grammar"),
        (#"\bequipments\b"#, "equipment", "'Equipment' is uncountable.", "grammar"),
        (#"\bfurnitures\b"#, "furniture", "'Furniture' is uncountable.", "grammar"),
        (#"\bresearches\b"#, "research / studies", "'Research' is normally uncountable.", "grammar"),
        (#"\bhomeworks\b"#, "homework", "'Homework' is uncountable.", "grammar"),
        (#"\bevidences\b"#, "evidence", "'Evidence' is uncountable.", "grammar"),
        (#"\bpeoples\b"#, "people", "'People' is already plural.", "grammar"),
        (#"\bchildrens\b"#, "children", "'Children' is already plural.", "grammar"),
        (#"\bmore better\b"#, "better", "Do not use 'more' with a comparative adjective.", "grammar"),
        (#"\bmore easier\b"#, "easier", "Do not use 'more' with a comparative adjective.", "grammar"),
        (#"\bdiscuss about\b"#, "discuss", "'Discuss' takes a direct object.", "grammar"),
        (#"\bemphasi[sz]e on\b"#, "emphasise", "'Emphasise' takes a direct object.", "grammar"),
        (#"\bdespite of\b"#, "despite / in spite of", "'Despite' is not followed by 'of'.", "grammar"),
        (#"\baccording to me\b"#, "in my opinion", "'According to' is used for other people's views.", "vocabulary"),
        (#"\bin the other hand\b"#, "on the other hand", "Fixed expression: 'on the other hand'.", "cohesion"),
        (#"\bnow a days\b"#, "nowadays", "'Nowadays' is one word.", "spelling"),
        (#"\balot\b"#, "a lot", "'A lot' is two words.", "spelling"),
        (#"\bcan able to\b"#, "can / are able to", "Use 'can' or 'be able to', not both.", "grammar"),
        (#"\bpeople is\b"#, "people are", "'People' takes a plural verb.", "grammar"),
        (#"\bpeople has\b"#, "people have", "'People' takes a plural verb.", "grammar"),
        (#"\bpeople was\b"#, "people were", "'People' takes a plural verb.", "grammar"),
        (#"\b(he|she|it) have\b"#, "$1 has", "Third person singular takes 'has'.", "grammar"),
        (#"\b(he|she|it) don't\b"#, "$1 doesn't", "Third person singular takes 'doesn't'.", "grammar"),
        (#"\bthey was\b"#, "they were", "'They' takes 'were'.", "grammar"),
        (#"\bthere is (many|several|a lot of|some) (\w+s)\b"#, "there are $1 $2", "Use 'there are' before a plural noun.", "grammar"),
        (#"\bthis (\w+s) are\b"#, "these $1 are", "Use 'these' with a plural noun.", "grammar"),
        (#"\beveryone are\b"#, "everyone is", "'Everyone' takes a singular verb.", "grammar"),
        (#"\beverybody have\b"#, "everybody has", "'Everybody' takes a singular verb.", "grammar"),
        (#"\bone of the (\w+[^s\W])\b(?= (is|are|was|that|which|in|of)\b)"#, "one of the $1s", "'One of the' is followed by a plural noun.", "grammar"),
        (#"\bin nowadays\b"#, "nowadays", "'Nowadays' is not preceded by 'in'.", "grammar"),
        (#"\bbecause of (he|she|they|it|we|i) "#, "because $1 ", "'Because of' is followed by a noun, 'because' by a clause.", "grammar"),
        (#"\bdepend of\b"#, "depend on", "The preposition after 'depend' is 'on'.", "grammar"),
        (#"\bresult to\b"#, "result in", "The verb 'result' is followed by 'in'.", "grammar"),
        (#"\bcontribute for\b"#, "contribute to", "The preposition after 'contribute' is 'to'.", "grammar"),
        (#"\blooking forward to (see|hear|meet)\b"#, "looking forward to $1ing", "'Look forward to' is followed by the -ing form.", "grammar"),
        (#"\bi am agree\b"#, "I agree", "'Agree' is a verb; do not use 'am'.", "grammar"),
        (#"\bdid not went\b"#, "did not go", "Use the base form after 'did not'.", "grammar"),
        (#"\bmuch (people|students|countries|problems|things)\b"#, "many $1", "Use 'many' with countable plural nouns.", "grammar"),
        (#"\bless (people|students|countries|cars|jobs)\b"#, "fewer $1", "Use 'fewer' with countable plural nouns.", "grammar"),
        (#"\bamount of (people|students|cars|countries)\b"#, "number of $1", "Use 'number of' with countable nouns.", "vocabulary"),
        (#"\ba (a|e|i|o)(\w+)\b"#, "an $1$2", "Use 'an' before a vowel sound.", "grammar"),
        (#"(?-i)(?<![.!?]\s)(?<!^)\bi\b"#, "I", "The pronoun 'I' is always capitalised.", "punctuation"),
    ]

    public init(task: Int, text: String) {
        let lower = text.lowercased()
        let tokens = lower.split { !$0.isLetter && $0 != "'" && $0 != "’" }.map(String.init)
        words = Marking.wordCount(text)
        paragraphs = text.components(separatedBy: "\n").filter { Marking.wordCount($0) >= 8 }.count

        var found: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence, Marking.wordCount(sentence) >= 3 {
                found.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        sentences = found
        averageSentenceLength = found.isEmpty ? 0 : Double(words) / Double(found.count)
        let complex = found.filter { sentence in
            sentence.lowercased().split { !$0.isLetter }.contains { Self.subordinators.contains(String($0)) }
        }
        complexShare = found.isEmpty ? 0 : Double(complex.count) / Double(found.count)

        // Moving-average type–token ratio: stable across essay lengths.
        let window = 50
        if tokens.count >= window {
            var total = 0.0
            var count = 0
            for start in stride(from: 0, through: tokens.count - window, by: 10) {
                total += Double(Set(tokens[start..<start + window]).count) / Double(window)
                count += 1
            }
            lexicalVariety = total / Double(count)
        } else {
            lexicalVariety = tokens.isEmpty ? 0 : Double(Set(tokens).count) / Double(tokens.count)
        }

        var linkerCounts: [String: Int] = [:]
        for linker in Self.linkers {
            let count = Self.count(of: "\\b\(linker)\\b", in: lower)
            if count > 0 { linkerCounts[linker] = count }
        }
        linkersUsed = linkerCounts
        overusedLinkers = linkerCounts.filter { $0.value >= 4 && !["because", "while", "such as", "since"].contains($0.key) }
            .keys.sorted()

        var frequency: [String: Int] = [:]
        for token in tokens where token.count > 3 && !Self.stopwords.contains(token) {
            frequency[token, default: 0] += 1
        }
        let threshold = max(5, words / 45)
        repeatedWords = frequency.filter { $0.value >= threshold }
            .sorted { $0.value > $1.value }.prefix(5).map { (word: $0.key, count: $0.value) }

        var informalFound = Self.informal.filter { Self.count(of: "\\b\($0)\\b", in: lower) > 0 }
        if Self.count(of: "\\b\\w+n['’]t\\b|\\b(it|that|there|he|she)['’]s\\b|\\b(i|we|they|you)['’](m|re|ve|ll)\\b", in: lower) > 0 {
            informalFound.append("contractions (don't, it's)")
        }
        informalItems = informalFound

        hasOverview = Self.count(of: "\\b(overall|in general|in summary|it is clear that|it can be seen that|generally speaking)\\b", in: lower) > 0
        hasOpinion = Self.count(of: "\\b(i (strongly |firmly |personally |completely |partly |totally )?(believe|think|agree|disagree|feel|would argue)|in my (opinion|view)|from my (perspective|point of view)|my view is)\\b", in: lower) > 0
        hasConclusion = Self.count(of: "\\b(in conclusion|to conclude|to sum up|in summary|to summarise|to summarize|all in all)\\b", in: lower) > 0
        figureCount = Self.count(of: "\\d+(\\.\\d+)?", in: text)

        corrections = Self.findCorrections(in: text)
    }

    private static func count(of pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    /// Pattern-based grammar slips plus misspellings from the system spell checker.
    static func findCorrections(in text: String) -> [Correction] {
        var results: [Correction] = []
        var seen = Set<String>()
        let full = NSRange(text.startIndex..., in: text)
        for (pattern, replacement, explanation, category) in errorPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: full).prefix(2) {
                guard let range = Range(match.range, in: text) else { continue }
                let original = String(text[range])
                // "a university", "a European", "a one-off" are correct: skip the a/an rule for them.
                if pattern.hasPrefix(#"\ba (a|e|i|o)"#) {
                    let next = original.dropFirst(2).lowercased()
                    if next.hasPrefix("one") || next.hasPrefix("eu") || next.hasPrefix("once") { continue }
                }
                let fixed = regex.replacementString(for: match, in: text, offset: 0, template: replacement)
                guard seen.insert(original.lowercased()).inserted else { continue }
                results.append(Correction(original: context(of: range, in: text), corrected: fixed,
                                          explanation: explanation, category: category))
            }
        }
        for (word, guess) in misspellings(in: text).prefix(12) where seen.insert(word.lowercased()).inserted {
            results.append(Correction(original: word, corrected: guess,
                                      explanation: "Spelling.", category: "spelling"))
        }
        return Array(results.prefix(20))
    }

    /// The matched words with one word of context either side.
    private static func context(of range: Range<String.Index>, in text: String) -> String {
        String(text[range])
    }

    /// Words rejected by both the British and the American dictionary, with the top suggestion.
    static func misspellings(in text: String) -> [(String, String)] {
        var results: [(String, String)] = []
        let nsText = text as NSString
        var location = 0
        #if canImport(UIKit)
        let checker = UITextChecker()
        while location < nsText.length {
            let range = checker.rangeOfMisspelledWord(
                in: text, range: NSRange(location: location, length: nsText.length - location),
                startingAt: location, wrap: false, language: "en_GB")
            if range.location == NSNotFound { break }
            let word = nsText.substring(with: range)
            location = range.location + range.length
            guard isCheckable(word, at: range.location, in: nsText) else { continue }
            let american = checker.rangeOfMisspelledWord(
                in: word, range: NSRange(location: 0, length: (word as NSString).length),
                startingAt: 0, wrap: false, language: "en_US")
            if american.location == NSNotFound { continue }
            if let guess = checker.guesses(forWordRange: range, in: text, language: "en_GB")?.first {
                results.append((word, guess))
            }
        }
        #elseif canImport(AppKit)
        let checker = NSSpellChecker.shared
        while location < nsText.length {
            let range = checker.checkSpelling(of: text, startingAt: location, language: "en_GB",
                                              wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
            if range.location == NSNotFound || range.length == 0 { break }
            let word = nsText.substring(with: range)
            location = range.location + range.length
            guard isCheckable(word, at: range.location, in: nsText) else { continue }
            let american = checker.checkSpelling(of: word, startingAt: 0, language: "en_US",
                                                 wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
            if american.location == NSNotFound || american.length == 0 { continue }
            if let guess = checker.guesses(forWordRange: range, in: text, language: "en_GB",
                                           inSpellDocumentWithTag: 0)?.first {
                results.append((word, guess))
            }
        }
        #endif
        return results
    }

    /// Skip names and acronyms: capitalised words that do not start a sentence.
    private static func isCheckable(_ word: String, at location: Int, in text: NSString) -> Bool {
        guard word.count > 2, let first = word.unicodeScalars.first else { return false }
        if !CharacterSet.uppercaseLetters.contains(first) { return true }
        var index = location - 1
        while index >= 0, let scalar = Unicode.Scalar(text.character(at: index)),
              CharacterSet.whitespacesAndNewlines.contains(scalar) {
            index -= 1
        }
        if index < 0 { return true }
        let previous = text.substring(with: NSRange(location: index, length: 1))
        return [".", "!", "?"].contains(previous)
    }
}
