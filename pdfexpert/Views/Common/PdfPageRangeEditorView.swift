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
    
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    @Namespace var bottomID
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
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
                        .id(self.bottomID)
                    }
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        self.scrollProxy = proxy
                    }
                }
                Spacer()
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
        }
        .background(ColorPalette.primaryBG)
        .onAppear {
            self.analyticsManager.track(event: .reportScreen(.pageRangeEditor))
        }
        .onChange(of: self.viewModel.pageRangeLowerBounds, perform: { _ in
            self.scrollToBottom()
        })
    }
    
    private func scrollToBottom() {
        withAnimation {
            self.scrollProxy?.scrollTo(self.bottomID, anchor: .bottom)
        }
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
            Button(action: { self.viewModel.removeRange(atIndex: index) }) {
                Image(systemName: "trash.fill")
                    .foregroundColor(ColorPalette.thirdText)
            }
        }
    }
    
    private func getItemView(atIndex index: Int) -> some View {
        Section(header: self.getRangeHeader(atIndex: index)) {
                self.getBoundView(forBound: self.$viewModel.pageRangeLowerBounds[index],
                                  withText: "From page number")
                self.getBoundView(forBound: self.$viewModel.pageRangeUpperBounds[index],
                                  withText: "To page number")
            }
    }
    
    private func getBoundView(forBound bound: Binding<String>, withText text: String) -> some View {
        ZStack {
            Text(text)
                .font(FontPalette.fontMedium(withSize: 12))
                .foregroundColor(ColorPalette.thirdText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            TextField("", text: bound)
                .font(FontPalette.fontMedium(withSize: 14))
                .foregroundColor(ColorPalette.primaryText)
                .lineLimit(1)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .multilineTextAlignment(.trailing)
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
