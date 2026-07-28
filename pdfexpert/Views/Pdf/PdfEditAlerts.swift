//
//  PdfEditAlerts.swift
//  PdfExpert
//
//  Everything the editor can say back, in one place.
//
//  These were twenty-odd modifiers stacked on the editor's own `body`, which is
//  where a screen stops being readable: the shape of the editor — a page, two
//  bars and a stack — was buried under its error handling. None of the logic
//  changed in the move.
//
//  The three "…and it worked" alerts were also three separate spellings of the
//  same alert, down to the same two buttons; they are now one.
//

import SwiftUI

extension View {

    /// The alerts, progress views and flow modifiers the editor puts over itself.
    func pdfEditAlerts(viewModel: PdfEditViewModel) -> some View {
        self.modifier(PdfEditAlerts(viewModel: viewModel))
    }
}

struct PdfEditAlerts: ViewModifier {

    @ObservedObject var viewModel: PdfEditViewModel

    func body(content: Content) -> some View {
        content
            // Long-running work, each with its own channel because each replaces
            // a different part of the document.
            .asyncView(asyncOperation: self.$viewModel.asyncPdf,
                       loadingView: { AnimationType.pdf.view })
            .asyncView(asyncOperation: self.$viewModel.asyncOcr,
                       loadingView: { AnimationType.pdf.view })
            .asyncView(asyncOperation: self.$viewModel.asyncCleanup,
                       loadingView: { AnimationType.pdf.view })
            .asyncView(asyncOperation: self.$viewModel.asyncImageLoading,
                       loadingView: { AnimationType.pdf.view })

            // The flows whose form the editor pushes: what is left of them here
            // is what they say back — the loader, the errors, the alert that a
            // copy was saved. Their forms are screens on the stack, so the full
            // `show*View` modifiers, which also present them, must not be here:
            // that would put the same form on screen twice.
            .compressOutcomes(viewModel: self.viewModel.pdfCompressViewModel)
            .splitOutcomes(viewModel: self.viewModel.pdfSplitViewModel)
            .extractOutcomes(viewModel: self.viewModel.pdfExtractViewModel)
            .exportOutcomes(viewModel: self.viewModel.pdfExportViewModel)
            .permissionsOutcomes(viewModel: self.viewModel.pdfPermissionsViewModel)

            // The flows that still own their own presentation.
            .showUnlockView(viewModel: self.viewModel.pdfUnlockViewModel)
            .showRedactView(viewModel: self.viewModel.pdfRedactViewModel)
            .showOfficeImportAlerts(coordinator: self.viewModel.officeImportCoordinator)
            .showShareView(coordinator: self.viewModel.pdfShareCoordinator)

            // Passwords.
            .removePasswordView(show: self.$viewModel.removePasswordAlertShow,
                                removePasswordCallback: self.viewModel.removePassword)
            .addPasswordView(show: self.$viewModel.passwordTextFieldShow,
                             addPasswordCallback: { self.viewModel.setPassword($0) })

            // Results.
            .alert(self.viewModel.toolOutcomeAlertTitle, isPresented: self.$viewModel.toolOutcomeAlertShow, actions: {
                Button("Ok", role: .cancel, action: {})
            }, message: {
                Text(self.viewModel.toolOutcomeAlertMessage)
            })
            .alert("Info", isPresented: self.$viewModel.missingWidgetWarningShow, actions: {
                Button("Ok", role: .cancel, action: {})
            }, message: {
                Text("Your pdf has no  fields that you can fill in.")
            })
            .alertCameraPermission(isPresented: self.$viewModel.cameraPermissionDeniedShow)
            .showError(self.$viewModel.pdfSaveError)
            .editorOutcomeAlert(.saved,
                                show: self.$viewModel.saveSuccessfulAlertShow,
                                onGoToArchive: { self.viewModel.goToArchive() },
                                onShare: { self.viewModel.share() })
            .editorOutcomeAlert(.split,
                                show: self.$viewModel.splitSuccessAlertShow,
                                onGoToArchive: { self.viewModel.goToArchive() })
            .editorOutcomeAlert(.extracted,
                                show: self.$viewModel.extractSuccessAlertShow,
                                onGoToArchive: { self.viewModel.goToArchive() })
    }
}

// MARK: - Outcomes

/// The three things the editor can finish doing that leave a document in the
/// archive. They were three near-identical alerts; the only real difference is
/// the wording and whether sharing makes sense.
enum EditorOutcome {

    case saved
    case split
    case extracted

    var title: String {
        switch self {
        case .saved: return String(localized: "PDF saved!")
        case .split: return String(localized: "PDF split!")
        case .extracted: return String(localized: "Pages extracted!")
        }
    }

    var message: String {
        switch self {
        case .saved: return String(localized: "Your pdf has been successfully saved")
        case .split: return String(localized: "Your pdf has been successfully split and saved!")
        case .extracted: return String(localized: "Your pages have been successfully extracted and saved!")
        }
    }
}

extension View {

    func editorOutcomeAlert(_ outcome: EditorOutcome,
                            show: Binding<Bool>,
                            onGoToArchive: @escaping () -> Void,
                            onShare: (() -> Void)? = nil) -> some View {
        self.alert(outcome.title, isPresented: show, actions: {
            Button("Go to files", action: onGoToArchive)
            if let onShare {
                Button("Share pdf", action: onShare)
            }
            Button("Continue edit", action: {})
        }, message: {
            Text(outcome.message)
        })
    }
}
