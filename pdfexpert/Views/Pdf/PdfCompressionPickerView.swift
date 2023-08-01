//
//  PdfCompressionPickerView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/07/23.
//

import SwiftUI
import Factory

struct PdfCompressionPickerView: View {
    
    @Binding var compressionOption: CompressionOption
    
    @State var currentCompressionOption: CompressionOption
    
    @Environment(\.dismiss) var dismiss
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    init(compressionOption: Binding<CompressionOption>) {
        self._compressionOption = compressionOption
        self._currentCompressionOption = State(initialValue: compressionOption.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(CompressionOption.orderedList, id:\.self) { option in
                Button(action: { self.currentCompressionOption = option }) {
                    Group {
                        HStack(spacing: 16) {
                            VStack(spacing: 6) {
                                Text(option.titleText)
                                    .font(FontPalette.fontMedium(withSize: 16))
                                    .foregroundColor(ColorPalette.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(option.descriptionText)
                                    .font(FontPalette.fontMedium(withSize: 12))
                                    .foregroundColor(ColorPalette.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            self.getCheckbox(forCompressionOption: option)
                        }
                        .padding(16)
                    }
                    .background(ColorPalette.secondaryBG)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1))
                        .foregroundColor(ColorPalette.thirdText))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 74)
            }
            Spacer()
            self.getDefaultButton(text: "Finish", onButtonPressed: {
                self.compressionOption = self.currentCompressionOption
                self.dismiss()
            })
        }
        .padding([.leading, .trailing], 16)
        .padding(.top, 48)
        .padding(.bottom, 80)
        .navigationTitle("Choose a compression for your pdf")
        .background(ColorPalette.primaryBG)
        .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
            self.dismiss()
        })
        .onAppear {
            self.analyticsManager.track(event: .reportScreen(.compressionPicker))
        }
    }
    
    @ViewBuilder func getCheckbox(forCompressionOption compressionOption: CompressionOption) -> some View {
        if compressionOption == self.currentCompressionOption {
            ZStack {
                Image(systemName: "circle.fill")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(ColorPalette.secondaryText)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 10, height: 10)
                    .foregroundColor(ColorPalette.primaryText)
            }
        } else {
            Image(systemName: "circle")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(ColorPalette.primaryText)
        }
    }
}
                            
fileprivate extension CompressionOption {
    
    var titleText: String {
        switch self {
        case .high: return "Maximum compression"
        case .medium: return "Recommended compression"
        case .low: return "Low compression"
        case .noCompression: return "No compression"
        }
    }
    
    var descriptionText: String {
        switch self {
        case .high: return "Lower quality, higher compression"
        case .medium: return "Good quality, good compression"
        case .low: return "High quality, less compression"
        case .noCompression: return "Top quality, no compression"
        }
    }
    
    static var orderedList: [CompressionOption] {
        self.allCases.reversed()
    }
}

struct PdfCompressionPickerView_Previews: PreviewProvider {
    static var previews: some View {
        PdfCompressionPickerView(compressionOption: .constant(.noCompression))
    }
}
