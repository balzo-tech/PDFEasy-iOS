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

struct HomeItem: Identifiable {
    let id = UUID()
    let title: String
    let buttonText: String
    let buttonAction: (HomeViewModel) -> ()
}

struct HomeView: View {
    
    @InjectedObject(\.homeViewModel) var homeViewModel
    @Injected(\.coordinator) var coordinator
    
    let items: [HomeItem] = [
        HomeItem(title: "Convert\npicture to PDF",
                 buttonText: "Start to convert",
                 buttonAction: { $0.openImageInputPicker() }),
        HomeItem(title: "Convert\nWord to PDF",
                 buttonText: "Start to convert",
                 buttonAction: { $0.openFileDocPicker() }),
        HomeItem(title: "PDF\nScanner",
                 buttonText: "Start to scan",
                 buttonAction: { $0.scanPdf() })
    ]
    
    var body: some View {
        List(self.items, id: \.id) { item in
            VStack {
                HomeItemView(title: item.title,
                             buttonText: item.buttonText,
                             onButtonPressed: { item.buttonAction(self.homeViewModel) })
                Spacer().frame(height: 40)
            }
            .listRowBackground(Color(.clear))
            .listRowInsets(EdgeInsets())
        }
        .padding(.top, 20)
        .listStyle(.plain)
        .background(ColorPalette.primaryBG)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { self.coordinator.showProfile() }) {
                    Image("profile")
                }
            }
        }
        .onAppear() {
            self.homeViewModel.onAppear()
        }
        .fullScreenCover(isPresented: self.$homeViewModel.monetizationShow) {
            SubscriptionView(onComplete: { self.homeViewModel.monetizationShow = false })
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
        NavigationStack {
            HomeView()
        }
        .background(ColorPalette.primaryBG)
    }
}
