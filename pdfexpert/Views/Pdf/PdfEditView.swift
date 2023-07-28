//
//  PdfEditView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import SwiftUI
import Factory
import PhotosUI

struct PdfEditView: View {
    
    fileprivate static let cellSide: CGFloat = 80.0
    fileprivate static let selectedCellBorderWidth: CGFloat = 4.0
    
    @StateObject var viewModel: PdfEditViewModel
    @State private var showingImageInputPicker = false
    @State private var showingDeleteConfermation = false
    @State private var indexToDelete: Int? = nil
    @State private var showingSaveErrorAlert = false
    
    @State private var passwordText: String = ""
    @State private var draggedImage: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    Spacer()
                    self.pdfView
                    Spacer()
                }
                self.pageListView
                self.editButtonsView
            }
            .padding([.leading, .trailing], 16)
            self.editOptionsView
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(self.$viewModel.pdfFilename)
        .ignoresSafeArea(.keyboard)
        .background(ColorPalette.primaryBG)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { self.viewModel.editOptionListShow = true }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(ColorPalette.primaryText)
                }
            }
        }

        .onAppear(perform:self.viewModel.onAppear)
        // File picker
        .filePicker(isPresented: self.$viewModel.filePickerShow,
                    fileTypes: K.Misc.ImportFileTypesForAddPage.compactMap { $0 },
                    onPickedFile: {
            // Callback is called on modal dismiss, thus we can assign and convert in a row
            self.viewModel.urlToFileToConvert = $0
            self.viewModel.convert()
        })
        // Camera for image capture
        .fullScreenCover(isPresented: self.$viewModel.cameraShow) {
            CameraView(model: Container.shared.cameraViewModel({ uiImage in
                self.viewModel.cameraShow = false
                self.viewModel.imageToConvert = uiImage
            })).onDisappear { self.viewModel.convert() }
        }
        // Photo gallery picker
        .photosPicker(isPresented: self.$viewModel.imagePickerShow,
                      selection: self.$viewModel.imageSelection,
                      matching: .images)
        // Scanner
        .fullScreenCover(isPresented: self.$viewModel.scannerShow) {
            ScannerView(onScannerResult: {
                self.viewModel.scannerShow = false
                self.viewModel.scannerResult = $0
            }).onDisappear { self.viewModel.convert() }
        }
        .fullScreenCover(isPresented: self.$viewModel.signatureAddViewShow) {
            let inputParameter = PdfSignatureViewModel
                .InputParameter(pdfEditable: self.viewModel.pdfEditable,
                                currentPageIndex: self.viewModel.pdfCurrentPageIndex,
                                onConfirm: { self.viewModel.updatePdf(pdfEditable: $0) })
            PdfSignatureView(viewModel: Container.shared.pdfSignatureViewModel(inputParameter))
        }
        .fullScreenCover(isPresented: self.$viewModel.fillFormViewShow) {
            let inputParameter = PdfFillFormViewModel
                .InputParameter(pdfEditable: self.viewModel.pdfEditable,
                                currentPageIndex: self.viewModel.pdfCurrentPageIndex,
                                onConfirm: { self.viewModel.updatePdf(pdfEditable: $0) })
            PdfFillFormView(viewModel: Container.shared.pdfFillFormViewModel(inputParameter))
        }
        .fullScreenCover(isPresented: self.$viewModel.fillWidgetViewShow) {
            let inputParameter = PdfFillWidgetViewModel
                .InputParameter(pdfEditable: self.viewModel.pdfEditable,
                                currentPageIndex: self.viewModel.pdfCurrentPageIndex,
                                onConfirm: { self.viewModel.updatePdf(pdfEditable: $0) })
            PdfFillWidgetView(viewModel: Container.shared.pdfFillWidgetViewModel(inputParameter))
        }
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
        .asyncView(asyncOperation: self.$viewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view })
        .asyncView(asyncOperation: self.$viewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view })
        .alertCameraPermission(isPresented: self.$viewModel.cameraPermissionDeniedShow)
        .alert("Info", isPresented: self.$viewModel.missingWidgetWarningShow, actions: {
            Button("Ok", role: .cancel, action: {})
        }, message: {
            Text("Your pdf has no editable fields that you can fill in.")
        })
        .sharePdf(self.$viewModel.pdfToBeShared, applyPostProcess: true)
        .showError(self.$viewModel.pdfSaveError)
        .fullScreenCover(isPresented: self.$viewModel.monetizationShow) {
            self.getSubscriptionView(onComplete: {
                self.viewModel.onMonetizationClose()
            })
        }
        .formSheet(isPresented: self.$viewModel.editOptionListShow,
                   size: CGSize(width: 400.0, height: 150.0)) {
            self.editListView
        }
        .saveSuccessfullAlert(show: self.$viewModel.saveSuccessfulAlertShow,
                             goToArchiveCallback: { self.viewModel.goToArchive() },
                             sharePdfCallback: { self.viewModel.share() })
        .removePasswordView(show: self.$viewModel.removePasswordAlertShow,
                            removePasswordCallback: self.viewModel.removePassword)
        .addPasswordView(show: self.$viewModel.passwordTextFieldShow,
                         addPasswordCallback: { self.viewModel.setPassword($0) })
    }
    
    @ViewBuilder var pdfView: some View {
        if self.viewModel.pageImages.count > 0 {
            TabView(selection: self.$viewModel.pdfCurrentPageIndex) {
                ForEach(Array(self.viewModel.pageImages.enumerated()), id:\.offset) { (pageIndex, pageImage) in
                    ZStack {
                        Image(uiImage: pageImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        } else {
            self.emptyView
        }
    }
    
    var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("archive_empty")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
            Text("You have no pages")
                .font(FontPalette.fontRegular(withSize: 16))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            self.getDefaultButton(text: "Add a new page") {
                self.showingImageInputPicker = true
            }
            Spacer()
        }
    }
    
    var editButtonsView: some View {
        HStack {
            self.getDefaultButton(text: "Save PDF") {
                self.viewModel.save()
            }
            Button(action: { self.viewModel.share() }) {
                Image(systemName: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .font(.system(size: 16).bold())
                    .foregroundColor(ColorPalette.primaryText)
                    .contentShape(Capsule())
            }
            .frame(width: 64, height: 48)
            .background(self.defaultGradientBackground)
            .cornerRadius(10)
        }
    }
    
    var pageListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack {
                ForEach(Array(self.viewModel.pdfThumbnails.enumerated()), id: \.offset) { index, image in
                    Button(action: {
                        self.indexToDelete = index
                        self.viewModel.pdfCurrentPageIndex = index
                        self.showingDeleteConfermation = true
                    }) {
                        self.getThumbnailCell(image: image)
                            .applyCellStyle(highlight: index == self.viewModel.pdfCurrentPageIndex)
                    }
                    .actionDialog(
                        Text("Action"),
                        isPresented: self.$showingDeleteConfermation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            self.showingDeleteConfermation = false
                            withAnimation {
                                if let indexToDelete = self.indexToDelete {
                                    self.viewModel.deletePage(atIndex: indexToDelete)
                                }
                            }
                        }
                    }
                }
            }
            .padding([.trailing, .leading], Self.selectedCellBorderWidth)
        }
        .frame(height: Self.cellSide + Self.selectedCellBorderWidth)
    }
    
    var editOptionsView: some View {
        HStack {
            self.addPageButton.frame(maxWidth: .infinity)
            self.showAddSignatureButton.frame(maxWidth: .infinity)
            self.showFillFormButton.frame(maxWidth: .infinity)
            self.showFillWidgetButton.frame(maxWidth: .infinity)
        }
        .padding([.trailing, .leading], 16)
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(ColorPalette.secondaryBG)
    }
    
    var addPageButton: some View {
        Button(action: {
            self.showingImageInputPicker = true
        }) {
            self.getEditOptionView(text: "Add page", imageName: "edit_add_file")
        }
        .actionDialog(
            Text("Choose your source"),
            isPresented: self.$showingImageInputPicker,
            titleVisibility: .visible
        ) {
            Button("Photo Gallery") {
                self.viewModel.openGallery()
            }
            Button("Camera") {
                self.viewModel.openCamera()
            }
            Button("File") {
                self.viewModel.openFilePicker()
            }
            Button("Scan") {
                self.viewModel.openScanner()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    func getThumbnailCell(image: UIImage) -> some View {
        return AnyView(
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .onDrag {
                    self.draggedImage = image
                    return NSItemProvider()
                }
                .onDrop(of: [.image],
                        delegate: PdfEditDropViewDelegate(destinationItem: image,
                                                          draggedItem: self.$draggedImage,
                                                          viewModel: self.viewModel))
        )
    }
    
    var showFillWidgetButton: some View {
        Button(action: { self.viewModel.showFillWidget() }) {
            self.getEditOptionView(text: "Fill Form", imageName: "edit_fill_form")
        }
    }
    
    var showFillFormButton: some View {
        Button(action: { self.viewModel.showFillForm() }) {
            self.getEditOptionView(text: "Add text", imageName: "edit_add_text")
        }
    }
    
    var showAddSignatureButton: some View {
        Button(action: { self.viewModel.showAddSignature() }) {
            self.getEditOptionView(text: "Signature", imageName: "edit_signature")
        }
    }
    
    func getEditOptionView(text: String, imageName: String) -> some View {
        return VStack(spacing: 6) {
            Spacer()
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .foregroundColor(ColorPalette.primaryText)
            Text(text)
                .font(FontPalette.fontLight(withSize: 12))
                .foregroundColor(ColorPalette.primaryText)
            Spacer()
        }
    }
    
    @ViewBuilder var editListView: some View {
        OptionListView(title: "Edit pdf", items: [
            self.passwordOptionItem
        ])
    }
    
    var passwordOptionItem: OptionItem {
        if self.viewModel.pdfEditable.password != nil {
            return OptionItem(title: "Unlock",
                              imageName: "edit_option_password_unlock",
                              callBack: { self.viewModel.handleEditAction(.removePassword) })
        } else {
            return OptionItem(title: "Protect",
                              imageName: "edit_option_password_lock",
                              callBack: { self.viewModel.handleEditAction(.addPassword) })
        }
    }
}

fileprivate extension View {
    func applyCellStyle(highlight: Bool) -> some View {
        self
            .frame(width: PdfEditView.cellSide, height: PdfEditView.cellSide)
            .cornerRadius(16)
            .if(highlight) { view in
                view.overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ColorPalette.buttonGradientStart,
                                lineWidth: PdfEditView.selectedCellBorderWidth)
                )
            }
    }
    
    @ViewBuilder func saveSuccessfullAlert(show: Binding<Bool>,
                                          goToArchiveCallback: @escaping () -> (),
                                          sharePdfCallback: @escaping () -> ()) -> some View {
        self.alert("PDF saved!", isPresented: show, actions: {
            Button("Go to files", action: goToArchiveCallback)
            Button("Share pdf", action: sharePdfCallback)
            Button("Continue edit", action: {})
        }, message: {
            Text("Your pdf has been successfully saved")
        })
    }
}

fileprivate extension PdfEditViewModel.EditMode {
    
    var name: String {
        switch self {
        case .add: return "Add"
        case .margins: return "Margins"
        case .compression: return "Compression"
        }
    }
    
    var iconImage: Image {
        switch self {
        case .add: return Image("edit_add_file")
        case .margins: return Image("edit_margins")
        case .compression: return Image("edit_compression")
        }
    }
}

fileprivate extension MarginsOption {
    
    var iconImage: some View {
        let insets: EdgeInsets = {
            switch self {
            case .noMargins: return EdgeInsets(top: 4, leading: 3, bottom: 4, trailing: 3)
            case .mediumMargins: return EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6)
            case .heavyMargins: return EdgeInsets(top: 12, leading: 9, bottom: 12, trailing: 9)
            }
        }()
        return ColorPalette.fourthText
            .cornerRadius(4)
            .padding(insets)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(ColorPalette.primaryText, lineWidth: 2))
    }
}

struct PdfEditView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            if let pdfEditable = K.Test.DebugPdfEditable {
                let inputParameter = PdfEditViewModel.InputParameter(pdfEditable: pdfEditable,
                                                                     startAction: nil,
                                                                     shouldShowCloseWarning: .constant(true))
                AnyView(PdfEditView(viewModel: Container.shared.pdfEditViewModel(inputParameter)))
            } else {
                AnyView(Spacer())
            }
        }
    }
}

fileprivate struct PdfEditDropViewDelegate: DropDelegate {
    
    let destinationItem: UIImage
    @Binding var draggedItem: UIImage?
    var viewModel: PdfEditViewModel
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Swap Items
        if let draggedItem {
            let fromIndex = self.viewModel.pdfThumbnails.firstIndex(of: draggedItem)
            if let fromIndex {
                let toIndex = self.viewModel.pdfThumbnails.firstIndex(of: self.destinationItem)
                if let toIndex, fromIndex != toIndex {
                    self.viewModel.handlePageReordering(fromIndex: fromIndex, toIndex: toIndex)
                }
            }
        }
    }
}
