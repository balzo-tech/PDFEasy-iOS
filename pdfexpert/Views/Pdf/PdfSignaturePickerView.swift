//
//  PdfSignaturePickerView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/08/23.
//

import SwiftUI
import Factory

struct PdfSignaturePickerView: View {
    
    @StateObject var viewModel: PdfSignaturePickerViewModel
    
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                Text("Your Signatures")
                    .font(FontPalette.fontRegular(withSize: 16))
                    .foregroundColor(ColorPalette.primaryBG)
                Spacer().frame(height: 16)
                self.content
                Spacer().frame(height: 16)
                self.addNewButton
            }
            if self.viewModel.isLoading {
                self.loadingView
            }
            self.getCloseButton(color: ColorPalette.primaryBG,
                                onClose: { self.viewModel.cancel() })
            self.getEditButton(color: ColorPalette.buttonGradientStart,
                               font: FontPalette.fontRegular(withSize: 16),
                               editMode: self.$editMode)
        }
        .background(ColorPalette.primaryText)
        .onAppear {
            self.viewModel.onAppear()
        }
    }
    
    @ViewBuilder var content: some View {
        switch self.viewModel.asyncItems.status {
        case .empty: Spacer()
        case .loading: self.loadingView
        case .data(let items): self.getItemList(items: items)
        case .error: self.errorView
        }
    }
    
    @ViewBuilder func getItemList(items: [Signature]) -> some View {
        if items.count > 0 {
            List {
                ForEach(items) { item in
                    Button(action: {
                        if self.editMode == .inactive {
                            self.viewModel.pick(item: item)
                        }
                    }) {
                        HStack(spacing: 0) {
                            Spacer()
                            Image(uiImage: item.image)
                                .resizable()
                                .scaledToFit()
                                .padding([.leading, .trailing], 16)
                            Spacer()
                        }
                    }
                    .padding([.top, .bottom], 16)
                    .frame(height: K.Misc.SignatureSize.height)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color(.clear))
                }
                .onDelete { indexSet in
                    self.viewModel.delete(indexSet: indexSet)
                }   
            }
            // Needed to use a custom background color in case of List with inset list style
            .scrollContentBackground(.hidden)
            .listStyle(.inset)
            .environment(\.editMode, self.$editMode)
        } else {
            self.emptyView
        }
    }
    
    var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No signature added")
                .font(FontPalette.fontRegular(withSize: 16))
                .foregroundColor(ColorPalette.thirdText)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding([.leading, .trailing], 16)
    }
    
    var loadingView: some View {
        AnimationType.dots.view.background(Color(.black).opacity(0.3))
    }
    
    var errorView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("subscription_error")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
            Text("Oh nou")
                .font(FontPalette.fontMedium(withSize: 32))
                .foregroundColor(ColorPalette.primaryBG)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Something went wrong,\nmind trying again?")
                .font(FontPalette.fontRegular(withSize: 15))
                .foregroundColor(ColorPalette.primaryBG)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            self.getDefaultButton(text: "Retry",
                                  onButtonPressed: self.viewModel.refresh)
            Spacer()
        }
        .padding([.leading, .trailing], 16)
    }
    
    var addNewButton: some View {
        HStack(spacing: 0) {
            Spacer()
            Button(action: { self.viewModel.createNewSignature() }) {
                Label("Add new signature", systemImage: "plus.circle.fill")
                    .font(FontPalette.fontRegular(withSize: 16))
                    .foregroundColor(ColorPalette.buttonGradientStart)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .padding(.trailing, 16)
    }
}

struct PdfSignaturePickerView_Previews: PreviewProvider {
    
    static let params = PdfSignaturePickerViewModel.Params(
        confirmationCallback: { _ in print("Signature confirmed!") },
        cancelCallback: { print("Signature selection cancelled") },
        createNewSignatureCallback: { print("Create new signature!") }
    )
    
    static var previews: some View {
        PdfSignaturePickerView(viewModel: Container.shared.pdfSignaturePickerViewModel(Self.params))
    }
}
