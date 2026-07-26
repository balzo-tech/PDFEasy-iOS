//
//  ChatPdfSelectionView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/07/23.
//

import SwiftUI
import Factory

struct ChatPdfSelectionView: View {

    @ObservedObject var viewModel: ChatPdfSelectionViewModel
    /// Set by the iPad split, where the conversation is the detail column and
    /// this screen stays visible beside it. On a phone the chat takes over the
    /// screen instead.
    var presentsChatInline: Bool = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(ColorPalette.categoryAi)
                .frame(width: 76, height: 76)
                .background(ColorPalette.categoryAi.opacity(0.14), in: .circle)
            VStack(spacing: DS.Spacing.xs) {
                Text("Ask your PDF anything")
                    .font(forCategory: .title2)
                    .foregroundStyle(ColorPalette.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Our PDF AI summarize and answer questions for free. Drop your PDF here.")
                    .font(forCategory: .body2)
                    .foregroundStyle(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.xl)
            self.buttonView
                .padding(.horizontal, DS.Spacing.xl)
            self.warningView
                .padding(.horizontal, DS.Spacing.xl)
            Spacer()
        }
        .ignoresSafeArea(.keyboard)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
        .onAppear() {
            self.viewModel.onAppear()
        }
        .formSheet(item: self.$viewModel.importOptionGroup) {
            OptionListView.getImportView(forImportOptionGroup: $0,
                                         importViewCallback: { self.viewModel.handleImportOption(importOption: $0) })
        }
        .filePicker(item: self.$viewModel.importFileOption, onPickedFiles: {
            self.viewModel.processPickedFileUrl($0.first)
        })
        .fullScreenCover(isPresented: self.$viewModel.scannerShow) {
            // Scanner
            ScannerView(onScannerResult: {
                self.viewModel.convertScan(scannerResult: $0)
            })
        }
        .fullScreenCover(item: self.modalChatParams) { chatPdfInitParams in
            let parameters = ChatPdfViewModel.Parameters(chatPdfInitParams: chatPdfInitParams)
            ChatPdfView(viewModel: Container.shared.chatPdfViewModel(parameters))
        }
        .fullScreenCover(isPresented: self.$viewModel.monetizationShow) {
            self.getSubscriptionView(onComplete: {
                self.viewModel.monetizationShow = false
            })
        }
        .asyncView(asyncOperation: self.$viewModel.asyncImportPdf,
                   loadingView: { AnimationType.pdf.view })
        .asyncView(asyncOperation: self.$viewModel.asyncChatPdfSetup)
        .showOfficeImportAlerts(coordinator: self.viewModel.officeImportCoordinator)
        .showUnlockView(viewModel: self.viewModel.pdfUnlockViewModel)
        .alertCameraPermission(isPresented: self.$viewModel.cameraPermissionDeniedShow)
    }
    
    /// Nil while the split shell is showing the conversation in its own column,
    /// so the same state does not drive two presentations at once.
    private var modalChatParams: Binding<ChatPdfInitParams?> {
        self.presentsChatInline ? .constant(nil) : self.$viewModel.chatPdfInitParams
    }

    /// Drop target for the document: a dashed well, the way file pickers read
    /// everywhere else — and, since it says "drop your PDF here", one that
    /// actually accepts a drop.
    @ViewBuilder var buttonView: some View {
        Button(action: self.viewModel.getPdfButtonPressed) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(ColorPalette.accent)
                Text("Choose a PDF")
                    .font(forCategory: .body3)
                    .foregroundStyle(ColorPalette.accent)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                    .fill(ColorPalette.accent.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                            .strokeBorder(ColorPalette.accent.opacity(0.5),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                    }
            }
            .contentShape(.rect(cornerRadius: DS.Radius.tile, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .documentDropDestination { pdf in
            self.viewModel.importDroppedPdf(pdf)
        }
    }

    @ViewBuilder var warningView: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14))
                .foregroundStyle(ColorPalette.textTertiary)
            Text("PDF are limited to 32MB per file\nand are limited to 2000 pages")
                .font(forCategory: .caption1)
                .foregroundStyle(ColorPalette.textTertiary)
                .minimumScaleFactor(0.7)
        }
    }
}

struct ChatPdfSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ChatPdfSelectionView(viewModel: Container.shared.chatPdfSelectionViewModel())
    }
}
