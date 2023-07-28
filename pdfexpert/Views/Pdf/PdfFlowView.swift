//
//  PdfFlowView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import SwiftUI
import Factory

struct PdfFlowView: View {
    
    @InjectedObject(\.pdfCoordinator) var coordinator
    @Environment(\.dismiss) var dismiss
    let pdfEditable: PdfEditable
    let startAction: PdfEditStartAction?
    
    @State var shouldShowCloseWarning: Bool = true
    @State var showCloseWarningDialog: Bool = false
    
    var body: some View {
        self.content
    }
    
    var content: some View {
        switch self.coordinator.rootView {
        case .edit:
            return AnyView(
                NavigationStack {
                    let inputParameter = PdfEditViewModel.InputParameter(pdfEditable: self.pdfEditable,
                                                                         startAction: self.startAction,
                                                                         shouldShowCloseWarning: self.$shouldShowCloseWarning)
                    PdfEditView(viewModel: Container.shared.pdfEditViewModel(inputParameter))
                        .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                            if self.shouldShowCloseWarning {
                                self.showCloseWarningDialog = true
                            } else {
                                self.dismiss()
                            }
                        })
                        .alert("Are you sure?",
                               isPresented: self.$showCloseWarningDialog,
                               actions: {
                            Button("No", role: .cancel, action: {})
                            Button("Yes", role: .destructive, action: {
                                self.dismiss()
                            })
                        }, message: { Text("If you quit, you will lose the changes to your current file.") })
                }
            )
        }
    }
}

struct PdfView_Previews: PreviewProvider {
    static var previews: some View {
        if let pdfEditable = K.Test.DebugPdfEditable {
            AnyView(PdfFlowView(pdfEditable: pdfEditable, startAction: nil))
        } else {
            AnyView(Color(.clear))
        }
    }
}
