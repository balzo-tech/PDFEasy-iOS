//
//  StirlingApiManagerMock.swift
//  PdfExpert
//
//  Standalone mock (no network, no third-party call) used by SwiftUI previews and,
//  in DEBUG, when `K.Test.Stirling.UseMock` is enabled. It returns canned success
//  responses (small dummy Data with the correct extension per operation), optionally
//  after `K.Test.Stirling.NetworkStubsDelay` seconds so loading states can be
//  exercised. Set `errorMode` (and `available`) to drive failure paths in dev/tests.
//

import Foundation
import Combine

class StirlingApiManagerMock: StirlingApiManager {

    private let stubDelay: TimeInterval = K.Test.Stirling.NetworkStubsDelay

    /// When set, `process(...)` fails with this error instead of returning a result.
    var errorMode: StirlingApiError?

    /// Backing value for `isAvailable` (defaults to available so the happy path works).
    var available: Bool = true

    var isAvailable: Bool { self.available }

    func process(fileData: Data,
                 filename: String,
                 operation: StirlingOperation) -> AnyPublisher<StirlingResult, StirlingApiError> {
        guard self.isAvailable else {
            return Fail(error: StirlingApiError.notConfigured).eraseToAnyPublisher()
        }
        if let errorMode = self.errorMode {
            return Fail(error: errorMode).eraseToAnyPublisher()
        }
        let ext = StirlingApiManagerImpl.defaultExtension(for: operation)
        // `.fileToPdf` must hand back something `PDFDocument(data:)` accepts, otherwise
        // the mocked fallback path fails on parsing rather than exercising the flow.
        let data: Data = (operation == .fileToPdf)
            ? (K.Test.DebugPdfDocumentData ?? Data("Mock \(operation.rawValue) output".utf8))
            : Data("Mock \(operation.rawValue) output".utf8)
        return self.stubbed(StirlingResult(data: data, suggestedFileExtension: ext))
    }

    private func stubbed(_ value: StirlingResult) -> AnyPublisher<StirlingResult, StirlingApiError> {
        let publisher = Just(value).setFailureType(to: StirlingApiError.self)
        if self.stubDelay > 0.0 {
            return publisher
                .delay(for: .seconds(self.stubDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        return publisher.eraseToAnyPublisher()
    }
}
