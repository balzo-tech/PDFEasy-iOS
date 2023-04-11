//
//  PdfEditView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import SwiftUI
import Factory

struct PdfEditView: View {
    
    @StateObject var pdfEditViewModel: PdfEditViewModel
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { self.pdfEditViewModel.save() }) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(ColorPalette.primaryText)
                    }
                }
            }
    }
}

struct PdfEditView_Previews: PreviewProvider {
    static var previews: some View {
        if let pdfEditable = K.Test.DebugPdfEditable {
            AnyView(PdfEditView(pdfEditViewModel: Container.shared.pdfEditViewModel(pdfEditable)))
        } else {
            AnyView(Spacer())
        }
        
    }
}
