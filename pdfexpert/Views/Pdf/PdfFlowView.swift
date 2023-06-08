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
    
    var body: some View {
        self.content
    }
    
    var content: some View {
        switch self.coordinator.rootView {
        case .edit:
            return AnyView(
                NavigationStack(path: self.$coordinator.path) {
                    let inputParameter = PdfEditViewModel.InputParameter(pdfEditable: self.pdfEditable,
                                                                         startAction: self.startAction)
                    PdfEditView(viewModel: Container.shared.pdfEditViewModel(inputParameter))
                        .navigationDestination(for: PdfCoordinator.Route.self) { route in
                            switch route {
                            case .viewer(let pdf, let marginsOption, let compression):
                                let inputParameter = PdfViewerViewModel.InputParameter(pdf: pdf,
                                                                                       marginsOption: marginsOption,
                                                                                       compression: compression)
                                PdfViewerView(viewModel: Container.shared.pdfViewerViewModel(inputParameter))
                                    .addCustomBackButton(color: ColorPalette.primaryText,
                                                         onPress: {
                                        self.coordinator.goBack(fromRoute: route)
                                    })
                            }
                        }
                        .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                            self.dismiss()
                        })
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
