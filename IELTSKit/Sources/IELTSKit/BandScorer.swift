import CoreML
import Foundation

/// BERT (cased) WordPiece tokenizer. It must produce exactly the ids the Python
/// tokenizer produced during training; `swift run SelfCheck` compares the two.
public struct ScorerTokenizer {
    static let maxLength = 512
    static let maxPrompt = 96

    private let vocab: [String: Int32]
    private let unknown: Int32
    private let cls: Int32
    private let sep: Int32
    private let pad: Int32

    public init(vocabURL: URL) throws {
        let text = try String(contentsOf: vocabURL, encoding: .utf8)
        var table: [String: Int32] = [:]
        for (index, token) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() where !token.isEmpty {
            table[String(token)] = Int32(index)
        }
        vocab = table
        unknown = table["[UNK]"] ?? 100
        cls = table["[CLS]"] ?? 101
        sep = table["[SEP]"] ?? 102
        pad = table["[PAD]"] ?? 0
    }

    /// "[CLS] Task N: question [SEP] essay [SEP]", padded to 512. Returns ids and attention mask.
    public func encode(task: Int, prompt: String, essay: String) -> (ids: [Int32], mask: [Int32], truncated: Bool) {
        let first = Array(tokenize("Task \(task): \(prompt)").prefix(Self.maxPrompt))
        let all = tokenize(essay)
        let room = Self.maxLength - 3 - first.count
        let second = Array(all.prefix(room))
        var ids = [cls] + first + [sep] + second + [sep]
        var mask = [Int32](repeating: 1, count: ids.count)
        let padding = Self.maxLength - ids.count
        ids += [Int32](repeating: pad, count: padding)
        mask += [Int32](repeating: 0, count: padding)
        return (ids, mask, all.count > room)
    }

    func tokenize(_ text: String) -> [Int32] {
        basicTokens(text).flatMap(wordPieces)
    }

    /// Split on whitespace and around every punctuation mark; drop control characters.
    private func basicTokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = String.UnicodeScalarView()
        func flush() {
            if !current.isEmpty {
                tokens.append(String(current))
                current = String.UnicodeScalarView()
            }
        }
        for scalar in text.unicodeScalars {
            if scalar.value == 0 || scalar.value == 0xFFFD { continue }
            if Self.isWhitespace(scalar) {
                flush()
            } else if Self.isControl(scalar) {
                continue
            } else if Self.isPunctuation(scalar) || Self.isCJK(scalar) {
                flush()
                tokens.append(String(scalar))
            } else {
                current.append(scalar)
            }
        }
        flush()
        return tokens
    }

    /// Greedy longest-match-first word pieces; continuation pieces start with "##".
    private func wordPieces(_ word: String) -> [Int32] {
        let scalars = Array(word.unicodeScalars)
        if scalars.count > 100 { return [unknown] }
        var pieces: [Int32] = []
        var start = 0
        while start < scalars.count {
            var end = scalars.count
            var match: Int32?
            while start < end {
                var piece = String(String.UnicodeScalarView(scalars[start..<end]))
                if start > 0 { piece = "##" + piece }
                if let id = vocab[piece] {
                    match = id
                    break
                }
                end -= 1
            }
            guard let id = match else { return [unknown] }
            pieces.append(id)
            start = end
        }
        return pieces
    }

    private static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r" { return true }
        return scalar.properties.generalCategory == .spaceSeparator
    }

    private static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .format, .surrogate, .privateUse, .unassigned: return true
        default: return false
        }
    }

    private static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        if (33...47).contains(value) || (58...64).contains(value) || (91...96).contains(value) || (123...126).contains(value) {
            return true
        }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) || (0x20000...0x2A6DF).contains(v)
            || (0x2A700...0x2B73F).contains(v) || (0x2B740...0x2B81F).contains(v) || (0x2B820...0x2CEAF).contains(v)
            || (0xF900...0xFAFF).contains(v) || (0x2F800...0x2FA1F).contains(v)
    }
}

/// Raw output of the trained scorer, in bands (not yet rounded).
public struct BandPrediction: Hashable {
    public var overall: Double
    public var task: Double
    public var coherence: Double
    public var lexical: Double
    public var grammar: Double
    /// True when the essay was longer than the model's 512-token window.
    public var truncated: Bool
}

public enum ScorerError: LocalizedError {
    case missingModel
    public var errorDescription: String? {
        "The band-scoring model is missing from the app. Run ml/scripts/train_scorer.py and rebuild."
    }
}

/// The Writing band model trained in ml/scripts/train_scorer.py, running through Core ML.
public final class BandScorer {
    public static let shared = BandScorer()

    private var model: MLModel?
    private var tokenizer: ScorerTokenizer?
    private let lock = NSLock()

    public var isAvailable: Bool {
        Bundle.module.url(forResource: "IELTSScorer", withExtension: "mlmodelc") != nil
            && Bundle.module.url(forResource: "scorer_vocab", withExtension: "txt") != nil
    }

    private func load() throws -> (MLModel, ScorerTokenizer) {
        lock.lock()
        defer { lock.unlock() }
        if let model, let tokenizer { return (model, tokenizer) }
        guard let modelURL = Bundle.module.url(forResource: "IELTSScorer", withExtension: "mlmodelc"),
              let vocabURL = Bundle.module.url(forResource: "scorer_vocab", withExtension: "txt") else {
            throw ScorerError.missingModel
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        let loaded = try MLModel(contentsOf: modelURL, configuration: configuration)
        let loadedTokenizer = try ScorerTokenizer(vocabURL: vocabURL)
        model = loaded
        tokenizer = loadedTokenizer
        return (loaded, loadedTokenizer)
    }

    public func tokenizerForChecks() throws -> ScorerTokenizer { try load().1 }

    public func predict(task: Int, prompt: String, essay: String) throws -> BandPrediction {
        let (model, tokenizer) = try load()
        let encoded = tokenizer.encode(task: task, prompt: prompt, essay: essay)
        let shape = [1, NSNumber(value: ScorerTokenizer.maxLength)]
        let ids = try MLMultiArray(shape: shape, dataType: .int32)
        let mask = try MLMultiArray(shape: shape, dataType: .int32)
        for index in 0..<ScorerTokenizer.maxLength {
            ids[index] = NSNumber(value: encoded.ids[index])
            mask[index] = NSNumber(value: encoded.mask[index])
        }
        let input = try MLDictionaryFeatureProvider(dictionary: ["input_ids": ids, "attention_mask": mask])
        let output = try model.prediction(from: input)
        guard let bands = output.featureValue(for: "bands")?.multiArrayValue, bands.count >= 5 else {
            throw ScorerError.missingModel
        }
        func value(_ index: Int) -> Double { min(9, max(1, bands[index].doubleValue)) }
        return BandPrediction(overall: value(0), task: value(1), coherence: value(2),
                              lexical: value(3), grammar: value(4), truncated: encoded.truncated)
    }
}
