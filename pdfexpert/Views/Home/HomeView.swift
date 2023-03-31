//
//  HomeView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/03/23.
//

import SwiftUI
import Factory
import PopupView
import PhotosUI

struct HomeView: View {
    
    @InjectedObject(\.homeViewModel) var homeViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            HomeItemView(title: "Convert\npicture to PDF",
                         buttonText: "Start to convert",
                         onButtonPressed: { self.homeViewModel.openImageInputPicker() })
            HomeItemView(title: "Convert\nWord to PDF",
                         buttonText: "Start to convert",
                         onButtonPressed: { self.homeViewModel.openFileDocPicker() })
            HomeItemView(title: "PDF\nScanner",
                         buttonText: "Start to scan",
                         onButtonPressed: { self.homeViewModel.scanPdf() })
            Spacer()
        }
        .background(ColorPalette.primaryBG)
        .onAppear() {
            self.homeViewModel.onAppear()
        }
        .fullScreenCover(isPresented: self.$homeViewModel.monetizationShow) {
            SubscriptionView(showModal: self.$homeViewModel.monetizationShow)
        }
        .popup(isPresented: self.$homeViewModel.imageInputPickerShow) {
            ImportView(onFileImportPressed: { self.homeViewModel.openFileImagePicker() },
                       onCameraImportPressed: { self.homeViewModel.openCamera() },
                       onGalleryImportPressed: { self.homeViewModel.openGallery() })
        } customize: {
            $0
                .type(.toast)
                .closeOnTapOutside(true)
                .closeOnTap(false)
                .backgroundColor(ColorPalette.primaryBG.opacity(0.5))
        }
        .fullScreenCover(isPresented: self.$homeViewModel.fileImagePickerShow) {
            FilePicker(fileTypes: [.image],
                       onPickedFile: { self.homeViewModel.convertFileImage(fileImageUrl: $0) })
        }
        .fullScreenCover(isPresented: self.$homeViewModel.fileDocPickerShow) {
            FilePicker(fileTypes: K.Misc.DocFileTypes,
                       onPickedFile: { self.homeViewModel.convertFileDoc(fileDocUrl: $0) })
        }
        .fullScreenCover(isPresented: self.$homeViewModel.scannerShow) {
            ScannerView(onScannerResult: { self.homeViewModel.convertScanToPdf(scannerResult: $0) })
        }
        .photosPicker(isPresented: self.$homeViewModel.imagePickerShow,
                      selection: self.$homeViewModel.imageSelection,
                      matching: .images)
        .fullScreenCover(isPresented: self.$homeViewModel.cameraShow) {
            CameraView(model: Container.shared.cameraViewModel({ uiImage in
                self.homeViewModel.cameraShow = false
                self.homeViewModel.convertUiImageToPdf(uiImage: uiImage)
            }))
        }
        .sheet(isPresented: self.$homeViewModel.pdfExportShow) {
            ActivityViewController(activityItems: [self.homeViewModel.asyncPdf.data!])
        }
        .asyncView(asyncOperation: self.$homeViewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view.loop(autoReverse: true) })
        .asyncView(asyncOperation: self.$homeViewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view.loop(autoReverse: true) })
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
