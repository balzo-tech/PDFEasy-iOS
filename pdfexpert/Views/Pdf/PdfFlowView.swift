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
    
    var body: some View {
        self.content
    }
    
    var content: some View {
        switch self.coordinator.rootView {
        case .edit:
            return AnyView(
                NavigationStack(path: self.$coordinator.path) {
                    PdfEditView(viewModel: Container.shared.pdfEditViewModel(self.pdfEditable))
                        .navigationDestination(for: PdfCoordinator.Route.self) { route in
                            switch route {
                            case .viewer(let pdf, let marginsOption, let quality):
                                let inputParameter = PdfViewerViewModel.InputParameter(pdf: pdf,
                                                                                       marginsOption: marginsOption,
                                                                                       quality: quality)
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
            AnyView(PdfFlowView(pdfEditable: pdfEditable))
        } else {
            AnyView(Color(.clear))
        }
    }
}
