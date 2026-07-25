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
    var isSystemImage: Bool = false
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
                 homeAction: .powerpointToPdf),
        HomeItem(title: String(localized: "Web page to PDF"),
                 description: String(localized: "Save any web page as a PDF document"),
                 imageName: "globe",
                 isSystemImage: true,
                 homeAction: .webToPdf),
        HomeItem(title: String(localized: "Markdown to PDF"),
                 description: String(localized: "Turn Markdown text into a formatted PDF"),
                 imageName: "chevron.left.forwardslash.chevron.right",
                 isSystemImage: true,
                 homeAction: .markdownToPdf)
    ]
    
    // "Repair PDF" uploads the document to the Stirling service, so — like the other
    // online tools — it is only offered when that service is available.
    var organizeItems: [HomeItem] {
        var items: [HomeItem] = [
            HomeItem(title: "Merge PDF",
                     description: "Combine pdf files in the order you want",
                     imageName: "home_merge",
                     homeAction: .merge),
            HomeItem(title: "Split PDF",
                     description: "Separate a set of pages for easy conversion into PDF",
                     imageName: "home_split",
                     homeAction: .split),
            HomeItem(title: String(localized: "Rotate PDF"),
                     description: String(localized: "Rotate one or all pages of your PDF"),
                     imageName: "rotate.right",
                     isSystemImage: true,
                     homeAction: .rotatePdf),
            HomeItem(title: String(localized: "Extract pages"),
                     description: String(localized: "Extract selected pages into a single new PDF"),
                     imageName: "doc.on.doc",
                     isSystemImage: true,
                     homeAction: .extractPages),
            HomeItem(title: String(localized: "Remove blank pages"),
                     description: String(localized: "Find and delete the empty pages of your PDF"),
                     imageName: "rectangle.dashed",
                     isSystemImage: true,
                     homeAction: .removeBlankPages),
        ]
        if Container.shared.stirlingApiManager().isAvailable {
            items.append(
                HomeItem(title: String(localized: "Repair PDF"),
                         description: String(localized: "Fix a corrupted or damaged PDF file"),
                         imageName: "wrench.and.screwdriver",
                         isSystemImage: true,
                         homeAction: .repairPdf)
            )
        }
        return items
    }
        
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
                 homeAction: .createPdf),
        HomeItem(title: String(localized: "Make Searchable (OCR)"),
                 description: String(localized: "Recognize text in scanned pages and make your PDF searchable"),
                 imageName: "home_ocr",
                 homeAction: .ocr),
        HomeItem(title: String(localized: "Page numbers"),
                 description: String(localized: "Add page numbers to every page of your PDF"),
                 imageName: "textformat.123",
                 isSystemImage: true,
                 homeAction: .pageNumbers),
        HomeItem(title: String(localized: "Watermark"),
                 description: String(localized: "Stamp a text watermark across every page"),
                 imageName: "drop.halffull",
                 isSystemImage: true,
                 homeAction: .watermark),
        HomeItem(title: String(localized: "Invert colors"),
                 description: String(localized: "Invert the colors of your PDF for comfortable reading"),
                 imageName: "circle.lefthalf.filled",
                 isSystemImage: true,
                 homeAction: .invertColors)
    ]
    
    // Built dynamically: the online-conversion tiles (PDF → Word / PowerPoint /
    // Excel) upload the document to the Stirling service, so they are only offered
    // when that service is available (remote-config kill switch + key). Reading
    // availability here means a config change is reflected on the next Home render.
    var importItems: [HomeItem] {
        var items: [HomeItem] = [
            HomeItem(title: "Import PDF",
                     description: "Import pdf from your files",
                     imageName: "home_import_pdf",
                     homeAction: .importPdf),
            HomeItem(title: String(localized: "Export PDF as…"),
                     description: String(localized: "Export your PDF as images, text, or its embedded images"),
                     imageName: "square.and.arrow.up.on.square",
                     isSystemImage: true,
                     homeAction: .exportPdf)
        ]
        if Container.shared.stirlingApiManager().isAvailable {
            items.append(contentsOf: [
                HomeItem(title: String(localized: "PDF to Word"),
                         description: String(localized: "Convert your PDF into an editable Word document (.docx)"),
                         imageName: "doc.text",
                         isSystemImage: true,
                         homeAction: .pdfToWord),
                HomeItem(title: String(localized: "PDF to PowerPoint"),
                         description: String(localized: "Turn your PDF into an editable PowerPoint presentation (.pptx)"),
                         imageName: "rectangle.on.rectangle",
                         isSystemImage: true,
                         homeAction: .pdfToPowerpoint),
                HomeItem(title: String(localized: "PDF to Excel"),
                         description: String(localized: "Extract your PDF tables into a spreadsheet (.csv)"),
                         imageName: "tablecells",
                         isSystemImage: true,
                         homeAction: .pdfToExcel),
                HomeItem(title: String(localized: "PDF/A"),
                         description: String(localized: "Convert your PDF to PDF/A for long-term archiving"),
                         imageName: "checkmark.seal",
                         isSystemImage: true,
                         homeAction: .pdfToPdfa)
            ])
        }
        return items
    }

    // "Sanitize PDF" uploads the document to the Stirling service, so — like the other
    // online tools — it is only offered when that service is available.
    var protectItems: [HomeItem] {
        var items: [HomeItem] = [
            HomeItem(title: "Unlock PDF",
                     description: "Unlock a PDF",
                     imageName: "home_remove_password",
                     homeAction: .removePassword),
            HomeItem(title: "PDF Protector",
                     description: "Enter a password to protect your pdf",
                     imageName: "home_add_password",
                     homeAction: .addPassword),
            HomeItem(title: String(localized: "Flatten PDF"),
                     description: String(localized: "Bake annotations and form fields into the page"),
                     imageName: "square.stack.3d.down.forward",
                     isSystemImage: true,
                     homeAction: .flattenPdf),
            HomeItem(title: String(localized: "PDF permissions"),
                     description: String(localized: "Restrict printing and copying on a copy of your PDF"),
                     imageName: "hand.raised",
                     isSystemImage: true,
                     homeAction: .pdfPermissions)
        ]
        if Container.shared.stirlingApiManager().isAvailable {
            items.append(
                HomeItem(title: String(localized: "Sanitize PDF"),
                         description: String(localized: "Remove scripts and embedded content from your PDF"),
                         imageName: "shield.checkered",
                         isSystemImage: true,
                         homeAction: .sanitizePdf)
            )
        }
        return items
    }
    
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
        // Camera / scanner modal flows, driven by a single activeSheet state machine.
        .fullScreenCover(item: self.$viewModel.activeSheet) { sheet in
            switch sheet {
            case .scanner:
                ScannerView(onScannerResult: {
                    self.viewModel.convertScan(scannerResult: $0)
                })
            case .camera:
                CameraView(model: Container.shared.cameraViewModel({ uiImage in
                    self.viewModel.convertImage(uiImage: uiImage)
                }))
            }
        }
        // Photo gallery picker
        .photosPicker(isPresented: self.$viewModel.imagePickerShow,
                      selection: self.$viewModel.imageSelection,
                      matching: .images)
        .asyncView(asyncOperation: self.$viewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view })
        .asyncView(asyncOperation: self.$viewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view })
        .showOfficeImportAlerts(coordinator: self.viewModel.officeImportCoordinator)
        .showWebImportView(viewModel: self.viewModel.pdfWebImportViewModel)
        .showMarkdownImportView(viewModel: self.viewModel.pdfMarkdownImportViewModel)
        .showPermissionsView(viewModel: self.viewModel.pdfPermissionsViewModel)
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
        .showExtractView(viewModel: self.viewModel.pdfExtractViewModel)
        .showExportView(viewModel: self.viewModel.pdfExportViewModel)
        .showConvertView(viewModel: self.viewModel.pdfConvertViewModel)
        .showAdvancedToolView(viewModel: self.viewModel.pdfAdvancedToolViewModel)
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
                             isSystemImage: item.isSystemImage,
                             onButtonPressed: { self.viewModel.performHomeAction(item.homeAction) })
                .aspectRatio(aspectRatio, contentMode: .fit)
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.clear))
                .listRowInsets(EdgeInsets())
            }
        } header: {
            Text(sectionTitle)
                .font(forCategory: .headline)
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
