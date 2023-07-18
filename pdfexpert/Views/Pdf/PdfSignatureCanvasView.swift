//
//  PdfSignatureCanvasView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/05/23.
//

import SwiftUI
import PencilKit
import Factory

struct PdfSignatureCanvasView: View {
    
    @StateObject var viewModel: PdfSignatureCanvasViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Signature")
                .font(FontPalette.fontMedium(withSize: 16))
                .foregroundColor(ColorPalette.secondaryBG)
                .frame(maxWidth: .infinity)
            Spacer().frame(height: 20)
            HStack(spacing: 0) {
                PencilKitView(canvasView: self.$viewModel.canvasView,
                              backgroundColor: ColorPalette.primaryText,
                              inkColor: .black,
                              onSaved: {})
                Button(action: { self.viewModel.onClearButtonPressed() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorPalette.thirdText)
                }
            }
            ColorPalette.primaryBG.frame(height: 1)
            Spacer().frame(height: 6)
            Text("Sign in here")
                .font(FontPalette.fontRegular(withSize: 12))
                .foregroundColor(ColorPalette.thirdText)
                .frame(maxWidth: .infinity)
            Spacer().frame(height: 37)
            self.getDefaultButton(text: "Confirm",
                                  onButtonPressed: { self.viewModel.onConfirmButtonPressed() })
            .padding([.leading, .trailing], 16)
        }
        .padding(20)
    }
}

struct PdfSignatureCanvasView_Previews: PreviewProvider {
    
    static let drawing = PKDrawing()
    
    static var previews: some View {
        PdfSignatureCanvasView(viewModel: Container.shared
            .pdfSignatureCanvasViewModel({ _ in print("Confirm button pressed") }))
            .background(ColorPalette.primaryText)
    }
}
