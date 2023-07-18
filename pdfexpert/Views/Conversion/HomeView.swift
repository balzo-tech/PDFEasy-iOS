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
    let description: String
    let imageName: String
    let homeAction: HomeAction
}

struct HomeView: View {
    
    @InjectedObject(\.homeViewModel) var viewModel
    
    @State private var passwordText: String = ""
    
    let convertItems: [HomeItem] = [
        HomeItem(title: "Image to PDF",
                 description: "Convert image to PDF in seconds",
                 imageName: "home_image_to_pdf",
                 homeAction: .imageToPdf),
        HomeItem(title: "Word to PDF",
                 description: "Make DOC file easy to read by converting them to PDF.",
                 imageName: "home_word_to_pdf",
                 homeAction: .wordToPdf),
        HomeItem(title: "Excel to PDF",
                 description: "Make EXCEL file easy to read by converting them to PDF.",
                 imageName: "home_excel_to_pdf",
                 homeAction: .excelToPdf),
        HomeItem(title: "Powerpoint to PDF",
                 description: "Make PPT file easy to view by converting them to PDF.",
                 imageName: "home_power_to_pdf",
                 homeAction: .powerpointToPdf),
        HomeItem(title: "Scan",
                 description: "Scan file from your smartphone or your camera",
                 imageName: "home_scan",
                 homeAction: .scan)
    ]
    
    let editItems: [HomeItem] = [
        HomeItem(title: "Sign PDF",
                 description: "Sign a document or send a signature request to others",
                 imageName: "home_sign",
                 homeAction: .sign),
        HomeItem(title: "Fill in a form",
                 description: "Fill in a form or file",
                 imageName: "home_fill_form",
                 homeAction: .formFill),
        HomeItem(title: "Add text",
                 description: "Add text on your files",
                 imageName: "home_add_text",
                 homeAction: .addText),
        HomeItem(title: "Create PDF",
                 description: "Create a pdf from scratch and edit it",
                 imageName: "home_create_pdf",
                 homeAction: .createPdf)
    ]
    
    let importItems: [HomeItem] = [
        HomeItem(title: "Import PDF",
                 description: "Import pdf from your files",
                 imageName: "home_import_pdf",
                 homeAction: .importPdf)
    ]
    
    private let gridItemLayout: [GridItem] = {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
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
                self.section(forItems: self.convertItems, sectionTitle: "Convert to PDF")
                self.section(forItems: self.editItems, sectionTitle: "Edit PDF")
                self.section(forItems: self.importItems, sectionTitle: "Convert from PDF")
            }
            .padding(14)
        }
        .listStyle(.plain)
        .background(ColorPalette.primaryBG)
        .navigationTitle("Explore")
        .onAppear() {
            self.viewModel.onAppear()
        }
        .formSheet(item: self.$viewModel.importOptionGroup) {
            self.getImportView(forImportOptionGroup: $0)
        }
        .filePicker(item: self.$viewModel.importFileOption, onPickedFile: {
            self.viewModel.processPickedFileUrl($0)
        })
        .alert("Your pdf is protected", isPresented: self.$viewModel.pdfPasswordInputShow, actions: {
            SecureField("Enter Password", text: self.$passwordText)
            Button("Confirm", action: {
                self.viewModel.importLockedPdf(password: self.passwordText)
                self.passwordText = ""
            })
            Button("Cancel", role: .cancel, action: {
                self.passwordText = ""
            })
        }, message: {
            Text("Enter the password of your pdf in order to import it.")
        })
        .fullScreenCover(isPresented: self.$viewModel.scannerShow) {
            // Scanner
            ScannerView(onScannerResult: {
                self.viewModel.convertScan(scannerResult: $0)
            })
        }
        .fullScreenCover(isPresented: self.$viewModel.cameraShow) {
            // Camera for image capture
            CameraView(model: Container.shared.cameraViewModel({ uiImage in
                self.viewModel.convertImage(uiImage: uiImage)
            }))
        }
        // Photo gallery picker
        .photosPicker(isPresented: self.$viewModel.imagePickerShow,
                      selection: self.$viewModel.imageSelection,
                      matching: .images)
        .fullScreenCover(isPresented: self.$viewModel.pdfFlowShow) {
            let pdfEditable = self.viewModel.asyncPdf.data!
            let editStartAction = self.viewModel.editStartAction
            PdfFlowView(pdfEditable: pdfEditable, startAction: editStartAction)
        }
        .asyncView(asyncOperation: self.$viewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view })
        .asyncView(asyncOperation: self.$viewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view })
        .alertCameraPermission(isPresented: self.$viewModel.cameraPermissionDeniedShow)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            self.viewModel.onDidBecomeActive()
        }
    }
    
    @ViewBuilder func section(forItems items: [HomeItem], sectionTitle: String) -> some View {
        Section {
            ForEach(items, id: \.id) { item in
                HomeItemView(title: item.title,
                             description: item.description,
                             imageName: item.imageName,
                             onButtonPressed: { self.viewModel.performHomeAction(item.homeAction) })
                .aspectRatio(1.0, contentMode: .fit)
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.clear))
                .listRowInsets(EdgeInsets())
            }
        } header: {
            Text(sectionTitle)
                .font(FontPalette.fontMedium(withSize: 18))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder func getImportView(forImportOptionGroup importOptionGroup: ImportOptionGroup) -> some View {
        ImportView(items: importOptionGroup.options.map { importOption in
            switch importOption {
            case .camera:
                return ImportItem(title: "Camera",
                                  imageName: "camera",
                                  callBack: { self.viewModel.openCamera() })
            case .gallery:
                return ImportItem(title: "Gallery",
                                  imageName: "gallery",
                                  callBack: { self.viewModel.openGallery() })
            case .scan:
                return ImportItem(title: "Scan a file",
                           imageName: "scan",
                           callBack: { self.viewModel.scanPdf() })
            case .file(let fileSource):
                switch fileSource {
                case .google:
                    return ImportItem(title: "Google Drive",
                               imageName: "home_file_source_google",
                               callBack: { self.viewModel.openFilePicker(fileSource: .google) })
                case .dropbox:
                    return ImportItem(title: "Dropbox",
                               imageName: "home_file_source_dropbox",
                               callBack: { self.viewModel.openFilePicker(fileSource: .dropbox) })
                case .icloud:
                    return ImportItem(title: "iCloud",
                               imageName: "home_file_source_icloud",
                               callBack: { self.viewModel.openFilePicker(fileSource: .icloud) })
                case .files:
                    return ImportItem(title: "Files",
                               imageName: "home_file_source_files",
                               callBack: { self.viewModel.openFilePicker(fileSource: .files) })
                }
            }
        })
    }
}

extension ImportOptionGroup: FormSheetItem {
    var viewSize: CGSize {
        switch self {
        case .image: return CGSize(width: 400.0, height: 250.0)
        case .fileAndScan: return CGSize(width: 400.0, height: 220.0)
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
