//
//  PdfPermissionsViewModel.swift
//  PdfExpert
//
//  "PDF permissions" (PREMIUM): restrict printing and copying on a document.
//
//  Deliberately a separate tool from "PDF Protector" rather than an extension of it.
//  The existing password flow stores `pdf.password` as *model* state applied when the
//  file is shared; permissions live inside the encrypted PDF itself, so carrying them
//  the same way would have meant a new Core Data attribute — and with the model marked
//  `usedWithCloudKit`, a production schema deploy. Re-emitting the document and saving
//  a protected copy to the archive (the PdfAdvancedTool shape) keeps the schema
//  untouched and leaves the original intact.
//

import Foundation
import Factory
import SwiftUI
import PDFKit

extension Container {
    var pdfPermissionsViewModel: Factory<PdfPermissionsViewModel> {
        self { PdfPermissionsViewModel() }
    }
}

class PdfPermissionsViewModel: ObservableObject {

    @Published var monetizationShow: Bool = false
    /// The owner-password + toggles form.
    @Published var formShow: Bool = false
    @Published var successAlertShow: Bool = false

    @Published var ownerPassword: String = ""
    @Published var allowsPrinting: Bool = true
    @Published var allowsCopying: Bool = true

    @Published var asyncImportedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdf = self.asyncImportedPdf.data {
                self.onImportCompleted(pdf: importedPdf)
                self.asyncImportedPdf = .init(status: .empty)
            }
        }
    }
    @Published var asyncApply: AsyncEmptyFailable<PdfPermissionsError> = .idle

    /// Enabled only once there is an owner password to enforce the flags with.
    var canConfirm: Bool {
        !self.ownerPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    @Injected(\.repository) private var repository

    lazy var pdfImportViewModel: PdfImportViewModel = {
        Container.shared.pdfImportViewModel(PdfImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncImportedPdf)))
    }()

    private var toBeProcessedPdf: Pdf? = nil
    private var onCompleted: (() -> ())? = nil

    /// Entry point. With a pdf (from the editor) the flow starts immediately; with nil
    /// (from Home) the tool runs its own import first.
    @MainActor
    func run(pdf: Pdf?, onCompleted: (() -> ())?) {
        self.onCompleted = onCompleted
        if let pdf = pdf {
            self.asyncImportedPdf = .init(status: .data(pdf))
        } else {
            self.pdfImportViewModel.importPdf(importFileTypes: K.Misc.ImportFileTypesForExtract)
        }
    }

    private func onImportCompleted(pdf: Pdf) {
        guard pdf.pageCount > 0 else {
            self.asyncApply = .error(.unknownError)
            return
        }
        self.toBeProcessedPdf = pdf
        self.analyticsManager.track(event: .reportScreen(.permissions))
        // Defer so any import sheet finishes dismissing before the paywall / form.
        DispatchQueue.main.async {
            self.startFlow()
        }
    }

    // MARK: - Premium gate

    @MainActor
    private func startFlow() {
        if self.store.isPremium.value {
            self.presentForm()
        } else {
            self.monetizationShow = true
        }
    }

    @MainActor
    func onMonetizationClose() {
        guard self.store.isPremium.value else {
            self.toBeProcessedPdf = nil
            return
        }
        self.presentForm()
    }

    @MainActor
    private func presentForm() {
        self.ownerPassword = ""
        self.allowsPrinting = true
        self.allowsCopying = true
        self.formShow = true
    }

    // MARK: - Form actions

    @MainActor
    func cancel() {
        self.formShow = false
        self.ownerPassword = ""
        self.toBeProcessedPdf = nil
    }

    @MainActor
    func confirm() {
        guard self.canConfirm else {
            self.asyncApply = .error(.missingOwnerPassword)
            return
        }
        guard let pdf = self.toBeProcessedPdf else {
            self.asyncApply = .error(.unknownError)
            return
        }

        let ownerPassword = self.ownerPassword
        let permissions = PdfPermissions(allowsPrinting: self.allowsPrinting,
                                         allowsCopying: self.allowsCopying)
        self.formShow = false
        self.ownerPassword = ""

        DispatchQueue.main.async {
            self.apply(to: pdf, ownerPassword: ownerPassword, permissions: permissions)
        }
    }

    @MainActor
    private func apply(to pdf: Pdf, ownerPassword: String, permissions: PdfPermissions) {
        self.asyncApply = .loading(Progress.undeterminedProgress)
        let document = pdf.pdfDocument

        DispatchQueue.global(qos: .userInitiated).async {
            let data = PdfPermissionsUtility.apply(to: document,
                                                   ownerPassword: ownerPassword,
                                                   permissions: permissions)
            DispatchQueue.main.async {
                guard let data = data, var protectedPdf = Pdf(data: data) else {
                    self.asyncApply = .error(.encodingFailed)
                    self.toBeProcessedPdf = nil
                    return
                }
                // Saved as a copy: the original stays readable and unrestricted in the
                // archive, so the user can always go back.
                protectedPdf.updateFilename(pdf.filename + "-protected")
                do {
                    _ = try self.repository.savePdf(pdf: protectedPdf)
                } catch {
                    self.asyncApply = .error(.unknownError)
                    self.toBeProcessedPdf = nil
                    return
                }
                self.asyncApply = .idle
                self.successAlertShow = true
                self.analyticsManager.track(event: .pdfPermissionsSet(allowsPrinting: permissions.allowsPrinting,
                                                                      allowsCopying: permissions.allowsCopying))
                self.toBeProcessedPdf = nil
                self.onCompleted?()
            }
        }
    }
}
