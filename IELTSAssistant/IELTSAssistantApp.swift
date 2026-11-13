import IELTSKit
import SwiftUI

@main
struct IELTSAssistantApp: App {
    /// The optional on-device language model. Nil unless the MLX packages and the
    /// model folder have been added to this target (see README, "Add the language model").
    private let generator: TextGenerator? = makeLanguageModel()

    var body: some Scene {
        WindowGroup {
            RootView(generator: generator)
        }
    }
}

#if canImport(MLXLLM) && canImport(MLXHuggingFace) && canImport(Tokenizers) && canImport(HuggingFace)
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

func makeLanguageModel() -> TextGenerator? {
    MLXGenerator()
}

/// Runs the fine-tuned model in the bundled "ielts-llm" folder with MLX.
/// NOTE: written against mlx-swift-lm 3.32 from its documentation; it could not be
/// compiled on the machine that wrote it (no Xcode), so expect to adjust small details.
final class MLXGenerator: TextGenerator {
    private let directory: URL
    private var container: ModelContainer?

    init?() {
        guard let url = Bundle.main.url(forResource: "ielts-llm", withExtension: nil) else { return nil }
        directory = url
    }

    func generate(
        system: String, messages: [ChatMessage], maxTokens: Int,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        if container == nil {
            container = try await loadModelContainer(from: directory, using: #huggingFaceTokenizerLoader())
        }
        guard let container, let last = messages.last else { return "" }

        // Earlier turns are folded into the prompt so each call is independent.
        var prompt = last.text
        let earlier = messages.dropLast().suffix(6)
        if !earlier.isEmpty {
            let history = earlier.map { ($0.role == "user" ? "User: " : "You: ") + $0.text }.joined(separator: "\n")
            prompt = "Conversation so far:\n\(history)\n\nUser's new message: \(last.text)"
        }

        let session = ChatSession(
            container, instructions: system,
            generateParameters: GenerateParameters(maxTokens: maxTokens, temperature: 0.6)
        )
        var text = ""
        for try await piece in session.streamResponse(to: prompt) {
            text += piece
            await onToken(piece)
        }
        return text
    }
}
#else
func makeLanguageModel() -> TextGenerator? {
    nil
}
#endif
