//
//  PdfEditView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import SwiftUI
import Factory

struct PdfEditView: View {
    
    @StateObject var pdfEditViewModel: PdfEditViewModel
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
                Button(action: { self.pdfEditViewModel.save() }) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(ColorPalette.primaryText)
                }
            }
        }
        .alert("Error",
               isPresented: .constant(self.pdfEditViewModel.pdfSaveError != nil),
               presenting: self.pdfEditViewModel.pdfSaveError,
               actions: { pdfSaveError in
            Button("OK") {
                self.pdfEditViewModel.pdfSaveError = nil
                switch pdfSaveError {
                case .unknown: break
                case .saveFailed: self.pdfEditViewModel.viewPdf()
                case .noPages: break
                }
            }
            if pdfSaveError == .saveFailed {
                Button("Cancel") { self.pdfEditViewModel.pdfSaveError = nil }
            }
        }, message: { pdfSaveError in
            Text(pdfSaveError.errorDescription ?? "")
        })
    }
    
    var pdfView: some View {
        if let pdfCurrentPageIndex = self.pdfEditViewModel.pdfCurrentPageIndex {
            return AnyView(
                PdfKitView(
                    pdfDocument: self.pdfEditViewModel.pdfEditable.pdfDocument,
                    singlePage: true,
                    pageMargins: nil,
                    currentPage: pdfCurrentPageIndex,
                    backgroundColor: UIColor(ColorPalette.primaryBG)
                )
            )
        } else {
            return AnyView(
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
            )
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
                        self.pdfEditViewModel.openGallery()
                    }
                    Button("Camera") {
                        self.pdfEditViewModel.openCamera()
                    }
                    Button("File") {
                        self.pdfEditViewModel.openFileImagePicker()
                    }
                }
                ForEach(Array(self.pdfEditViewModel.pdfThumbnails.enumerated()), id: \.offset) { index, image in
                    Button(action: {
                        self.indexToDelete = index
                        self.pdfEditViewModel.pdfCurrentPageIndex = index
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
                                    self.pdfEditViewModel.deletePage(atIndex: indexToDelete)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 80)
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
            )
        } else {
            return AnyView(ColorPalette.primaryText)
        }
    }
}

fileprivate extension View {
    func applyCellStyle() -> some View {
        self
            .aspectRatio(1.0, contentMode: .fill)
            .cornerRadius(16)
    }
}

struct PdfEditView_Previews: PreviewProvider {
    static var previews: some View {
        if let pdfEditable = K.Test.DebugPdfEditable {
            AnyView(PdfEditView(pdfEditViewModel: Container.shared.pdfEditViewModel(pdfEditable)))
        } else {
            AnyView(Spacer())
        }
        
    }
}
