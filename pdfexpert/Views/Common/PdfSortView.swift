//
//  PdfSortView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 02/08/23.
//

import SwiftUI
import Factory

struct PdfSortView: View {
    
    @ObservedObject var viewModel: PdfSortViewModel
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(Array(self.viewModel.pdfs.enumerated()), id:\.offset) { _, item in
                        self.getItemView(forItem: item)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(.clear))
                    }
                    .onMove { from, to in
                        self.viewModel.pdfs.move(fromOffsets: from, toOffset: to)
                    }
                }
                .environment(\.editMode, .constant(.active))
                .scrollContentBackground(.hidden)
                .listStyle(.inset)
                Spacer()
                self.getDefaultButton(text: self.viewModel.confirmButtonText, onButtonPressed: {
                    self.viewModel.confirm()
                })
            }
            .padding([.leading, .trailing], 16)
            .padding(.top, 48)
            .padding(.bottom, 80)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Drag and drop to sort your documents")
            .background(ColorPalette.primaryBG)
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                self.viewModel.cancel()
            })
        }
        .background(ColorPalette.primaryBG)
        .onAppear {
            self.analyticsManager.track(event: .reportScreen(.sortPdf))
        }
    }
    
    private func getItemView(forItem item: Pdf) -> some View {
        HStack(spacing: 16) {
            self.getPdfThumbnail(forPdf: item)
                .frame(width: 86)
            VStack(spacing: 0) {
                Spacer()
                Text(item.filename)
                    .font(FontPalette.fontMedium(withSize: 16))
                    .foregroundColor(ColorPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                Spacer().frame(height: 16)
                HStack(spacing: 16) {
                    Text(item.pageCountText)
                        .font(FontPalette.fontMedium(withSize: 15))
                        .foregroundColor(ColorPalette.fourthText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
        }
        .padding(.trailing, 16)
        .background(ColorPalette.secondaryBG)
        .frame(height: 94)
        .cornerRadius(10)
    }
    
    @ViewBuilder private func getPdfThumbnail(forPdf pdf: Pdf) -> some View {
        if let thumbnail = pdf.thumbnail {
            Color.clear
                .overlay(Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill())
                .clipShape(RoundedRectangle(cornerRadius: 10,
                                            style: .continuous))
        } else {
            ColorPalette.secondaryBG
                .cornerRadius(10)
        }
    }
}

extension View {
    func showSortView(isPresented: Binding<Bool>,
                      onDismiss: (() -> Void)?,
                      params: PdfSortViewModel.Params) -> some View {
        self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
            let viewModel = Container.shared.pdfSortViewModel(params)
            PdfSortView(viewModel: viewModel)
        }
    }
}

struct PdfSortView_Previews: PreviewProvider {
    
    static let params = PdfSortViewModel.Params(
        pdfs: .constant([K.Test.DebugPdf, K.Test.DebugPdf, K.Test.DebugPdf].compactMap { $0 }),
        confirmButtonText: "Merge PDF",
        confirmCallback: { print("Sort confirmed!") },
        cancelCallback: { print("Sort cancelled...") })
    
    static var previews: some View {
        Color(.white)
            .showSortView(isPresented: .constant(true),
                          onDismiss: { print("Sort completed.") },
                          params: Self.params)
    }
}
