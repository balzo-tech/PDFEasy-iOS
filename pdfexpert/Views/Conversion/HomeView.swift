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
    let imageName: String
    let buttonAction: (HomeViewModel) -> ()
}

struct HomeView: View {
    
    @InjectedObject(\.homeViewModel) var homeViewModel
    
    @State private var passwordText: String = ""
    
    let items: [HomeItem] = [
        HomeItem(title: "Convert\nimages to PDF",
                 imageName: "home_convert_image",
                 buttonAction: { $0.openImageInputPicker() }),
        HomeItem(title: "Convert\nfiles to PDF",
                 imageName: "home_convert_files",
                 buttonAction: { $0.openFilePicker() }),
        HomeItem(title: "PDF\nScanner",
                 imageName: "home_scan",
                 buttonAction: { $0.scanPdf() }),
        HomeItem(title: "Fill in\na file",
                 imageName: "home_fill_form",
                 buttonAction: { $0.openFillFormInputPicker() }),
        HomeItem(title: "Sign\na file",
                 imageName: "home_sign",
                 buttonAction: { $0.openSignInputPicker() }),
        HomeItem(title: "Import\nPDF",
                 imageName: "home_import_pdf",
                 buttonAction: { $0.openPdfFilePicker() })
    ]
    
    private var gridItemLayout = [GridItem(.flexible(), spacing: 14),
                                  GridItem(.flexible(), spacing: 14)]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 14) {
                ForEach(self.items, id: \.id) { item in
                    HomeItemView(title: item.title,
                                 imageName: item.imageName,
                                 onButtonPressed: { item.buttonAction(self.homeViewModel) })
                    .aspectRatio(1.0, contentMode: .fit)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.clear))
                    .listRowInsets(EdgeInsets())
                }
            }
            .padding(14)
        }
        .listStyle(.plain)
        .background(ColorPalette.primaryBG)
        .navigationTitle("Home")
        .onAppear() {
            self.homeViewModel.onAppear()
        }
        // Image input picker
        .sheet(isPresented: self.$homeViewModel.imageInputPickerShow) {
            ImportView(items: [
                ImportItem(title: "File",
                           imageName: "file",
                           callBack: { self.homeViewModel.openFileImagePicker() }),
                ImportItem(title: "Camera",
                           imageName: "camera",
                           callBack: { self.homeViewModel.openCamera() }),
                ImportItem(title: "Gallery",
                           imageName: "gallery",
                           callBack: { self.homeViewModel.openGallery() })
            ])
            .presentationDetents([.height(400)])
        }
        // Fill Form input picker
        .sheet(isPresented: self.$homeViewModel.fillFormInputPickerShow) {
            ImportView(items: [
                ImportItem(title: "From existing file",
                           imageName: "file",
                           callBack: { self.homeViewModel.openFilePicker() }),
                ImportItem(title: "Scan a file",
                           imageName: "scan",
                           callBack: { self.homeViewModel.scanPdf() })
            ])
            .presentationDetents([.height(300)])
        }
        // Sign input picker
        .sheet(isPresented: self.$homeViewModel.signInputPickerShow) {
            ImportView(items: [
                ImportItem(title: "From existing file",
                           imageName: "file",
                           callBack: { self.homeViewModel.openFilePicker() }),
                ImportItem(title: "Scan a file",
                           imageName: "scan",
                           callBack: { self.homeViewModel.scanPdf() })
            ])
            .presentationDetents([.height(300)])
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
        // File picker for files
        .fullScreenCover(isPresented: self.$homeViewModel.filePickerShow) {
            FilePicker(fileTypes: K.Misc.ImportFileTypes.compactMap { $0 },
                       onPickedFile: {
                // Callback is called on modal dismiss, thus we can assign and convert in a row
                self.homeViewModel.urlToFileToConvert = $0
                self.homeViewModel.convert()
            })
        }
        // File picker for pdf files
        .fullScreenCover(isPresented: self.$homeViewModel.pdfFilePickerShow) {
            FilePicker(fileTypes: [.pdf],
                       onPickedFile: {
                self.homeViewModel.importPdf(pdfUrl: $0)
            })
        }
        .alert("Your pdf is protected", isPresented: self.$homeViewModel.pdfPasswordInputShow, actions: {
            SecureField("Enter Password", text: self.$passwordText)
            Button("Confirm", action: {
                self.homeViewModel.importLockedPdf(password: self.passwordText)
                self.passwordText = ""
            })
            Button("Cancel", role: .cancel, action: {
                self.passwordText = ""
            })
        }, message: {
            Text("Enter the password of your pdf in order to import it.")
        })
        // Scanner
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
        .sheet(isPresented: self.$homeViewModel.pdfFlowShow, onDismiss: {
            self.homeViewModel.editStartAction = nil
        }) {
            let pdfEditable = self.homeViewModel.asyncPdf.data!
            let editStartAction = self.homeViewModel.editStartAction
            PdfFlowView(pdfEditable: pdfEditable, startAction: editStartAction)
        }
        .asyncView(asyncOperation: self.$homeViewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view.loop(autoReverse: true) })
        .asyncView(asyncOperation: self.$homeViewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view.loop(autoReverse: true) })
        .alertCameraPermission(isPresented: self.$homeViewModel.cameraPermissionDeniedShow)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            self.homeViewModel.onDidBecomeActive()
        }
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
