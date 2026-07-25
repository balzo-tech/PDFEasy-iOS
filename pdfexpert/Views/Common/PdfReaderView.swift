//
//  PdfReaderView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/08/23.
//

import SwiftUI
import Factory

struct PdfReaderView: View {
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: PdfReaderViewModel
    
    var body: some View {
        NavigationStack {
            self.contentView
            .padding(16)
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(self.viewModel.filename)
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                self.viewModel.requestClose(onClose: { self.dismiss() })
            })
            .alert(String(localized: "Unsaved changes"),
                   isPresented: self.$viewModel.unsavedChangesAlertShow,
                   actions: {
                Button(String(localized: "Save")) {
                    if self.viewModel.save() {
                        self.dismiss()
                    }
                }
                Button(String(localized: "Discard"), role: .destructive) {
                    self.viewModel.discardChanges()
                    self.dismiss()
                }
                Button(String(localized: "Cancel"), role: .cancel, action: {})
            }, message: {
                Text("Do you want to save the annotations you added?")
            })
            .alert(String(localized: "Error"), isPresented: self.$viewModel.saveErrorShow, actions: {
                Button("Ok", role: .cancel, action: {})
            }, message: {
                Text("The annotations could not be saved.")
            })
            .showSubscriptionView(self.$viewModel.monetizationShow,
                                  onComplete: { self.viewModel.onMonetizationClose() })
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    self.toolbar
                }
            }
            .fullScreenCover(isPresented: self.$viewModel.showPageSelection) {
                PdfPageSelectionView(pageIndex: self.$viewModel.pageIndex,
                                     title: self.viewModel.filename,
                                     pageThumbnails: self.viewModel.pageThumbnails.data ?? [])
            }
            .fullScreenCover(isPresented: self.$viewModel.showPageImages) {
                PdfImageViewerView(pageIndex: self.viewModel.pageIndex,
                                   images: self.viewModel.pageImages.data ?? [])
            }
        }
        .background(ColorPalette.primaryBG)
        .onAppear(perform: self.viewModel.onAppear)
        .asyncView(asyncItem: self.$viewModel.pageThumbnails)
        .asyncView(asyncItem: self.$viewModel.pageImages)
    }
    
    @ViewBuilder var contentView: some View {
        VStack(spacing: 16) {
            if self.viewModel.textMode {
                self.textView
            } else {
                self.standardView
            }
            if self.viewModel.annotationMode {
                self.annotationToolbar
            }
            self.pageCounter(currentPageIndex: self.viewModel.pageIndex,
                             totalPages: self.viewModel.pageCount)
        }
    }

    /// Markup controls: type, colour, apply-to-selection and undo.
    @ViewBuilder var annotationToolbar: some View {
        VStack(spacing: 12) {
            Text("Select some text, then apply the markup.")
                .font(forCategory: .caption1)
                .foregroundColor(ColorPalette.thirdText)

            HStack(spacing: 16) {
                ForEach(PdfAnnotationType.allCases) { type in
                    Button(action: { self.viewModel.annotationType = type }) {
                        Image(systemName: type.systemImageName)
                            .foregroundColor(self.viewModel.annotationType == type
                                             ? ColorPalette.buttonGradientStart
                                             : ColorPalette.primaryText)
                    }
                    .accessibilityLabel(type.displayName)
                }

                Divider().frame(height: 20)

                ForEach(Array(PdfReaderViewModel.annotationColors.enumerated()), id: \.offset) { _, color in
                    Button(action: { self.viewModel.annotationColor = color }) {
                        Circle()
                            .fill(color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(ColorPalette.primaryText,
                                                lineWidth: self.viewModel.annotationColor == color ? 2 : 0)
                            )
                    }
                }
            }

            HStack(spacing: 16) {
                Button(action: { self.viewModel.annotateSelection() }) {
                    Text("Apply to selection")
                        .font(forCategory: .button)
                        .foregroundColor(ColorPalette.buttonGradientStart)
                }
                Button(action: { self.viewModel.undoLastAnnotation() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(self.viewModel.canUndoAnnotation
                                         ? ColorPalette.primaryText
                                         : ColorPalette.thirdText)
                }
                .disabled(!self.viewModel.canUndoAnnotation)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(ColorPalette.secondaryBG)
        .cornerRadius(12)
    }
    
    var textView: some View {
        TabView(selection: self.$viewModel.pageIndex) {
            ForEach(Array(self.viewModel.pages.enumerated()), id:\.offset) { _, page in
                if let page = page {
                    ScrollView {
                        Text(page)
                    }
                } else {
                    Text("No text available on this page")
                        .font(forCategory: .body1)
                        .foregroundColor(ColorPalette.primaryText)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(ColorPalette.primaryBG)
    }
    
    var standardView: some View {
        PdfKitViewBinder(
            pdfView: self.$viewModel.pdfView,
            singlePage: false,
            pageMargins: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            backgroundColor: UIColor(ColorPalette.primaryBG),
            usePaginator: true
        )
    }
    
    @ViewBuilder var toolbar: some View {
        if self.viewModel.hasUnsavedAnnotations {
            Button(action: { self.viewModel.save() }) {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(ColorPalette.primaryText)
            }
            .accessibilityLabel(String(localized: "Save"))
        }
        Button(action: { self.viewModel.toggleAnnotationMode() }) {
            Image(systemName: "highlighter")
                .foregroundColor(self.viewModel.annotationMode
                                 ? ColorPalette.buttonGradientStart
                                 : ColorPalette.primaryText)
        }
        .accessibilityLabel(String(localized: "Annotate"))
        Button(action: { self.viewModel.switchTextMode() }) {
            Image(systemName: self.viewModel.textMode ? "doc" : "doc.text")
                .foregroundColor(ColorPalette.primaryText)
        }
        Button(action: { self.viewModel.presentPageImages() }) {
            Image(systemName: "photo.stack")
                .foregroundColor(ColorPalette.primaryText)
        }
        Button(action: { self.viewModel.presentPageSelection() }) {
            Image("page_selection")
                .foregroundColor(ColorPalette.primaryText)
        }
    }
}

extension View {
    func showPdfReaderView(item: Binding<Pdf?>, onSaved: ((Pdf) -> Void)? = nil) -> some View {
        self.fullScreenCover(item: item) { pdf in
            let params = PdfReaderViewModel.Params(pdf: pdf, onSaved: onSaved)
            let viewModel = Container.shared.pdfReaderViewModel(params)
            PdfReaderView(viewModel: viewModel)
        }
    }
}

struct PdfReaderView_Previews: PreviewProvider {
    
    static var previews: some View {
        Color.white
            .showPdfReaderView(item: .constant(K.Test.DebugPdf))
    }
}
