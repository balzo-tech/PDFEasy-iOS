//
//  PdfEditView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import SwiftUI
import Factory
import PhotosUI
import WeScan

struct PdfEditView: View {
    
    fileprivate static let cellSide: CGFloat = 80.0
    
    @StateObject var viewModel: PdfEditViewModel
    @State private var showingImageInputPicker = false
    @State private var showingDeleteConfermation = false
    @State private var indexToDelete: Int? = nil
    @State private var showingSaveErrorAlert = false
    
    var body: some View {
        VStack(spacing: 30) {
            self.pdfView
            self.editView
            self.editOptionsView
        }
        .padding([.leading, .trailing], 16)
        .background(ColorPalette.primaryBG)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                self.showAddSignatureButton
                self.saveButton
            }
        }
        .alert("Error",
               isPresented: .constant(self.viewModel.pdfSaveError != nil),
               presenting: self.viewModel.pdfSaveError,
               actions: { pdfSaveError in
            Button("OK") {
                self.viewModel.pdfSaveError = nil
                switch pdfSaveError {
                case .unknown: break
                case .saveFailed: self.viewModel.viewPdf()
                case .noPages: break
                }
            }
            if pdfSaveError == .saveFailed {
                Button("Cancel") { self.viewModel.pdfSaveError = nil }
            }
        }, message: { pdfSaveError in
            Text(pdfSaveError.errorDescription ?? "")
        })
        .fullScreenCover(isPresented: self.$viewModel.monetizationShow) {
            self.getSubscriptionView(onComplete: {
                self.viewModel.monetizationShow = false
            })
        }
        // File picker for images
        .fullScreenCover(isPresented: self.$viewModel.fileImagePickerShow) {
            FilePicker(fileTypes: [.image],
                       onPickedFile: {
                // Callback is called on modal dismiss, thus we can assign and convert in a row
                self.viewModel.urlToImageToConvert = $0
                self.viewModel.convert()
            })
        }
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
        // WeScan scanner
        .fullScreenCover(isPresented: self.$viewModel.scannerShow) {
            ScannerView(onScannerResult: {
                self.viewModel.scannerShow = false
                self.viewModel.scannerResult = $0
            }).onDisappear { self.viewModel.convert() }
        }
        .fullScreenCover(isPresented: self.$viewModel.signatureAddViewShow) {
            let inputParameter = PdfSignatureViewModel
                .InputParameter(pdfEditable: self.viewModel.pdfEditable,
                                onConfirm: { self.viewModel.updatePdfWithSignatures(pdfEditable: $0) })
            PdfSignatureView(viewModel: Container.shared.pdfSignatureViewModel(inputParameter))
        }
        .asyncView(asyncOperation: self.$viewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view.loop(autoReverse: true) })
        .asyncView(asyncOperation: self.$viewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view.loop(autoReverse: true) })
        .alertCameraPermission(isPresented: self.$viewModel.cameraPermissionDeniedShow)
    }
    
    var pdfView: some View {
        GeometryReader { geometry in
            if let image = self.viewModel.getCurrentPageImage(withSize: geometry.size) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width/2, y: geometry.size.height/2)
            } else {
                self.emptyView
            }
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
            Spacer()
        }
    }
    
    @ViewBuilder var editView: some View {
        VStack {
            Spacer()
            switch self.viewModel.editMode {
            case .add: self.pageListView
            case .margins: self.marginOptionsView
            case .compression: self.compressionSliderView
            }
            Spacer()
        }.frame(height: 88)
    }
    
    var editOptionsView: some View {
        HStack {
            ForEach(PdfEditViewModel.EditMode.allCases, id:\.self) { editMode in
                Button(action: { self.viewModel.editMode = editMode }) {
                    VStack {
                        editMode.iconImage
                            .foregroundColor(self.viewModel.editMode == editMode
                                             ? ColorPalette.buttonGradientStart
                                             : ColorPalette.fourthText)
                        Text(editMode.name)
                            .foregroundColor(ColorPalette.primaryText)
                            .font(FontPalette.fontRegular(withSize: 14))
                    }.frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    var pageListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack {
                Button(action: {
                    self.showingImageInputPicker = true
                }) {
                    self.addThumbnailCell
                        .applyCellStyle()
                }
                .confirmationDialog(
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
                        self.viewModel.openFileImagePicker()
                    }
                    Button("Scan") {
                        self.viewModel.openScanner()
                    }
                }
                ForEach(Array(self.viewModel.pdfThumbnails.enumerated()), id: \.offset) { index, image in
                    Button(action: {
                        self.indexToDelete = index
                        self.viewModel.pdfCurrentPageIndex = index
                        self.showingDeleteConfermation = true
                    }) {
                        self.getThumbnailCell(image: image)
                            .applyCellStyle()
                    }
                    .confirmationDialog(
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
        }
        .frame(height: Self.cellSide)
    }
    
    var addThumbnailCell: some View {
        GeometryReader { geometry in
            Image(systemName: "plus.circle.fill")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(ColorPalette.thirdText)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
        }
        .background(ColorPalette.primaryText)
    }
    
    func getThumbnailCell(image: UIImage?) -> some View {
        if let image = image {
            return AnyView(
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
        } else {
            return AnyView(ColorPalette.primaryText)
        }
    }
    
    var marginOptionsView: some View {
        HStack(spacing: 16) {
            ForEach(MarginsOption.allCases, id:\.self) { marginsOption in
                Button(action: { self.viewModel.marginsOption = marginsOption }) {
                    marginsOption.iconImage
                        .padding(EdgeInsets(top: 13, leading: 9, bottom: 13, trailing: 9))
                        .frame(width: 60, height: 88)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(
                            self.viewModel.marginsOption == marginsOption
                            ? ColorPalette.buttonGradientStart
                            : .clear, lineWidth: 2))
                }
            }
        }
    }
    
    var compressionSliderView: some View {
        HStack(spacing: 12) {
            Text("0")
                .foregroundColor(ColorPalette.primaryText)
                .font(FontPalette.fontRegular(withSize: 14))
            Slider(value: self.$viewModel.compression)
                .tint(ColorPalette.buttonGradientStart)
            Text("100")
                .foregroundColor(ColorPalette.primaryText)
                .font(FontPalette.fontRegular(withSize: 14))
        }
        .padding([.leading, .trailing], 16)
    }
    
    var showAddSignatureButton: some View {
        Button(action: { self.viewModel.showAddSignature() }) {
            Image("signature")
        }
    }
    
    var saveButton: some View {
        Button(action: { self.viewModel.save() }) {
            Image(systemName: "square.and.arrow.down")
                .foregroundColor(ColorPalette.primaryText)
                .font(.system(size: 16).bold())
        }
    }
}

fileprivate extension View {
    func applyCellStyle() -> some View {
        self
            .frame(width: PdfEditView.cellSide, height: PdfEditView.cellSide)
            .cornerRadius(16)
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
        if let pdfEditable = K.Test.DebugPdfEditable {
            AnyView(PdfEditView(viewModel: Container.shared.pdfEditViewModel(pdfEditable)))
        } else {
            AnyView(Spacer())
        }
    }
}
