import Foundation

enum IntentEngine {
    static func makeIntent(sentence: String, language: String) async throws -> SearchIntent {
        let prompt = """
        In a video edit, a funny or viral clip will be cut in right after this sentence.
        Sentence: "\(sentence)"
        Video language: \(language)
        emotion: the emotion the sentence carries, one word.
        reaction: the reaction the inserted clip should deliver, short.
        queries: three search queries for finding short viral clips, written in the \(language) language.
        speechlessOk: whether a speechless clip (silent reaction) would also work.
        """

        let data = try await ModelClient.json(prompt: prompt, schema: intentSchema)
        return try JSONDecoder().decode(SearchIntent.self, from: data)
    }

    static func score(sentence: String, language: String,
                      candidates: [CandidateClip]) async throws -> [CandidateClip] {
        guard !candidates.isEmpty else { return [] }
        let list = candidates.enumerated()
            .map { "\($0.offset): \($0.element.title) (\($0.element.durationText))" }
            .joined(separator: "\n")

        let prompt = """
        We're picking a clip to cut in right after this sentence in a video edit.
        Sentence: "\(sentence)"
        Video language: \(language)
        Score each candidate 0-10. Rule: a clip that contains speech must speak \(language),
        otherwise it is out; a speechless clip is scored on topical fit alone.
        Guess the spoken language from the title and set hasSpeech accordingly.
        reason: at most six words.
        Candidates:
        \(list)
        """

        let data = try await ModelClient.json(prompt: prompt, schema: scoreSchema)
        guard let decoded = try? JSONDecoder().decode(ScoreList.self, from: data) else {
            return candidates
        }

        var scored = candidates
        for entry in decoded.scores where entry.index >= 0 && entry.index < scored.count {
            scored[entry.index].score = entry.score
            scored[entry.index].reason = entry.reason
            scored[entry.index].language = entry.hasSpeech ? language : nil
        }
        return scored.filter { $0.score >= 6 }.sorted { $0.score > $1.score }
    }

    private struct ScoreList: Decodable {
        let scores: [Entry]

        struct Entry: Decodable {
            let index: Int
            let score: Int
            let reason: String
            let hasSpeech: Bool
        }
    }

    private static let intentSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["emotion", "reaction", "queries", "speechlessOk"],
        "properties": [
            "emotion": ["type": "string"],
            "reaction": ["type": "string"],
            "queries": ["type": "array", "items": ["type": "string"]],
            "speechlessOk": ["type": "boolean"]
        ]
    ]

    private static let scoreSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["scores"],
        "properties": [
            "scores": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["index", "score", "reason", "hasSpeech"],
                    "properties": [
                        "index": ["type": "integer"],
                        "score": ["type": "integer"],
                        "reason": ["type": "string"],
                        "hasSpeech": ["type": "boolean"]
                    ]
                ]
            ]
        ]
    ]
}
