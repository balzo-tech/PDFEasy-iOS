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
    
    @StateObject var viewModel: PdfEditViewModel
    @State private var showingImageInputPicker = false
    @State private var showingDeleteConfermation = false
    @State private var indexToDelete: Int? = nil
    @State private var showingSaveErrorAlert = false
    
    var body: some View {
        VStack(spacing: 30) {
            self.pdfView
            self.pageListView
        }
        .padding([.leading, .trailing], 16)
        .background(ColorPalette.primaryBG)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { self.viewModel.save() }) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(ColorPalette.primaryText)
                }
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
        .asyncView(asyncOperation: self.$viewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view.loop(autoReverse: true) })
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
}

fileprivate extension View {
    func applyCellStyle() -> some View {
        self
            .frame(width: PdfEditView.cellSide, height: PdfEditView.cellSide)
            .cornerRadius(16)
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
