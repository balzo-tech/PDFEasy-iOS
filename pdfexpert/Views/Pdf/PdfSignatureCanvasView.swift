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
                .font(forCategory: .body1)
                .foregroundColor(ColorPalette.secondaryBG)
                .frame(maxWidth: .infinity)
            Spacer().frame(height: 10)
            self.tabsView
            Spacer().frame(height: 10)
            Spacer()
            self.contentView
            Spacer().frame(height: 40)
            self.saveButton
            Spacer().frame(height: 20)
            self.getDefaultButton(text: "Confirm",
                                  enabled: self.viewModel.confirmAllowed,
                                  onButtonPressed: { self.viewModel.onConfirmButtonPressed() })
        }
        .padding(16)
        .background(ColorPalette.primaryText)
        .galleryImageProviderView(flow: self.viewModel.galleryImageProviderFlow)
    }
    
    var tabsView: some View {
        HStack(spacing: 16) {
            ForEach(SignatureSource.allCases, id:\.self) { source in
                Button(action: { self.viewModel.source = source }) {
                    Label(title: {
                        Text(source.text)
                            .lineLimit(1)
                            .font(forCategory: .caption1)
                            .foregroundColor(
                                self.viewModel.source == source
                                ? ColorPalette.secondaryText
                                : ColorPalette.primaryBG
                            )
                    }, icon: {
                        source.icon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(
                                self.viewModel.source == source
                                ? ColorPalette.secondaryText
                                : ColorPalette.primaryBG
                            )
                    })
                }
            }
        }
    }
    
    @ViewBuilder var contentView: some View {
        switch self.viewModel.source {
        case .drawing: self.drawContentView
        case .image: self.imageContentView
        case .camera: self.cameraContentView
        }
    }
    
    var drawContentView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer().frame(width: 24)
                VStack(spacing: 0) {
                    PencilKitView(canvasView: self.$viewModel.canvasView,
                                  backgroundColor: ColorPalette.primaryText,
                                  inkColor: .black,
                                  onSaved: {})
                    .frame(width: K.Misc.SignatureSize.width, height: K.Misc.SignatureSize.height)
                    ColorPalette.thirdText.frame(height: 1)
                }
                Button(action: { self.viewModel.onClearButtonPressed() }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .foregroundColor(ColorPalette.thirdText)
                        .frame(width: 24, height: 24)
                        .scaledToFit()
                }
            }
            Spacer().frame(height: 6)
            Text("Sign in here")
                .font(forCategory: .body2)
                .foregroundColor(ColorPalette.thirdText)
        }
    }
    
    var imageContentView: some View {
        HStack {
            Spacer()
            VStack(spacing: 0) {
                Button(action: { self.viewModel.onSelectImageButtonPressed() }) {
                    if let uiImage = self.viewModel.signatureGalleryImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Color.clear
                    }
                }
                .frame(width: K.Misc.SignatureSize.width, height: K.Misc.SignatureSize.height)
                Spacer().frame(height: 6)
                Text("Select Image")
                    .font(forCategory: .body2)
                    .foregroundColor(ColorPalette.thirdText)
            }
            Spacer()
        }
    }
    
    var cameraContentView: some View {
        HStack {
            Spacer()
            VStack(spacing: 0) {
                Button(action: { self.viewModel.onTakePictureButtonPressed() }) {
                    if let uiImage = self.viewModel.signatureCameraImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Color.clear
                    }
                }
                .frame(width: K.Misc.SignatureSize.width, height: K.Misc.SignatureSize.height)
                Spacer().frame(height: 6)
                Text("Take a Picture")
                    .font(forCategory: .body2)
                    .foregroundColor(ColorPalette.thirdText)
            }
            Spacer()
        }
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
            .font(forCategory: .callout)
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

fileprivate extension SignatureSource {
    var text: String {
        switch self {
        case .drawing: return "Drawing"
        case .image: return "From Image"
        case .camera: return "From Camera"
        }
    }
    
    var icon: Image {
        switch self {
        case .drawing: return Image("sign_drawing")
        case .image: return Image(systemName: "photo")
        case .camera: return Image(systemName: "camera")
        }
    }
}

struct PdfSignatureCanvasView_Previews: PreviewProvider {
    
    static let drawing = PKDrawing()
    
    static var previews: some View {
        PdfSignatureCanvasView(viewModel: Container.shared
            .pdfSignatureCanvasViewModel({ _ in print("Confirm button pressed") }))
    }
}
