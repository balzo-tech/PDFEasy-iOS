//
//  ScanFlowView.swift
//  PdfExpert
//
//  The scanner, end to end: camera → review → save.
//
//  One view owns the whole session so the pages survive moving between the
//  camera and the review screen, and so whoever opened the scanner — the Scanner
//  tab, the editor adding pages, ChatPDF importing a document — only has to say
//  what should happen at the end.
//

import SwiftUI
import Factory

struct ScanFlowView: View {

    let mode: ScanFlowMode
    /// `.handOff` only: what to do with the pages.
    var onPages: (([ScannedPage]) -> Void)? = nil
    /// `.newDocument` only: called with the document once it is in the archive.
    var onSaved: ((Pdf) -> Void)? = nil

    @StateObject private var viewModel = Container.shared.documentScanViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var discardConfirmationShow: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch self.viewModel.step {
            case .capture:
                ScanCameraView(viewModel: self.viewModel, onClose: self.close)
            case .review:
                ScanReviewView(viewModel: self.viewModel)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            self.viewModel.onHandOff = { pages in
                self.onPages?(pages)
                self.dismiss()
            }
            self.viewModel.onSaved = { pdf in
                self.onSaved?(pdf)
                self.dismiss()
            }
            self.viewModel.start(mode: self.mode)
        }
        .sheet(isPresented: self.$viewModel.saveSheetShow) {
            ScanSaveSheetView(viewModel: self.viewModel)
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
        }
        .asyncView(asyncOperation: self.$viewModel.asyncPdf)
        .asyncView(asyncItem: self.$viewModel.asyncSave)
        // Saving to Photos leaves nothing behind in the app, so it has to say so.
        .alert("Saved to Photos", isPresented: self.$viewModel.savedToPhotosAlertShow) {
            Button("Done") { self.dismiss() }
            Button("Keep scanning", role: .cancel) {}
        } message: {
            Text("\(self.viewModel.savedToPhotosCount) pages were added to your photo library.")
        }
        .alert("Photos access is off", isPresented: self.$viewModel.photosPermissionDeniedShow) {
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("PDF Pro needs permission to add photos before it can save the pages there.")
        }
        .confirmationDialog(Text("Discard this scan?"),
                            isPresented: self.$discardConfirmationShow,
                            titleVisibility: .visible) {
            Button("Discard", role: .destructive) { self.dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The pages you have taken will be lost.")
        }
    }

    /// Closing with pages in hand asks first: they exist nowhere else.
    private func close() {
        if self.viewModel.pages.isEmpty {
            self.dismiss()
        } else {
            self.discardConfirmationShow = true
        }
    }
}

// MARK: - Save sheet

/// Name it, then choose what it becomes. Two buttons rather than a format
/// picker plus a Save: there are only two answers, and this way each one is a
/// single tap.
struct ScanSaveSheetView: View {

    @ObservedObject var viewModel: DocumentScanViewModel

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.xxs) {
                Text("Scan complete")
                    .font(forCategory: .title3)
                    .foregroundStyle(ColorPalette.textPrimary)
                Text("Choose how to save \(self.viewModel.pageCountText.lowercased())")
                    .font(forCategory: .body2)
                    .foregroundStyle(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DS.Spacing.lg)

            TextField("File name", text: self.$viewModel.filename)
                .textFieldStyle(.plain)
                .font(forCategory: .body1)
                .foregroundStyle(ColorPalette.textPrimary)
                .padding(.horizontal, DS.Spacing.md)
                .frame(height: 52)
                .background(ColorPalette.surface, in: .rect(cornerRadius: DS.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                        .strokeBorder(ColorPalette.separator, lineWidth: 1)
                }
                .focused(self.$isNameFocused)
                .submitLabel(.done)
                .onSubmit { self.isNameFocused = false }
                .autocorrectionDisabled()

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.md)
        .readableColumn()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
        // The two answers live in a bottom inset rather than in the stack, so
        // the keyboard raised by the name field pushes them up instead of
        // covering them. Underneath it, the first tap on a covered button is
        // spent dismissing the keyboard and the button appears not to work —
        // which is what "I had to press Save more than once" was.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Spacing.xs) {
                PrimaryActionButton(title: String(localized: "Save as PDF"), systemImage: "doc.fill") {
                    self.isNameFocused = false
                    self.viewModel.saveAsPdf()
                }
                SecondaryActionButton(title: String(localized: "Save as images"), systemImage: "photo.on.rectangle") {
                    self.isNameFocused = false
                    self.viewModel.saveAsImages()
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
            .background(ColorPalette.background)
        }
    }
}
