//
//  PdfReaderView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/08/23.
//
//  Reading is the whole point of this screen, so the page runs edge to edge and
//  every control floats above it in glass: the page counter, the markup bar and
//  the toolbar.
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
            .background(ColorPalette.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(self.viewModel.filename)
            .addSystemCloseButton(color: ColorPalette.textPrimary, onPress: {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(DS.Motion.snappy) {
                            self.viewModel.toggleAnnotationMode()
                        }
                    } label: {
                        Label("Annotate", systemImage: "highlighter")
                    }
                    .tint(self.viewModel.annotationMode ? ColorPalette.accent : ColorPalette.textPrimary)
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    self.readerMenu
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
        .onAppear(perform: self.viewModel.onAppear)
        .asyncView(asyncItem: self.$viewModel.pageThumbnails)
        .asyncView(asyncItem: self.$viewModel.pageImages)
    }

    @ViewBuilder var contentView: some View {
        ZStack(alignment: .bottom) {
            Group {
                if self.viewModel.textMode {
                    self.textView
                } else {
                    self.standardView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: DS.Spacing.xs) {
                if self.viewModel.annotationMode {
                    self.annotationToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                self.pageCounterBadge
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)
        }
    }

    private var pageCounterBadge: some View {
        Text("\(self.viewModel.pageIndex + 1) of \(self.viewModel.pageCount)")
            .font(forCategory: .caption1)
            .foregroundStyle(ColorPalette.textPrimary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 6)
            .floatingGlassCapsule(interactive: false)
    }

    /// Markup controls: type, colour, apply-to-selection and undo.
    @ViewBuilder var annotationToolbar: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("Select some text, then apply the markup.")
                .font(forCategory: .caption1)
                .foregroundStyle(ColorPalette.textSecondary)

            HStack(spacing: DS.Spacing.md) {
                ForEach(PdfAnnotationType.allCases) { type in
                    Button(action: {
                        withAnimation(DS.Motion.quick) { self.viewModel.annotationType = type }
                    }) {
                        Image(systemName: type.systemImageName)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(self.viewModel.annotationType == type
                                             ? ColorPalette.accent
                                             : ColorPalette.textPrimary)
                            .frame(width: 36, height: 32)
                    }
                    .accessibilityLabel(type.displayName)
                }

                Divider().frame(height: 22)

                ForEach(Array(PdfReaderViewModel.annotationColors.enumerated()), id: \.offset) { _, color in
                    Button(action: {
                        withAnimation(DS.Motion.quick) { self.viewModel.annotationColor = color }
                    }) {
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Circle().stroke(ColorPalette.textPrimary,
                                                lineWidth: self.viewModel.annotationColor == color ? 2 : 0)
                            }
                    }
                }
            }

            HStack(spacing: DS.Spacing.sm) {
                Button(action: { self.viewModel.annotateSelection() }) {
                    Text("Apply to selection")
                        .font(forCategory: .button)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(ColorPalette.accent)

                Button(action: { self.viewModel.undoLastAnnotation() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(ColorPalette.textPrimary)
                .disabled(!self.viewModel.canUndoAnnotation)
                .accessibilityLabel(Text("Undo"))
            }
        }
        .padding(DS.Spacing.sm)
        .frame(maxWidth: .infinity)
        .floatingGlass(radius: DS.Radius.card)
    }

    var textView: some View {
        TabView(selection: self.$viewModel.pageIndex) {
            ForEach(Array(self.viewModel.pages.enumerated()), id:\.offset) { _, page in
                if let page = page {
                    ScrollView {
                        Text(page)
                            .font(forCategory: .body1)
                            .foregroundStyle(ColorPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Spacing.md)
                            .padding(.bottom, 80)
                    }
                } else {
                    Text("No text available on this page")
                        .font(forCategory: .body1)
                        .foregroundStyle(ColorPalette.textSecondary)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(ColorPalette.background)
    }

    var standardView: some View {
        PdfKitViewBinder(
            pdfView: self.$viewModel.pdfView,
            singlePage: false,
            pageMargins: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            backgroundColor: UIColor(ColorPalette.background),
            usePaginator: true
        )
    }

    /// Reading-mode switches, kept out of the way of the page itself.
    private var readerMenu: some View {
        Menu {
            if self.viewModel.hasUnsavedAnnotations {
                Button {
                    _ = self.viewModel.save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            }
            Button {
                self.viewModel.switchTextMode()
            } label: {
                Label(self.viewModel.textMode
                      ? String(localized: "Page view")
                      : String(localized: "Text view"),
                      systemImage: self.viewModel.textMode ? "doc" : "doc.text")
            }
            Button {
                self.viewModel.presentPageSelection()
            } label: {
                Label("Pages", systemImage: "square.grid.2x2")
            }
            Button {
                self.viewModel.presentPageImages()
            } label: {
                Label("Images", systemImage: "photo.stack")
            }
        } label: {
            Label("More", systemImage: "ellipsis")
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
