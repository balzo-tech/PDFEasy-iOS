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
                 buttonAction: { $0.openImagePickerFlow() }),
        HomeItem(title: "Convert\nfiles to PDF",
                 imageName: "home_convert_files",
                 buttonAction: { $0.openConvertFileFlow() }),
        HomeItem(title: "PDF\nScanner",
                 imageName: "home_scan",
                 buttonAction: { $0.scanPdf(startAction: nil, directlyFromScan: true) }),
        HomeItem(title: "Fill in\na PDF file",
                 imageName: "home_fill_widget",
                 buttonAction: { $0.openFillWidgetFlow() }),
        HomeItem(title: "Sign\na file",
                 imageName: "home_sign",
                 buttonAction: { $0.openSignFlow() }),
        HomeItem(title: "Import\nPDF",
                 imageName: "home_import_pdf",
                 buttonAction: { $0.openPdfFileFlow() }),
        HomeItem(title: "Add text",
                 imageName: "home_fill_form",
                 buttonAction: { $0.openFillFormFlow() })
    ]
    
    private let gridItemLayout: [GridItem] = {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)]
        } else {
            return [GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)]
        }
    }()
    
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
        .formSheet(item: self.$homeViewModel.pickerType) {
            self.getView(forPickerType: $0)
        }
        .formSheet(item: self.$homeViewModel.selectedSourceType) {
            self.getFileSourceImportView(forSourceType: $0)
        }
        .filePicker(isPresented: self.$homeViewModel.fileImagePickerShow,
                    fileTypes: [.image],
                    onPickedFile: {
            self.homeViewModel.urlToImageToConvert = $0
            self.homeViewModel.convert()
        })
        .filePicker(isPresented: self.$homeViewModel.filePickerShow,
                    fileTypes: K.Misc.ImportFileTypes.compactMap { $0 },
                    onPickedFile: {
            self.homeViewModel.urlToFileToConvert = $0
            self.homeViewModel.convert()
        })
        .filePicker(isPresented: self.$homeViewModel.pdfFilePickerShow,
                    fileTypes: [.pdf],
                    onPickedFile: {
            self.homeViewModel.importPdf(pdfUrl: $0)
        })
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
        .fullScreenCover(isPresented: self.$homeViewModel.scannerShow) {
            // Scanner
            ScannerView(onScannerResult: {
                self.homeViewModel.scannerShow = false
                self.homeViewModel.scannerResult = $0
            }).onDisappear { self.homeViewModel.convert() }
        }
        .fullScreenCover(isPresented: self.$homeViewModel.cameraShow) {
            // Camera for image capture
            CameraView(model: Container.shared.cameraViewModel({ uiImage in
                self.homeViewModel.cameraShow = false
                self.homeViewModel.imageToConvert = uiImage
            })).onDisappear { self.homeViewModel.convert() }
        }
        // Photo gallery picker
        .photosPicker(isPresented: self.$homeViewModel.imagePickerShow,
                      selection: self.$homeViewModel.imageSelection,
                      matching: .images)
        .fullScreenCover(isPresented: self.$homeViewModel.pdfFlowShow, onDismiss: {
            self.homeViewModel.editStartAction = nil
        }) {
            let pdfEditable = self.homeViewModel.asyncPdf.data!
            let editStartAction = self.homeViewModel.editStartAction
            PdfFlowView(pdfEditable: pdfEditable, startAction: editStartAction)
        }
        .asyncView(asyncOperation: self.$homeViewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view })
        .asyncView(asyncOperation: self.$homeViewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view })
        .alertCameraPermission(isPresented: self.$homeViewModel.cameraPermissionDeniedShow)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            self.homeViewModel.onDidBecomeActive()
        }
    }
    
    @ViewBuilder func getView(forPickerType pickerType: PickerType) -> some View {
        switch pickerType {
        case .image:
            ImportView(items: [
                ImportItem(title: "File",
                           imageName: "file",
                           callBack: { self.homeViewModel.openFileSourcePicker(sourceType: .imageFile) }),
                ImportItem(title: "Camera",
                           imageName: "camera",
                           callBack: { self.homeViewModel.openCamera() }),
                ImportItem(title: "Gallery",
                           imageName: "gallery",
                           callBack: { self.homeViewModel.openGallery() })
            ])
        case .pdf:
            self.getFileOrScanImportView(forSourceType: .pdf, startAction: nil)
        case .convert:
            self.getFileSourceImportView(forSourceType: .convertFile)
        case .formFill:
            self.getFileOrScanImportView(forSourceType: .formFill, startAction: .openFillForm)
        case .sign:
            self.getFileOrScanImportView(forSourceType: .sign, startAction: .openSignature)
        }
    }
    
    private func getFileOrScanImportView(forSourceType sourceType: SourceType, startAction: PdfEditStartAction?) -> some View {
        return ImportView(items: [
            ImportItem(title: "From existing file",
                       imageName: "file",
                       callBack: { self.homeViewModel.openFileSourcePicker(sourceType: sourceType) }),
            ImportItem(title: "Scan a file",
                       imageName: "scan",
                       callBack: { self.homeViewModel.scanPdf(startAction: startAction, directlyFromScan: false) })
        ])
    }
    
    private func getFileSourceImportView(forSourceType sourceType: SourceType) -> some View {
        ImportView(items: [
            ImportItem(title: "Google Drive",
                       imageName: "home_file_source_google",
                       callBack: { self.homeViewModel.openFilePicker(fileSource: .google, sourceType: sourceType) }),
            ImportItem(title: "Dropbox",
                       imageName: "home_file_source_dropbox",
                       callBack: { self.homeViewModel.openFilePicker(fileSource: .dropbox, sourceType: sourceType) }),
            ImportItem(title: "iCloud",
                       imageName: "home_file_source_icloud",
                       callBack: { self.homeViewModel.openFilePicker(fileSource: .icloud, sourceType: sourceType) }),
            ImportItem(title: "Files",
                       imageName: "home_file_source_files",
                       callBack: { self.homeViewModel.openFilePicker(fileSource: .files, sourceType: sourceType) })
        ])
    }
}

extension PickerType: FormSheetItem {
    var viewSize: CGSize {
        switch self {
        case .image: return CGSize(width: 400.0, height: 400.0)
        case .pdf: return CGSize(width: 400.0, height: 320.0)
        case .convert: return CGSize(width: 400.0, height: 320.0)
        case .formFill: return CGSize(width: 400.0, height: 320.0)
        case .sign: return CGSize(width: 400.0, height: 320.0)
        }
    }
}

extension SourceType: FormSheetItem {
    var viewSize: CGSize {
        CGSize(width: 400.0, height: 500.0)
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
