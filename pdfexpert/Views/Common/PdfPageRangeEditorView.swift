//
//  PdfPageRangeEditorView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/08/23.
//

import SwiftUI
import Factory

struct PdfPageRangeEditorView: View {
    
    @ObservedObject var viewModel: PdfPageRangeEditorViewModel
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    @FocusState private var pdfPageRangeInFocus: PdfPageRangeFocusable?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(Array(self.viewModel.pageRangeLowerBounds.enumerated()), id:\.offset) { index, item in
                        self.getItemView(atIndex: index)
                            .listRowBackground(ColorPalette.secondaryBG)
                    }
                    HStack {
                        Spacer()
                        self.addRangeButton
                    }
                    .listRowBackground(ColorPalette.primaryBG)
                }
                .scrollContentBackground(.hidden)
                self.getDefaultButton(text: "Split PDF", onButtonPressed: {
                    self.viewModel.confirm()
                })
                .padding([.leading, .trailing], 16)
            }
            .padding(.top, 48)
            .padding(.bottom, 80)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Split pages into ranges")
            .background(ColorPalette.primaryBG)
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                self.viewModel.cancel()
            })
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(action: {
                        self.viewModel.onConfirmRange()

                    }) {
                        Text("Done")
                            .foregroundColor(ColorPalette.secondaryText)
                            .bold()
                    }
                }
            }
        }
        .background(ColorPalette.primaryBG)
        .onAppear {
            self.analyticsManager.track(event: .reportScreen(.pageRangeEditor))
        }
        // Syncing focus state in both direction allow validation upon focues change
        // in view model
        .onChange(of: self.pdfPageRangeInFocus) { self.viewModel.pdfPageRangeInFocus = $0 }
        .onChange(of: self.viewModel.pdfPageRangeInFocus) { self.pdfPageRangeInFocus = $0 }

    }
    
    private var addRangeButton: some View {
        Button(action: self.viewModel.addRange) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(ColorPalette.secondaryText)
                Text("Add new range")
                    .font(FontPalette.fontMedium(withSize: 16))
                    .foregroundColor(ColorPalette.secondaryText)
                    .lineLimit(1)
            }
        }
    }
    
    private func getRangeHeader(atIndex index: Int) -> some View {
        HStack {
            Text("Range \(index + 1)")
                .font(FontPalette.fontMedium(withSize: 16))
                .foregroundColor(ColorPalette.primaryText)
            Spacer()
            if index > 0 {
                Button(action: { self.viewModel.removeRange(atIndex: index) }) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(ColorPalette.thirdText)
                }
            }
        }
    }
    
    private func getItemView(atIndex index: Int) -> some View {
        Section(header: self.getRangeHeader(atIndex: index)) {
            self.getBoundView(index: index, isLowerBound: true)
            self.getBoundView(index: index, isLowerBound: false)
        }
    }
    
    private func getBoundView(index: Int, isLowerBound: Bool) -> some View {
        ZStack {
            Text(isLowerBound ? "From page number" : "To page number")
                .font(FontPalette.fontMedium(withSize: 12))
                .foregroundColor(ColorPalette.thirdText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            // Inline binding avoid out of index exception when deleting an in-focus range
            TextField("", text: Binding(get: {
                guard index < self.viewModel.pageRangeLowerBounds.count else {
                    return ""
                }
                return isLowerBound
                ? self.viewModel.pageRangeLowerBounds[index]
                : self.viewModel.pageRangeUpperBounds[index]
            }, set: { newValue in
                guard index < self.viewModel.pageRangeLowerBounds.count else {
                    return
                }
                if isLowerBound {
                    self.viewModel.pageRangeLowerBounds[index] = newValue
                } else {
                    self.viewModel.pageRangeUpperBounds[index] = newValue
                }
            }))
            .font(FontPalette.fontMedium(withSize: 14))
            .foregroundColor(ColorPalette.primaryText)
            .lineLimit(1)
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .multilineTextAlignment(.trailing)
            .focused(self.$pdfPageRangeInFocus,
                     equals: isLowerBound ? .lowerBound(index: index) : .upperBound(index: index))
            .keyboardType(.numberPad)
        }
    }
}

extension View {
    func showPageRangeEditorView(isPresented: Binding<Bool>,
                                 onDismiss: (() -> Void)?,
                                 params: PdfPageRangeEditorViewModel.Params) -> some View {
        self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
            let viewModel = Container.shared.pdfPageRangeEditorViewModel(params)
            PdfPageRangeEditorView(viewModel: viewModel)
        }
    }
}

struct PdfPageRangeEditorView_Previews: PreviewProvider {
    
    static let params = PdfPageRangeEditorViewModel.Params(
        pageRanges: .constant([0...1, 0...1]),
        totalPages: 10,
        confirmCallback: { print("Split confirmed!") },
        cancelCallback: { print("Split cancelled...") })
    
    static var previews: some View {
        Color(.white)
            .showPageRangeEditorView(isPresented: .constant(true),
                                     onDismiss: { print("Split completed.") },
                                     params: Self.params)
    }
}
