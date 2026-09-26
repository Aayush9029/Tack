import Dependencies
import DependenciesMacros
import Foundation
import FoundationModels

/// Names a note from its text with the on-device model. Returns nil when Apple
/// Intelligence is off or not downloaded, or when the note's language is not supported.
@DependencyClient
public struct TitleClient: Sendable {
    public var suggest: @Sendable (_ body: String) async throws -> String?
}

extension TitleClient: DependencyKey {
    public static let liveValue = TitleClient { body in
        let model = SystemLanguageModel.default
        guard case .available = model.availability, model.supportsLocale(Locale.current) else { return nil }
        let session = LanguageModelSession(
            model: model,
            instructions: "You name sticky notes. Give a short title that says what the note is about."
        )
        // Guardrails, language and asset errors mean no title, not a problem to report.
        guard let response = try? await session.respond(
            to: Prompt { "Note:\n\(body)" },
            generating: SuggestedTitle.self,
            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 32)
        ) else { return nil }
        return clean(response.content.title)
    }

    public static let testValue = TitleClient()

    private static func clean(_ title: String) -> String? {
        let cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'“”‘’.#*")))
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(48))
    }
}

public extension DependencyValues {
    var titleClient: TitleClient {
        get { self[TitleClient.self] }
        set { self[TitleClient.self] = newValue }
    }
}
