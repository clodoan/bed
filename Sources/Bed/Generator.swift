import Foundation

enum GeneratorError: LocalizedError {
    case noToken
    case http(Int, String)
    case replicate(String)
    case timeout
    case noOutput

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Paste a token from replicate.com/account/api-tokens"
        case .http(let code, let body):
            let snippet = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if snippet.isEmpty { return "HTTP \(code)" }
            return "HTTP \(code): \(snippet.prefix(180))"
        case .replicate(let message):
            return message
        case .timeout:
            return "Timed out waiting for audio"
        case .noOutput:
            return "No audio URL in response"
        }
    }
}

struct Generator {
    private let createURL = URL(
        string: "https://api.replicate.com/v1/models/stability-ai/stable-audio-2.5/predictions"
    )!

    func generate(prompt: String, token: String) async throws -> URL {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { throw GeneratorError.noToken }

        var request = URLRequest(url: createURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("wait=60", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "input": [
                "prompt": "\(prompt), instrumental, no vocals, background music for focused work",
                "duration": 90,
                "steps": 8,
                "cfg_scale": 1
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.throwIfHTTPError(response, data: data)

        var prediction = try Prediction.parse(data)

        if let error = prediction.error, !error.isEmpty {
            throw GeneratorError.replicate(error)
        }

        let deadline = Date().addingTimeInterval(180)
        while prediction.isInFlight {
            if Date() > deadline { throw GeneratorError.timeout }
            try await Task.sleep(for: .seconds(2))

            guard let getURL = prediction.getURL else {
                throw GeneratorError.noOutput
            }

            var poll = URLRequest(url: getURL)
            poll.timeoutInterval = 30
            poll.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
            let (pollData, pollResponse) = try await URLSession.shared.data(for: poll)
            try Self.throwIfHTTPError(pollResponse, data: pollData)
            prediction = try Prediction.parse(pollData)

            if let error = prediction.error, !error.isEmpty {
                throw GeneratorError.replicate(error)
            }
        }

        if prediction.status == "failed" || prediction.status == "canceled" {
            throw GeneratorError.replicate(prediction.error ?? "Generation failed")
        }

        guard let audioURL = prediction.firstHTTPSURL else {
            throw GeneratorError.noOutput
        }
        return audioURL
    }

    private static func throwIfHTTPError(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard !(200..<300).contains(http.statusCode) else { return }

        if let prediction = try? Prediction.parse(data),
           let error = prediction.error, !error.isEmpty {
            throw GeneratorError.replicate(error)
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        throw GeneratorError.http(http.statusCode, body)
    }
}

private struct Prediction {
    let status: String
    let error: String?
    let getURL: URL?
    let firstHTTPSURL: URL?

    var isInFlight: Bool {
        status == "starting" || status == "processing"
    }

    static func parse(_ data: Data) throws -> Prediction {
        let json = try JSONSerialization.jsonObject(with: data)

        let dict = json as? [String: Any]
        let status = (dict?["status"] as? String) ?? ""
        let error = stringify(dict?["error"])

        var getURL: URL?
        if let urls = dict?["urls"] as? [String: Any],
           let get = urls["get"] as? String {
            getURL = URL(string: get)
        }

        let firstHTTPSURL: URL?
        if let output = dict?["output"] {
            firstHTTPSURL = extractHTTPSURL(from: output)
        } else {
            firstHTTPSURL = extractHTTPSURL(from: json)
        }

        return Prediction(
            status: status,
            error: error,
            getURL: getURL,
            firstHTTPSURL: firstHTTPSURL
        )
    }

    private static func stringify(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func extractHTTPSURL(from json: Any) -> URL? {
        switch json {
        case let string as String:
            if let url = URL(string: string), url.scheme == "https" {
                return url
            }
            return nil
        case let array as [Any]:
            for item in array {
                if let url = extractHTTPSURL(from: item) { return url }
            }
            return nil
        case let dict as [String: Any]:
            for key in ["output", "url", "audio", "file"] {
                if let nested = dict[key], let url = extractHTTPSURL(from: nested) {
                    return url
                }
            }
            for value in dict.values {
                if let url = extractHTTPSURL(from: value) { return url }
            }
            return nil
        default:
            return nil
        }
    }
}
