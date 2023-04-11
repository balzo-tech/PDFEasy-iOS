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
                    PdfEditView(pdfEditViewModel: Container.shared.pdfEditViewModel(self.pdfEditable))
                        .navigationDestination(for: PdfCoordinator.Route.self) { route in
                            switch route {
                            case .viewer(let pdf):
                                PdfViewerView(pdfViewerViewModel: Container.shared.pdfViewerViewModel(pdf))
                                    .navigationBarBackButtonHidden()
                                    .toolbar {
                                        ToolbarItem(placement: .navigationBarLeading) {
                                            Button(action: { self.coordinator.goBack(fromRoute: route) }) {
                                                Image(systemName: "chevron.backward")
                                                    .foregroundColor(ColorPalette.primaryText)
                                            }
                                        }
                                    }
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: { self.dismiss() }) {
                                    Image(systemName: "xmark")
                                        .foregroundColor(ColorPalette.primaryText)
                                }
                            }
                        }
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
