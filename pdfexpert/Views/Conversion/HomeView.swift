//
//  HomeView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/03/23.
//

import SwiftUI
import Factory
import PhotosUI

struct HomeItem: Identifiable {
    let id = UUID()
    let title: String
    let buttonText: String
    let buttonAction: (HomeViewModel) -> ()
}

struct HomeView: View {
    
    @InjectedObject(\.homeViewModel) var homeViewModel
    
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
            .listRowSeparator(.hidden)
            .listRowBackground(Color(.clear))
            .listRowInsets(EdgeInsets())
        }
        .padding(.top, 20)
        .listStyle(.plain)
        .background(ColorPalette.primaryBG)
        .navigationTitle("Convert")
        .onAppear() {
            self.homeViewModel.onAppear()
        }
        .fullScreenCover(isPresented: self.$homeViewModel.monetizationShow) {
            self.getSubscriptionView(onComplete: {
                self.homeViewModel.monetizationShow = false
            })
        }
        .sheet(isPresented: self.$homeViewModel.imageInputPickerShow) {
            ImportView(onFileImportPressed: { self.homeViewModel.openFileImagePicker() },
                       onCameraImportPressed: { self.homeViewModel.openCamera() },
                       onGalleryImportPressed: { self.homeViewModel.openGallery() })
            .presentationDetents([.height(400)])
        }
        // File picker for images
        .fullScreenCover(isPresented: self.$homeViewModel.fileImagePickerShow) {
            FilePicker(fileTypes: [.image],
                       onPickedFile: {
                // Callback is called on modal dismiss, thus we can assign and convert in a row
                self.homeViewModel.urlToImageToConvert = $0
                self.homeViewModel.convert()
            })
        }
        // File picker for doc files
        .fullScreenCover(isPresented: self.$homeViewModel.fileDocPickerShow) {
            FilePicker(fileTypes: K.Misc.DocFileTypes,
                       onPickedFile: {
                // Callback is called on modal dismiss, thus we can assign and convert in a row
                self.homeViewModel.urlToDocToConvert = $0
                self.homeViewModel.convert()
            })
        }
        // WeScan scanner
        .fullScreenCover(isPresented: self.$homeViewModel.scannerShow) {
            ScannerView(onScannerResult: {
                self.homeViewModel.scannerShow = false
                self.homeViewModel.scannerResult = $0
            }).onDisappear { self.homeViewModel.convert() }
        }
        // Camera for image capture
        .fullScreenCover(isPresented: self.$homeViewModel.cameraShow) {
            CameraView(model: Container.shared.cameraViewModel({ uiImage in
                self.homeViewModel.cameraShow = false
                self.homeViewModel.imageToConvert = uiImage
            })).onDisappear { self.homeViewModel.convert() }
        }
        // Photo gallery picker
        .photosPicker(isPresented: self.$homeViewModel.imagePickerShow,
                      selection: self.$homeViewModel.imageSelection,
                      matching: .images)
        .sheet(isPresented: self.$homeViewModel.pdfFlowShow) {
            let pdfEditable = self.homeViewModel.asyncPdf.data!
            PdfFlowView(pdfEditable: pdfEditable)
        }
        .asyncView(asyncOperation: self.$homeViewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view.loop(autoReverse: true) })
        .asyncView(asyncOperation: self.$homeViewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view.loop(autoReverse: true) })
        .alertCameraPermission(isPresented: self.$homeViewModel.cameraPermissionDeniedShow)
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
