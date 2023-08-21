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
    
    let mostUsedItems: [HomeItem] = [
        HomeItem(title: "Image to PDF",
                 description: "Convert image to PDF in seconds",
                 imageName: "home_image_to_pdf",
                 homeAction: .imageToPdf),
        HomeItem(title: "Scan",
                 description: "Scan file from your smartphone or your camera",
                 imageName: "home_scan",
                 homeAction: .scan),
        HomeItem(title: "Read PDF",
                 description: "Read PDF improves the readability of your PDF",
                 imageName: "home_read",
                 homeAction: .readPdf)
    ]
    
    let convertItems: [HomeItem] = [
        HomeItem(title: "Word to PDF",
                 description: "Make DOC file easy to read by converting them to PDF",
                 imageName: "home_word_to_pdf",
                 homeAction: .wordToPdf),
        HomeItem(title: "Excel to PDF",
                 description: "Make EXCEL file easy to read by converting them to PDF",
                 imageName: "home_excel_to_pdf",
                 homeAction: .excelToPdf),
        HomeItem(title: "Powerpoint to PDF",
                 description: "Make PPT file easy to view by converting them to PDF",
                 imageName: "home_power_to_pdf",
                 homeAction: .powerpointToPdf)
    ]
    
    let organizeItems: [HomeItem] = [
        HomeItem(title: "Merge PDF",
                 description: "Combine pdf files in the order you want",
                 imageName: "home_merge",
                 homeAction: .merge),
        HomeItem(title: "Split PDF",
                 description: "Separate a set of pages for easy conversion into PDF",
                 imageName: "home_split",
                 homeAction: .split),
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
    
    let protectItems: [HomeItem] = [
        HomeItem(title: "Unlock PDF",
                 description: "Unlock a PDF",
                 imageName: "home_remove_password",
                 homeAction: .removePassword),
        HomeItem(title: "PDF Protector",
                 description: "Enter a password to protect your pdf",
                 imageName: "home_add_password",
                 homeAction: .addPassword)
    ]
    
    private static let standardGridItemLayout: [GridItem] = {
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
    
    private static let expandedGridItemLayout: [GridItem] = {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)]
        } else {
            return [GridItem(.flexible(), spacing: 14)]
        }
    }()
    
    var body: some View {
        ScrollView {
            VStack {
                LazyVGrid(columns: Self.expandedGridItemLayout, spacing: 14) {
                    self.section(forItems: self.mostUsedItems, sectionTitle: "Most used", aspectRatio: 2.5)
                }
                .padding(14)
                LazyVGrid(columns: Self.standardGridItemLayout, spacing: 14) {
                    self.section(forItems: self.convertItems, sectionTitle: "Convert to PDF")
                    self.section(forItems: self.organizeItems, sectionTitle: "Organize PDF")
                    self.section(forItems: self.editItems, sectionTitle: "Edit PDF")
                    self.section(forItems: self.importItems, sectionTitle: "Convert from PDF")
                    self.section(forItems: self.protectItems, sectionTitle: "Protect PDF")
                }
                .padding(14)
            }
        }
        .padding(.top, 16)
        .listStyle(.plain)
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
        .asyncView(asyncOperation: self.$viewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view })
        .asyncView(asyncOperation: self.$viewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view })
        .alertCameraPermission(isPresented: self.$viewModel.cameraPermissionDeniedShow)
        .addPasswordView(show: self.$viewModel.addPasswordShow,
                         addPasswordCallback: { self.viewModel.setPassword($0) })
        .addPasswordCompletedAlert(show: self.$viewModel.addPasswordCompletedShow,
                                   goToArchiveCallback: { self.viewModel.goToArchive() },
                                   sharePdfCallback: { self.viewModel.share() })
        .removePasswordCompletedAlert(show: self.$viewModel.removePasswordCompletedShow,
                                      goToArchiveCallback: { self.viewModel.goToArchive() },
                                      sharePdfCallback: { self.viewModel.share() })
        .showError(self.$viewModel.addPasswordError)
        .showError(self.$viewModel.removePasswordError)
        .showShareView(coordinator: self.viewModel.pdfShareCoordinator)
        .showMergeView(viewModel: self.viewModel.pdfMergeViewModel)
        .showSplitView(viewModel: self.viewModel.pdfSplitViewModel)
        .showReadView(viewModel: self.viewModel.pdfReadViewModel)
        .showUnlockView(viewModel: self.viewModel.pdfUnlockViewModel)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            self.viewModel.onDidBecomeActive()
        }
    }
    
    @ViewBuilder func section(forItems items: [HomeItem],
                              sectionTitle: String,
                              aspectRatio: CGFloat = 1.0) -> some View {
        Section {
            ForEach(items, id: \.id) { item in
                HomeItemView(title: item.title,
                             description: item.description,
                             imageName: item.imageName,
                             onButtonPressed: { self.viewModel.performHomeAction(item.homeAction) })
                .aspectRatio(aspectRatio, contentMode: .fit)
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
}

extension View {
    @ViewBuilder func addPasswordCompletedAlert(show: Binding<Bool>,
                                                goToArchiveCallback: @escaping () -> (),
                                                sharePdfCallback: @escaping () -> ()) -> some View {
        self.alert("PDF Protected!", isPresented: show, actions: {
            Button("Go to files", action: goToArchiveCallback)
            Button("Share pdf", action: sharePdfCallback)
        }, message: {
            Text("Your pdf has been successfully protected")
        })
    }
    
    @ViewBuilder func removePasswordCompletedAlert(show: Binding<Bool>,
                                                   goToArchiveCallback: @escaping () -> (),
                                                   sharePdfCallback: @escaping () -> ()) -> some View {
        self.alert("PDF Unlocked!", isPresented: show, actions: {
            Button("Go to files", action: goToArchiveCallback)
            Button("Share pdf", action: sharePdfCallback)
        }, message: {
            Text("Your pdf has been successfully unlocked")
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
