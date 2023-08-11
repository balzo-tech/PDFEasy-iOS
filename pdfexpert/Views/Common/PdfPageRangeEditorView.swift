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
    
    @Namespace var bottomID
    
    @State var previousNumberOfRanges: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                self.listView
                self.bottomView
                    .ignoresSafeArea(.keyboard)
            }
            .padding(.top, 48)
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
        // The focus state in the viewmodel is the one in charge and allow field validation.
        // The one in the view must by synced with it
        .onChange(of: self.viewModel.pdfPageRangeInFocus) { self.pdfPageRangeInFocus = $0 }
    }
    
    private var listView: some View {
        ScrollViewReader { scrollViewProxy in
            List {
                ForEach(Array(self.viewModel.pageRangeLowerBounds.enumerated()), id:\.offset) { index, item in
                    self.getItemView(atIndex: index)
                        .listRowBackground(ColorPalette.secondaryBG)
                }
                .onChange(of: self.viewModel.pageRangeLowerBounds.count) { newValue in
                    if self.isScrollToAvailable, newValue > self.previousNumberOfRanges {
                        withAnimation {
                            scrollViewProxy.scrollTo(self.bottomID, anchor: .bottom)
                        }
                    }
                    self.previousNumberOfRanges = newValue
                }
                HStack {
                    Spacer()
                    self.addRangeButton
                }
                .listRowBackground(ColorPalette.primaryBG)
                .listRowSeparator(.hidden)
                Spacer()
                    .frame(height: 135)
                    .listRowBackground(ColorPalette.primaryBG)
                    .id(self.bottomID)
            }
            .safeAreaInset(edge: .bottom, content: {
                Spacer().frame(height: 8)
            })
            .scrollContentBackground(.hidden)
        }
    }
    
    private var bottomView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                self.getDefaultButton(text: "Split PDF", onButtonPressed: {
                    self.viewModel.confirm()
                })
                .padding([.leading, .trailing], 16)
                .padding(.bottom, 80)
                .padding(.top, 16)
            }.background(ColorPalette.primaryBG)
        }
    }
    
    private var addRangeButton: some View {
        Button(action: {
            withAnimation {
                self.viewModel.addRange()
            }
        }) {
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
                Button(action: {
                    withAnimation {
                        self.viewModel.removeRange(atIndex: index)
                    }
                }) {
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
            HStack {
                Text(isLowerBound ? "From page number" : "To page number")
                    .font(FontPalette.fontMedium(withSize: 12))
                    .foregroundColor(ColorPalette.thirdText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                TextField("", text: self.viewModel.getTextFieldText(index: index,
                                                                    isLowerBound: isLowerBound))
                .font(FontPalette.fontMedium(withSize: 14))
                .foregroundColor(ColorPalette.primaryText)
                .lineLimit(1)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .fixedSize(horizontal: true, vertical: true)
                .allowsHitTesting(false)
                .focused(self.$pdfPageRangeInFocus,
                         equals: isLowerBound ? .lowerBound(index: index) : .upperBound(index: index))
                .keyboardType(.numberPad)
            }
            Button("") {
                self.viewModel.focus(index: index, isLowerBound: isLowerBound)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
