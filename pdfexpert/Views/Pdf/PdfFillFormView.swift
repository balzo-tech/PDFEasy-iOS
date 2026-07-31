//
//  PdfFillFormView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 26/05/23.
//

import SwiftUI
import Factory
import PDFKit

struct PdfFillFormView: View {
    
    @StateObject var viewModel: PdfFillFormViewModel
    @Environment(\.dismiss) var dismiss
    @State var showCancelWarningDialog: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Spacer()
                    GeometryReader { parentGeometryReader in
                        TabView(selection: self.$viewModel.pageIndex) {
                            ForEach(Array(self.viewModel.pageImages.enumerated()), id:\.offset) { (pageIndex, page) in
                                GeometryReader { geometryReader in
                                    HStack {
                                        Spacer()
                                        ZStack {
                                            Image(uiImage: page)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .ignoresSafeArea(.keyboard)
                                            self.getAnnotationViews(forPageIndex: pageIndex)
                                                .ignoresSafeArea(.keyboard)
                                        }
                                        Spacer()
                                    }
                                    .onTapGesture {
                                        self.viewModel.tapOnPdfView(positionInView: $0,
                                                                    pageIndex: pageIndex,
                                                                    pageViewSize: geometryReader.size)
                                    }
                                    .position(x: geometryReader.size.width / 2, y: geometryReader.size.height / 2)
                            // Report the size as soon as the page is on screen.
                            // It used to be learned from the first tap, which is
                            // too late for an element the editor asked to open.
                            .onAppear {
                                self.viewModel.onPageAppeared(size: geometryReader.size,
                                                              pageIndex: pageIndex)
                            }
                                }
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .position(x: parentGeometryReader.size.width / 2, y: parentGeometryReader.size.height / 2)
                        .frame(width: parentGeometryReader.size.width,
                               height: parentGeometryReader.size.height)
                        .overlay(alignment: .top) {
                            if self.viewModel.pageImages.count > 1 {
                                Text("\(self.viewModel.pageIndex + 1) of \(self.viewModel.pageImages.count)")
                                    .font(forCategory: .caption1)
                                    .foregroundStyle(ColorPalette.textPrimary)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, 6)
                                    .floatingGlassCapsule(interactive: false)
                                    .padding(.top, DS.Spacing.xs)
                                    .animation(DS.Motion.quick, value: self.viewModel.pageIndex)
                            }
                        }
                    }
                    .background(ColorPalette.primaryBG)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("Tap where you wish to add text")
                    Spacer()
                }
                // What used to be here was the page counter, which says nothing
                // you cannot see and left colour, face and size unreachable. The
                // counter is a badge over the page now, like the editor's.
                TextStyleBar(style: self.$viewModel.style,
                             isEditing: self.viewModel.editedPageIndex != nil,
                             onGrow: { self.viewModel.scaleEditedText(by: 1.2) },
                             onShrink: { self.viewModel.scaleEditedText(by: 1 / 1.2) },
                             onDelete: { self.viewModel.onDeleteAnnotationPressed() })
                Spacer().frame(height: DS.Spacing.md)
                self.getDefaultButton(text: String(localized: "Finish"), onButtonPressed: {
                    self.viewModel.onConfirmButtonPressed()
                    self.dismiss()
                })
                Spacer().frame(height: DS.Spacing.xl)
            }
            .padding([.leading, .trailing], 16)
            .ignoresSafeArea(.keyboard)
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                if self.viewModel.unsavedChangesExist {
                    self.showCancelWarningDialog = true
                } else {
                    self.dismiss()
                }
            })
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { self.viewModel.onSuggestedFieldsButtonPressed() }) {
                        Image("suggested_fields")
                            .foregroundColor(ColorPalette.primaryText)
                    }
                }
            })
            .alert("Are you sure?",
                   isPresented: self.$showCancelWarningDialog,
                   actions: {
                Button("No", role: .cancel, action: {})
                Button("Yes", role: .destructive, action: {
                    self.dismiss()
                })
            }, message: { Text("If you quit, you will lose the changes you have just made.") })
            .background(ColorPalette.primaryBG)
        }
        .onAppear(perform: self.viewModel.onAppear)
        .fullScreenCover(isPresented: self.$viewModel.showSuggestedFields) {
            SuggestedFieldsFormView()
        }
    }
    
    @ViewBuilder func getAnnotationViews(forPageIndex pageIndex: Int) -> some View {
        ForEach(self.viewModel.getAnnotations(forPageIndex: pageIndex), id:\.self) { pageAnnotation in
            self.getView(forAnnotation: pageAnnotation)
        }
        if self.viewModel.editedPageIndex == pageIndex {
            TextResizableView(data: self.$viewModel.currentTextResizableViewData,
                              fontName: self.viewModel.style.font.fontName,
                              fontColor: self.viewModel.style.color.uiColor,
                              color: ColorPalette.accent,
                              borderWidth: 1.5,
                              minSize: CGSize(width: 5, height: 5),
                              handleSize: 28,
                              handleTapSize: 50,
                              suggestedWords: self.viewModel.suggestedFields?.fields ?? [],
                              deleteCallback: self.viewModel.onDeleteAnnotationPressed)
        }
    }
    
    @ViewBuilder func getView(forAnnotation annotation: PDFAnnotation) -> some View {
        if let page = annotation.page {
            GeometryReader { geometryReader in
                let annotationBounds = self.viewModel.convertRect(annotation.verticalCenteredTextBounds,
                                                                        viewSize: geometryReader.size,
                                                                        fromPage: page)
                let position = CGPoint(x: annotationBounds.origin.x + annotationBounds.size.width / 2,
                                       y: annotationBounds.origin.y + annotationBounds.size.height / 2)
                Text(annotation.contents ?? "")
                    // The face the annotation was written with, not the default:
                    // once text can be set in a serif or a handwriting face, a
                    // preview that ignores it is showing the wrong document.
                    .font(Font(UIFont.font(named: annotation.font?.familyName
                                           ?? K.Misc.DefaultAnnotationTextFontName,
                                           fitting: annotation.contents ?? "",
                                           into: annotationBounds.size,
                                           with: [:],
                                           options: [])))
                    .foregroundColor(Color(annotation.fontColor ?? .black))
                    .frame(width: annotationBounds.width, height: annotationBounds.height)
                    // See the note in `PdfSignatureView`: the outline is what tells
                    // the user this text is still editable.
                    .overlay {
                        Rectangle()
                            .strokeBorder(ColorPalette.accent.opacity(0.7),
                                          style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    .frame(width: annotationBounds.width, height: annotationBounds.height)
                    .position(position)
            }
        }
    }
}

struct PdfFillFormView_Previews: PreviewProvider {
    static var previews: some View {
        if let pdf = K.Test.DebugPdf {
            let inputParameter = PdfFillFormViewModel.InputParameter(pdf: pdf,
                                                                     currentPageIndex: 0,
                                                                     onConfirm: { _ in })
            AnyView(PdfFillFormView(viewModel: Container.shared.pdfFillFormViewModel(inputParameter)))
        } else {
            AnyView(Spacer())
        }
    }
}
