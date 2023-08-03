//
//  ChatPdfSelectionView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/07/23.
//

import SwiftUI
import Factory

struct ChatPdfSelectionView: View {
    
    @InjectedObject(\.chatPdfSelectionViewModel) var viewModel
    
    var body: some View {
        VStack {
            Spacer()
            Text("Our PDF AI summarize and answer questions for free. Drop your PDF here.")
                .font(FontPalette.fontRegular(withSize: 14))
                .foregroundColor(ColorPalette.primaryText)
                .multilineTextAlignment(.center)
                .padding([.leading, .trailing], 32)
            Spacer().frame(height: 60)
            self.buttonView
            Spacer().frame(height: 50)
            self.warningView
                .padding([.leading, .trailing], 32)
            Spacer()
        }
        .ignoresSafeArea(.keyboard)
        .background(ColorPalette.primaryBG)
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
        .fullScreenCover(item: self.$viewModel.chatPdfInitParams) { chatPdfInitParams in
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
        .showUnlockView(viewModel: self.viewModel.pdfUnlockViewModel)
        .alertCameraPermission(isPresented: self.$viewModel.cameraPermissionDeniedShow)
    }
    
    @ViewBuilder var buttonView: some View {
        Button(action: self.viewModel.getPdfButtonPressed) {
            GeometryReader { geometryReader in
                Group {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 48)
                        .foregroundColor(ColorPalette.secondaryText)
                }
                .frame(width: geometryReader.size.width * 0.7, height: geometryReader.size.height)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundColor(ColorPalette.primaryText))
                .position(x: geometryReader.size.width/2, y: geometryReader.size.height/2)
                .contentShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(height: 130)
    }
    
    @ViewBuilder var warningView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 18)
                
                .foregroundColor(ColorPalette.thirdText)
            Text("PDF are limited to 32MB per file\nand are limited to 2000 pages")
                .font(FontPalette.fontRegular(withSize: 13))
                .foregroundColor(ColorPalette.thirdText)
                .minimumScaleFactor(0.5)
        }
    }
}

struct ChatPdfSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ChatPdfSelectionView()
    }
}
