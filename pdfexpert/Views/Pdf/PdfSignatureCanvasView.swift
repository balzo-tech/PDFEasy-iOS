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
            Text("Add Signature")
                .font(FontPalette.fontRegular(withSize: 16))
                .foregroundColor(ColorPalette.secondaryBG)
                .frame(maxWidth: .infinity)
            Spacer()
            HStack(spacing: 0) {
                Spacer()
                PencilKitView(canvasView: self.$viewModel.canvasView,
                              backgroundColor: ColorPalette.primaryText,
                              inkColor: .black,
                              onSaved: {})
                .frame(width: K.Misc.SignatureSize.width, height: K.Misc.SignatureSize.height)
                Spacer()
                Button(action: { self.viewModel.onClearButtonPressed() }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .foregroundColor(ColorPalette.thirdText)
                        .frame(width: 24, height: 24)
                        .scaledToFit()
                }
            }
            ColorPalette.thirdText.frame(height: 1)
            VStack(spacing: 0) {
                Spacer().frame(height: 6)
                Text("Sign in here")
                    .font(FontPalette.fontRegular(withSize: 12))
                    .foregroundColor(ColorPalette.thirdText)
                    .frame(maxWidth: .infinity)
                Spacer().frame(height: 40)
                self.saveButton
                Spacer().frame(height: 20)
                self.getDefaultButton(text: "Confirm",
                                      onButtonPressed: { self.viewModel.onConfirmButtonPressed() })
            }
        }
        .padding(16)
        .background(ColorPalette.primaryText)
    }
    
    var saveButton: some View {
        Button(action: { self.viewModel.toggleShouldSave() }) {
            Label {
                Text("Memorize signature")
                    .padding(.trailing, 6)
            } icon: {
                Image(
                    systemName: self.viewModel.shouldSaveSignature
                    ? "checkmark.circle.fill"
                    : "checkmark.circle"
                )
                .resizable()
                .scaledToFit()
                .padding([.top, .bottom, .leading], 6)
            }
            .font(FontPalette.fontMedium(withSize: 12))
            .foregroundColor(
                self.viewModel.shouldSaveSignature
                ? ColorPalette.buttonGradientStart
                : ColorPalette.thirdText
            )
            .frame(height: 40)
        }
        .frame(height: 40)
        .overlay(Capsule().stroke(
            self.viewModel.shouldSaveSignature
            ? ColorPalette.buttonGradientStart
            : ColorPalette.thirdText,
            lineWidth: 1
        ))
    }
}

struct PdfSignatureCanvasView_Previews: PreviewProvider {
    
    static let drawing = PKDrawing()
    
    static var previews: some View {
        PdfSignatureCanvasView(viewModel: Container.shared
            .pdfSignatureCanvasViewModel({ _ in print("Confirm button pressed") }))
    }
}
