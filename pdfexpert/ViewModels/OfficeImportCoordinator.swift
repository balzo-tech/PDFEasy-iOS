//
//  OfficeImportCoordinator.swift
//  PdfExpert
//
//  Single owner of the "user picked a non-PDF document" flow, shared by Home, the
//  editor and the chat selection (all three used to call PSPDFKit's
//  `Processor.generatePDF` with their own copy of the logic).
//
//  Flow: convert on-device first (free, offline, WebKit + print pagination). Only if
//  that fails does it offer the high-fidelity online conversion — never silently: the
//  document would leave the device, so it takes an explicit confirmation, the shared
//  one-time privacy disclosure, and the premium gate (the Stirling API is billed per
//  operation). When the API is unavailable (kill switch off or no key) the on-device
//  error is surfaced as-is and nothing is offered.
//

import Foundation
import Factory
import SwiftUI
import Combine

extension Container {
    var officeImportCoordinator: ParameterFactory<OfficeImportCoordinator.Params, OfficeImportCoordinator> {
        self { OfficeImportCoordinator(params: $0) }
    }
}

/// Which engine produced (or failed to produce) the PDF. Reported to analytics so the
/// on-device success rate can be watched — it decides whether the fallback is carrying
/// too much traffic (and cost).
enum OfficeConvertEngine: String {
    case onDevice
    case stirling
}

class OfficeImportCoordinator: ObservableObject {

    struct Params {
        /// The caller's async channel: the coordinator drives loading / data / error on
        /// it, so each host keeps its existing behaviour (Home opens the editor, the
        /// editor appends the pages, the chat starts its selection).
        let asyncPdf: Binding<AsyncOperation<Pdf, PdfError>>
    }

    /// "Local conversion failed — convert online?"
    @Published var fallbackAlertShow: Bool = false
    /// One-time "the document is uploaded" disclosure (shared with the other online tools).
    @Published var disclosureAlertShow: Bool = false
    @Published var monetizationShow: Bool = false

    @Injected(\.stirlingApiManager) private var stirlingApiManager
    @Injected(\.store) private var store
    @Injected(\.cacheManager) private var cacheManager
    @Injected(\.analyticsManager) private var analyticsManager

    private let asyncPdf: Binding<AsyncOperation<Pdf, PdfError>>
    /// Held while the fallback alert / disclosure / paywall are up, so the conversion
    /// can resume with the same file once the user comes back.
    private var pendingFileUrl: URL?
    private var cancellables: Set<AnyCancellable> = []

    init(params: Params) {
        self.asyncPdf = params.asyncPdf
    }

    // MARK: - Entry point

    @MainActor
    func convert(fileUrl: URL) {
        self.pendingFileUrl = fileUrl
        self.asyncPdf.wrappedValue = .init(status: .loading(Progress(totalUnitCount: 1)))
        Task { @MainActor in
            do {
                let data = try await DocumentRenderUtility.convertFile(at: fileUrl)
                self.complete(withPdfData: data, filename: fileUrl.filename, engine: .onDevice)
            } catch {
                self.handleOnDeviceFailure(error: error)
            }
        }
    }

    // MARK: - On-device failure → fallback offer

    @MainActor
    private func handleOnDeviceFailure(error: Error) {
        self.analyticsManager.track(event: .officeConvertFailed(engine: .onDevice))
        debugPrint(for: self, message: "On-device document conversion failed. Error: \(error)")

        guard self.stirlingApiManager.isAvailable, self.pendingFileUrl != nil else {
            self.fail(with: error)
            return
        }
        // Clear the loader first: the alert must not come up on top of a spinner that
        // would keep running behind it.
        self.asyncPdf.wrappedValue = .init(status: .empty)
        self.analyticsManager.track(event: .officeConvertFallbackOffered)
        self.fallbackAlertShow = true
    }

    @MainActor
    func onFallbackDeclined() {
        self.fallbackAlertShow = false
        self.pendingFileUrl = nil
        self.asyncPdf.wrappedValue = .init(status: .empty)
    }

    @MainActor
    func onFallbackAccepted() {
        self.fallbackAlertShow = false
        // Defer so the alert finishes dismissing before the next presentation.
        DispatchQueue.main.async {
            self.runDisclosureGate()
        }
    }

    // MARK: - Gates

    @MainActor
    private func runDisclosureGate() {
        if self.cacheManager.pdfConvertPrivacyAccepted {
            self.runPremiumGate()
        } else {
            self.disclosureAlertShow = true
        }
    }

    @MainActor
    func onDisclosureAccepted() {
        self.cacheManager.pdfConvertPrivacyAccepted = true
        self.disclosureAlertShow = false
        DispatchQueue.main.async {
            self.runPremiumGate()
        }
    }

    @MainActor
    func onDisclosureCancelled() {
        self.disclosureAlertShow = false
        self.pendingFileUrl = nil
        self.asyncPdf.wrappedValue = .init(status: .empty)
    }

    @MainActor
    private func runPremiumGate() {
        if self.store.isPremium.value {
            self.performRemoteConversion()
        } else {
            self.monetizationShow = true
        }
    }

    @MainActor
    func onMonetizationClose() {
        guard self.store.isPremium.value else {
            self.pendingFileUrl = nil
            self.asyncPdf.wrappedValue = .init(status: .empty)
            return
        }
        self.performRemoteConversion()
    }

    // MARK: - Online conversion

    @MainActor
    private func performRemoteConversion() {
        guard let fileUrl = self.pendingFileUrl,
              let fileData = try? Data(contentsOf: fileUrl) else {
            self.fail(with: PdfError.urlToPdfConversionError)
            return
        }

        self.asyncPdf.wrappedValue = .init(status: .loading(Progress(totalUnitCount: 1)))
        self.stirlingApiManager.process(fileData: fileData,
                                        filename: fileUrl.lastPathComponent,
                                        operation: .fileToPdf)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                if case .failure(let error) = completion {
                    self.analyticsManager.track(event: .officeConvertFailed(engine: .stirling))
                    self.fail(with: error)
                }
            }, receiveValue: { [weak self] result in
                guard let self = self else { return }
                self.complete(withPdfData: result.data, filename: fileUrl.filename, engine: .stirling)
            })
            .store(in: &self.cancellables)
    }

    // MARK: - Outcome

    @MainActor
    private func complete(withPdfData data: Data, filename: String, engine: OfficeConvertEngine) {
        guard var pdf = Pdf(data: data) else {
            self.analyticsManager.track(event: .officeConvertFailed(engine: engine))
            self.fail(with: PdfError.urlToPdfConversionError)
            return
        }
        pdf.updateFilename(filename)
        self.pendingFileUrl = nil
        self.analyticsManager.track(event: .officeConvertCompleted(engine: engine))
        self.asyncPdf.wrappedValue = .init(status: .data(pdf))
    }

    @MainActor
    private func fail(with error: Error) {
        self.pendingFileUrl = nil
        // Keep the engine's own localized message (unsupported format, timeout, offline,
        // server message…) rather than flattening everything to "Internal Error".
        if let pdfError = error as? PdfError {
            self.asyncPdf.wrappedValue = .init(status: .error(pdfError))
        } else if let localized = (error as? LocalizedError)?.errorDescription {
            self.asyncPdf.wrappedValue = .init(status: .error(.underlyingError(errorDescription: localized)))
        } else {
            self.asyncPdf.wrappedValue = .init(status: .error(.unknownError))
        }
    }
}
