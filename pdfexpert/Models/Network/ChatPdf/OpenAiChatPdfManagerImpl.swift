//
//  OpenAiChatPdfManagerImpl.swift
//  PdfExpert
//
//  Chat-with-PDF backed by OpenAI's Chat Completions API.
//
//  Unlike the previous chatpdf.com integration, nothing is uploaded to a third
//  party: the PDF text is extracted on-device, kept in memory, and sent as part
//  of the prompt on every request. Conversation context is also kept in memory
//  (chatpdf.com used to keep it server-side).
//
//  SECURITY NOTE: the OpenAI API key is embedded in the client. It is compiled in
//  XOR-obfuscated (from the git-ignored ProjectInfo.plist, via the "Generate Secrets"
//  build phase), so it no longer ships as cleartext in the IPA and does not appear in
//  `strings` on the binary. This only raises the bar: a determined attacker who hooks
//  the running process or proxies the traffic can still recover it. The accepted future
//  mitigation is a thin server-side proxy that holds the real key and enforces quotas.
//

import Foundation
import PDFKit
import Moya
import CombineMoya
import Combine
import Factory

class OpenAiChatPdfManagerImpl: ChatPdfManager {

    // MARK: In-memory conversation state

    private struct ChatEntry {
        let role: String
        let content: String
    }

    private struct Conversation {
        let documentText: String
        let truncated: Bool
        var history: [ChatEntry]
    }

    private var conversations: [String: Conversation] = [:]
    private let lock = NSLock()
    private let workQueue = DispatchQueue(label: "com.pdfexpert.openaichatpdf", qos: .userInitiated)

    // MARK: Networking

    lazy var provider: MoyaProvider<OpenAiChatService> = { self.createProvider() }()

    lazy var loggerPlugin: PluginType = {
        let formatter = NetworkLoggerPlugin.Configuration.Formatter(requestData: Data.JSONRequestDataFormatter,
                                                                    responseData: Data.JSONRequestDataFormatter)
        let logOptions: NetworkLoggerPlugin.Configuration.LogOptions = K.Test.ChatPdf.NetworkLogVerbose
            ? .verbose
            : .default
        let config = NetworkLoggerPlugin.Configuration(formatter: formatter, logOptions: logOptions)
        return NetworkLoggerPlugin(configuration: config)
    }()

    @Injected(\.configService) private var configService
    @Injected(\.proxyCredentialsProvider) private var credentialsProvider

    func createProvider() -> MoyaProvider<OpenAiChatService> {
        MoyaProvider<OpenAiChatService>(plugins: [self.loggerPlugin])
    }

    // MARK: - ChatPdfManager

    /// No upload: extract the document text on-device, store it in memory keyed by
    /// a freshly generated UUID, and hand back a `ChatPdfRef` pointing at it.
    func sendPdf(pdf: Data) -> AnyPublisher<ChatPdfRef, ChatPdfError> {
        Deferred {
            Future<ChatPdfRef, ChatPdfError> { promise in
                guard let document = PDFDocument(data: pdf) else {
                    promise(.failure(.parse))
                    return
                }
                let rawText = PDFUtility.extractText(from: document)
                guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    promise(.failure(.underlyingError(errorDescription: Self.noExtractableTextError)))
                    return
                }
                let (text, truncated) = Self.truncateDocumentText(rawText)
                let id = UUID().uuidString
                self.setConversation(Conversation(documentText: text, truncated: truncated, history: []), forId: id)
                promise(.success(ChatPdfRef(sourceId: id)))
            }
        }
        .subscribe(on: self.workQueue)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    /// One chat-completion call that returns a strict-JSON summary + suggested
    /// questions. Does NOT consume the monthly message cap.
    func getSetupData(ref: ChatPdfRef) -> AnyPublisher<ChatPdfSetupData, ChatPdfError> {
        guard let conversation = self.conversation(forId: ref.sourceId) else {
            return Fail(error: ChatPdfError.unknownError).eraseToAnyPublisher()
        }
        let config = self.configService.remoteConfigData.value
        guard !config.proxyBaseUrl.isEmpty else {
            return Fail(error: Self.missingKeyError).eraseToAnyPublisher()
        }
        let messages: [[String: Any]] = [
            ["role": "system", "content": Self.setupSystemPrompt(documentText: conversation.documentText,
                                                                 truncated: conversation.truncated)],
            ["role": "user", "content": Self.setupUserPrompt]
        ]
        return self.proxyCredentials()
            .flatMap { credentials in
                self.provider.requestPublisher(.chatCompletion(credentials: credentials,
                                                               baseUrlString: config.proxyBaseUrl,
                                                               model: config.chatGptModel,
                                                               messages: messages,
                                                               maxTokens: config.chatGptMaxTokens,
                                                               jsonResponse: true))
                .mapError { $0 as Error }
            }
            .tryMap { try Self.extractContent(from: $0) }
            .map { content -> ChatPdfSetupData in
                if let data = content.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(SetupResponse.self, from: data),
                   !decoded.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return ChatPdfSetupData(summary: decoded.summary,
                                            suggestedQuestions: decoded.suggestedQuestions ?? [])
                }
                // The model ignored the JSON contract: fall back to the raw text as the
                // summary (or a generic prompt if it is empty) with no suggestions.
                let summary = content.isEmpty ? Self.fallbackSummary : content
                return ChatPdfSetupData(summary: summary, suggestedQuestions: [])
            }
            .mapError { Self.mapError($0) }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    /// Standard chat completion: system prompt (instructions + document text) +
    /// the in-memory conversation history + the new user prompt. Both the prompt
    /// and the reply are appended to the history.
    func generateText(ref: ChatPdfRef, prompt: String) -> AnyPublisher<ChatPdfMessage, ChatPdfError> {
        guard let conversation = self.conversation(forId: ref.sourceId) else {
            return Fail(error: ChatPdfError.unknownError).eraseToAnyPublisher()
        }
        let config = self.configService.remoteConfigData.value
        guard !config.proxyBaseUrl.isEmpty else {
            return Fail(error: Self.missingKeyError).eraseToAnyPublisher()
        }
        var messages: [[String: Any]] = [
            ["role": "system", "content": Self.chatSystemPrompt(documentText: conversation.documentText,
                                                               truncated: conversation.truncated)]
        ]
        messages.append(contentsOf: conversation.history.map { ["role": $0.role, "content": $0.content] })
        messages.append(["role": "user", "content": prompt])

        return self.proxyCredentials()
            .flatMap { credentials in
                self.provider.requestPublisher(.chatCompletion(credentials: credentials,
                                                               baseUrlString: config.proxyBaseUrl,
                                                               model: config.chatGptModel,
                                                               messages: messages,
                                                               maxTokens: config.chatGptMaxTokens,
                                                               jsonResponse: false))
                .mapError { $0 as Error }
            }
            .tryMap { try Self.extractContent(from: $0) }
            .map { content -> ChatPdfMessage in
                self.appendToHistory(forId: ref.sourceId, userPrompt: prompt, assistantReply: content)
                return ChatPdfMessage(role: .assistant, type: .text, content: content)
            }
            .mapError { Self.mapError($0) }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func deletePdf(ref: ChatPdfRef) {
        self.removeConversation(forId: ref.sourceId)
    }

    // MARK: - Truncation (pure, unit-testable)

    /// Truncates the extracted document text to a character budget so the prompt
    /// stays within the model context window. Returns the (possibly shortened)
    /// text and a flag telling the caller whether truncation happened.
    static func truncateDocumentText(_ text: String,
                                     maxCharacters: Int = K.ChatPdf.DocumentCharacterBudget) -> (text: String, truncated: Bool) {
        guard text.count > maxCharacters else { return (text, false) }
        let endIndex = text.index(text.startIndex, offsetBy: maxCharacters)
        return (String(text[text.startIndex..<endIndex]), true)
    }

    // MARK: - Thread-safe conversation store

    private func setConversation(_ conversation: Conversation, forId id: String) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.conversations[id] = conversation
    }

    private func conversation(forId id: String) -> Conversation? {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.conversations[id]
    }

    private func removeConversation(forId id: String) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.conversations[id] = nil
    }

    private func appendToHistory(forId id: String, userPrompt: String, assistantReply: String) {
        self.lock.lock(); defer { self.lock.unlock() }
        guard var conversation = self.conversations[id] else { return }
        conversation.history.append(ChatEntry(role: "user", content: userPrompt))
        conversation.history.append(ChatEntry(role: "assistant", content: assistantReply))
        // Keep only the most recent messages to bound the request size.
        let limit = K.ChatPdf.ConversationHistoryMessageLimit
        if conversation.history.count > limit {
            conversation.history.removeFirst(conversation.history.count - limit)
        }
        self.conversations[id] = conversation
    }

    // MARK: - Helpers

    /// The App Check token and the subscription id, fetched per request. Moya's
    /// headers are synchronous and App Check's token is not, so this runs first
    /// and the request is built from what it returns.
    private func proxyCredentials() -> AnyPublisher<ProxyCredentials, Error> {
        Future<ProxyCredentials, Error> { promise in
            _Concurrency.Task {
                do { promise(.success(try await self.credentialsProvider.credentials())) }
                catch { promise(.failure(error)) }
            }
        }
        .eraseToAnyPublisher()
    }

    private static func extractContent(from response: Moya.Response) throws -> String {
        guard 200 ... 299 ~= response.statusCode else {
            if let apiError = try? JSONDecoder().decode(OpenAiErrorResponse.self, from: response.data) {
                throw ChatPdfError.underlyingError(errorDescription: apiError.error.message)
            }
            throw ChatPdfError.underlyingError(errorDescription: String(data: response.data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(OpenAiChatResponse.self, from: response.data)
        guard let content = decoded.choices.first?.message.content else {
            throw ChatPdfError.parse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mapError(_ error: Error) -> ChatPdfError {
        if let error = error as? ChatPdfError { return error }
        if error is DecodingError { return .parse }
        return .underlyingError(errorDescription: error.localizedDescription)
    }

    // MARK: - Prompts & localized messages

    private static var noExtractableTextError: String {
        String(localized: "This PDF has no extractable text. Try \"Make Searchable (OCR)\" first, then start the chat again.")
    }

    private static var missingKeyError: ChatPdfError {
        .underlyingError(errorDescription: String(localized: "AI chat is currently unavailable. Please try again later."))
    }

    private static var fallbackSummary: String {
        String(localized: "Ask me something about your PDF!")
    }

    private static func truncationNote(_ truncated: Bool) -> String {
        truncated
            ? "\n\nNOTE: The document text was truncated because it exceeded the size limit; only the beginning of the document is available to you."
            : ""
    }

    private static func chatSystemPrompt(documentText: String, truncated: Bool) -> String {
        """
        You are a helpful assistant that answers questions strictly about the following PDF document. \
        Always answer in the same language as the user's question. If the answer cannot be found in the document, \
        say that you could not find it in the document.\(truncationNote(truncated))

        ---- DOCUMENT START ----
        \(documentText)
        ---- DOCUMENT END ----
        """
    }

    private static func setupSystemPrompt(documentText: String, truncated: Bool) -> String {
        """
        You analyze the following PDF document. Reply ONLY with a valid JSON object with exactly this shape: \
        {"summary": "...", "suggestedQuestions": ["...", "...", "..."]}. \
        "summary" must be a concise summary of the document written in the same language as the document. \
        "suggestedQuestions" must be an array of exactly three short questions a user might ask about the document, \
        written in the same language as the document. Do not output anything outside of the JSON object.\(truncationNote(truncated))

        ---- DOCUMENT START ----
        \(documentText)
        ---- DOCUMENT END ----
        """
    }

    private static let setupUserPrompt = "Summarize this document and suggest three questions."
}

// MARK: - Response models

private struct OpenAiChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

private struct OpenAiErrorResponse: Decodable {
    struct APIError: Decodable { let message: String }
    let error: APIError
}

private struct SetupResponse: Decodable {
    let summary: String
    let suggestedQuestions: [String]?
}

// MARK: - Moya target

enum OpenAiChatService {
    case chatCompletion(credentials: ProxyCredentials, baseUrlString: String, model: String, messages: [[String: Any]], maxTokens: Int, jsonResponse: Bool)
}

extension OpenAiChatService: TargetType {

    /// The proxy, not OpenAI. The app has not held an OpenAI key since the key
    /// stopped being extractable from its bundle — see `proxy/README.md`.
    var baseURL: URL {
        switch self {
        case let .chatCompletion(_, baseUrlString, _, _, _, _):
            return URL(string: baseUrlString) ?? URL(string: "https://invalid.invalid")!
        }
    }

    var path: String { "/v1/chat" }

    var method: Moya.Method { .post }

    var sampleData: Data {
        "{\"choices\":[{\"message\":{\"content\":\"Test Message\"}}]}".data(using: .utf8) ?? Data()
    }

    var task: Task {
        switch self {
        case let .chatCompletion(_, _, model, messages, maxTokens, jsonResponse):
            var parameters: [String: Any] = [
                "model": model,
                "messages": messages,
                "max_tokens": maxTokens
            ]
            if jsonResponse {
                parameters["response_format"] = ["type": "json_object"]
            }
            return .requestParameters(parameters: parameters, encoding: JSONEncoding.default)
        }
    }

    var headers: [String: String]? {
        switch self {
        case let .chatCompletion(credentials, _, _, _, _, _):
            return credentials.headers.merging(["Content-Type": "application/json"]) { current, _ in current }
        }
    }
}
