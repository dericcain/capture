import Foundation

actor OpenAIService {
    static let apiKeyDefaultsKey = "openAIAPIKey"

    struct EnrichmentPayload: Codable {
        let summary: String
        let areas: [String]
        let people: [String]
        let topics: [String]
        let tasks: [String]
        let dates: [String]
        let confidence: Double
    }

    private let session: URLSession
    private let baseURL = URL(string: "https://api.openai.com/v1")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    var apiKey: String? {
        let key = UserDefaults.standard.string(forKey: Self.apiKeyDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return key?.isEmpty == false ? key : nil
    }

    func hasAPIKey() -> Bool {
        apiKey != nil
    }

    func transcribeAudio(fileURL: URL) async throws -> String {
        guard let apiKey else {
            throw ServiceError.missingAPIKey
        }

        let fileData = try Data(contentsOf: fileURL)

        var request = URLRequest(url: baseURL.appending(path: "audio/transcriptions"))
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue(["Bearer", apiKey].joined(separator: " "), forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendMultipartField(named: "model", value: "whisper-1", boundary: boundary)
        body.appendMultipartFile(named: "file", fileData: fileData, filename: fileURL.lastPathComponent, mimeType: "audio/m4a", boundary: boundary)
        body.appendString("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func generateEnrichment(from content: String) async throws -> EnrichmentPayload {
        guard let apiKey else {
            throw ServiceError.missingAPIKey
        }

        var request = URLRequest(url: baseURL.appending(path: "chat/completions"))
        request.httpMethod = "POST"
        request.setValue(["Bearer", apiKey].joined(separator: " "), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Summarize and extract metadata from the following capture. Return a JSON object with keys summary, areas, people, topics, tasks, dates, confidence. Areas should be chosen from: fitness, soccer, music, software, life. Tasks and dates should be short human-readable phrases.

        Capture:
        \(content)
        """

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": "You are a precise extraction assistant."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw ServiceError.invalidResponse
        }
        guard let jsonData = content.data(using: .utf8) else {
            throw ServiceError.invalidResponse
        }
        return try JSONDecoder().decode(EnrichmentPayload.self, from: jsonData)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw ServiceError.remoteFailure(message)
        }
    }
}

extension OpenAIService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case remoteFailure(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                "Missing OpenAI API key."
            case .invalidResponse:
                "The AI service returned an invalid response."
            case .remoteFailure(let message):
                message
            }
        }
    }
}

private struct TranscriptionResponse: Codable {
    let text: String
}

private struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String?
        }
        let message: Message
    }

    let choices: [Choice]
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }

    mutating func appendMultipartField(named name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString(value)
        appendString("\r\n")
    }

    mutating func appendMultipartFile(named name: String, fileData: Data, filename: String, mimeType: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(fileData)
        appendString("\r\n")
    }
}
