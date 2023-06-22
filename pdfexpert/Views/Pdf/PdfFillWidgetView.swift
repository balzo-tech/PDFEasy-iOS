//
//  PdfFillWidgetView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 22/06/23.
//

import SwiftUI
import Factory

struct PdfFillWidgetView: View {
    
    @StateObject var viewModel: PdfFillWidgetViewModel
    @Environment(\.dismiss) var dismiss
    @State var showCancelWarningDialog: Bool = false
    
    var body: some View {
        NavigationStack {
            PdfKitViewBinder(
                pdfView: self.$viewModel.pdfView,
                singlePage: false,
                pageMargins: UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0),
                backgroundColor: UIColor(ColorPalette.primaryBG),
                usePaginator: true
            )
            .padding([.leading, .trailing], 16)
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Tap to fill in")
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                if self.viewModel.shouldShowCloseWarning {
                    self.showCancelWarningDialog = true
                } else {
                    self.viewModel.onCancelButtonPressed()
                    self.dismiss()
                }
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        self.viewModel.onConfirmButtonPressed()
                        self.dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16).bold())
                            .foregroundColor(ColorPalette.buttonGradientStart)
                    }
                }
            }
            .alert("Are you sure?",
                   isPresented: self.$showCancelWarningDialog,
                   actions: {
                Button("No", role: .cancel, action: {})
                Button("Yes", role: .destructive, action: {
                    self.viewModel.onCancelButtonPressed()
                    self.dismiss()
                })
            }, message: { Text("If you quit, you will lose the changes you have just made.") })
        }
        .onAppear(perform: self.viewModel.onAppear)
    }
}

struct PdfFillWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        if let pdfEditable = K.Test.DebugPdfEditable {
            let inputParameter = PdfFillWidgetViewModel.InputParameter(pdfEditable: pdfEditable,
                                                                       currentPageIndex: 0,
                                                                       onConfirm: { _ in })
            AnyView(PdfFillWidgetView(viewModel: Container.shared.pdfFillWidgetViewModel(inputParameter)))
        } else {
            AnyView(Spacer())
        }
    }
}
