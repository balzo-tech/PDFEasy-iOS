//
//  PdfRedactView.swift
//  PdfExpert
//
//  Redaction editor: the current page is shown as a rendered image and the user drags
//  rectangles over what must disappear.
//
//  Coordinates are the fragile part of this tool, so they are handled in one place:
//  the page image is laid out with a known aspect fit, and every gesture rectangle is
//  normalized (0…1, top-left) against *that* displayed rect before it leaves the view.
//  Zoom, device size and page rotation therefore cannot shift a box — the utility only
//  ever sees fractions of the page.
//

import SwiftUI

struct PdfRedactView: ViewModifier {

    @ObservedObject var viewModel: PdfRedactViewModel

    func body(content: Content) -> some View {
        content
            .showImportView(viewModel: self.viewModel.pdfImportViewModel)
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .fullScreenCover(isPresented: self.$viewModel.editorShow) {
                PdfRedactEditorView(viewModel: self.viewModel)
            }
            .asyncView(asyncItem: self.$viewModel.asyncRedact)
            .alert(String(localized: "Apply redactions?"),
                   isPresented: self.$viewModel.confirmAlertShow,
                   actions: {
                Button(String(localized: "Cancel"), role: .cancel, action: {})
                Button(String(localized: "Apply")) {
                    self.viewModel.onApplyConfirmed()
                }
            }, message: {
                Text("The redacted pages are converted into images: on those pages the text will no longer be selectable or searchable. A new copy is saved and your original is left untouched.")
            })
            .alert(String(localized: "Done"), isPresented: self.$viewModel.successAlertShow, actions: {
                Button("Ok", role: .cancel, action: {})
            }, message: {
                Text("A redacted copy has been saved to your archive.")
            })
    }
}

struct PdfRedactEditorView: View {

    @ObservedObject var viewModel: PdfRedactViewModel

    /// The rectangle being dragged, in the page image's own coordinate space.
    @State private var currentRect: CGRect? = nil

    var body: some View {
        NavigationStack {
            // The page itself keeps the whole window — drawing a box over the
            // right words is precision work and a bigger page is an easier
            // target. It is the text and the controls around it that are bounded,
            // so on an iPad the page navigation is not a screen-width apart from
            // the undo button.
            VStack(spacing: 12) {
                Text("Drag over the areas you want to black out.")
                    .font(forCategory: .caption1)
                    .foregroundColor(ColorPalette.thirdText)
                    .multilineTextAlignment(.center)
                    .readableColumn()

                self.pageView

                self.pageControls
                    .readableColumn()
            }
            .padding(16)
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(String(localized: "Redact PDF"))
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                self.viewModel.cancel()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Apply")) {
                        self.viewModel.requestApply()
                    }
                    .disabled(!self.viewModel.canApply)
                    .foregroundColor(self.viewModel.canApply ? ColorPalette.primaryText : ColorPalette.thirdText)
                }
            }
        }
    }

    @ViewBuilder private var pageView: some View {
        if self.viewModel.pageIndex < self.viewModel.pageImages.count {
            let image = self.viewModel.pageImages[self.viewModel.pageIndex]
            GeometryReader { geometry in
                let displayed = Self.fittedRect(imageSize: image.size, in: geometry.size)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: displayed.width, height: displayed.height)
                        .offset(x: displayed.minX, y: displayed.minY)

                    // Boxes already placed on this page.
                    ForEach(self.viewModel.currentPageBoxes) { box in
                        let rect = Self.denormalize(box.rect, in: displayed)
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                    }

                    // The box being dragged right now.
                    if let currentRect = self.currentRect {
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: currentRect.width, height: currentRect.height)
                            .offset(x: currentRect.minX, y: currentRect.minY)
                    }
                }
                // `.topLeading`, and it matters: an `.offset` moves what is drawn
                // but not the layout, so this ZStack measures the page image and
                // a centring frame would slide it down by half the spare height —
                // on top of the offset that had already centred it. The page ended
                // up against the bottom edge, and every box was drawn that same
                // half-gap away from the finger that drew it.
                .frame(width: geometry.size.width,
                       height: geometry.size.height,
                       alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            self.currentRect = Self.rect(from: value.startLocation,
                                                         to: value.location)
                                .intersection(displayed)
                        }
                        .onEnded { value in
                            let rect = Self.rect(from: value.startLocation, to: value.location)
                                .intersection(displayed)
                            self.currentRect = nil
                            guard !rect.isNull, !rect.isEmpty else { return }
                            self.viewModel.addBox(normalizedRect: Self.normalize(rect, in: displayed))
                        }
                )
            }
        } else {
            Spacer()
        }
    }

    @ViewBuilder private var pageControls: some View {
        HStack(spacing: 16) {
            Button(action: { self.viewModel.pageIndex = max(0, self.viewModel.pageIndex - 1) }) {
                Image(systemName: "chevron.left")
            }
            .disabled(self.viewModel.pageIndex == 0)

            Text("\(self.viewModel.pageIndex + 1) of \(self.viewModel.pageCount)")
                .font(forCategory: .body2)
                .foregroundColor(ColorPalette.primaryText)

            Button(action: {
                self.viewModel.pageIndex = min(self.viewModel.pageCount - 1, self.viewModel.pageIndex + 1)
            }) {
                Image(systemName: "chevron.right")
            }
            .disabled(self.viewModel.pageIndex >= self.viewModel.pageCount - 1)

            Spacer()

            Button(action: { self.viewModel.removeLastBoxOnCurrentPage() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(self.viewModel.currentPageBoxes.isEmpty)

            Button(action: { self.viewModel.clearBoxes() }) {
                Image(systemName: "trash")
            }
            .disabled(!self.viewModel.canApply)
        }
        .foregroundColor(ColorPalette.primaryText)
    }

    // MARK: - Geometry (pure)

    /// Where an aspect-fitted image actually lands inside `container`.
    static func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (container.width - size.width) / 2,
                      y: (container.height - size.height) / 2,
                      width: size.width,
                      height: size.height)
    }

    static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x),
               y: min(start.y, end.y),
               width: abs(end.x - start.x),
               height: abs(end.y - start.y))
    }

    /// View rect → fraction of the page (top-left origin).
    static func normalize(_ rect: CGRect, in displayed: CGRect) -> CGRect {
        guard displayed.width > 0, displayed.height > 0 else { return .zero }
        return CGRect(x: (rect.minX - displayed.minX) / displayed.width,
                      y: (rect.minY - displayed.minY) / displayed.height,
                      width: rect.width / displayed.width,
                      height: rect.height / displayed.height)
    }

    static func denormalize(_ rect: CGRect, in displayed: CGRect) -> CGRect {
        CGRect(x: displayed.minX + rect.minX * displayed.width,
               y: displayed.minY + rect.minY * displayed.height,
               width: rect.width * displayed.width,
               height: rect.height * displayed.height)
    }
}

extension View {
    func showRedactView(viewModel: PdfRedactViewModel) -> some View {
        self.modifier(PdfRedactView(viewModel: viewModel))
    }
}
