//
//  PreReviewPopupView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/08/23.
//

import SwiftUI

typealias PreReviewResultCallback = ((Int) -> ())

struct PreReviewPopupView: View {
    
    @Binding var isPresenting: Bool
    let onConfirm: PreReviewResultCallback
    
    @State var selectedRate: Int? = nil
    
    var body: some View {
        ZStack {
            self.getCloseButton(
                color: ColorPalette.primaryText,
                leftSide: false,
                padding: 12
            ) {
                self.isPresenting = false
            }
            VStack(spacing: 0) {
                Spacer().frame(height: 40)
                Text("Do you like our app?")
                    .font(forCategory: .headline)
                    .foregroundColor(ColorPalette.primaryText)
                    .frame(maxWidth: .infinity)
                Spacer().frame(height: 8)
                Text("Give us a quick rating so we\nknow how you like it")
                    .font(forCategory: .body2)
                    .foregroundColor(ColorPalette.primaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer().frame(height: 30)
                HStack(spacing: 10) {
                    ForEach(1..<6) { rateValue in
                        self.getRateView(forRateValue: rateValue)
                    }
                }
                .frame(height: 32)
                Spacer().frame(height: 44)
            }
            .padding(16)
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(ColorPalette.secondaryBG)
        .cornerRadius(8)
    }
    
    private func getRateView(forRateValue rateValue: Int) -> some View {
        Button(action: { self.onRateTapped(withRateValue: rateValue) }) {
            Image(systemName: self.getRateSystemName(forRateValue: rateValue))
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundColor(ColorPalette.extra)
        }
    }
    
    private func getRateSystemName(forRateValue rateValue: Int) -> String {
        if let selectedRate, selectedRate >= rateValue {
            return "star.fill"
        } else {
            return "star"
        }
    }
    
    private func onRateTapped(withRateValue rateValue: Int) {
        self.selectedRate = rateValue
        self.onConfirm(rateValue)
    }
}

extension View {
    func preReviewPopup(
        isPresenting: Binding<Bool>,
        onConfirm: @escaping PreReviewResultCallback
    ) -> some View {
        self.popup(isPresenting: isPresenting,
                   popupContent: { PreReviewPopupView(isPresenting: isPresenting,
                                                      onConfirm: onConfirm) })
    }
}

struct PreReviewPopupView_Previews: PreviewProvider {
    static var previews: some View {
        PreReviewPopupView(
            isPresenting: .constant(true),
            onConfirm: { result in print("Result: \(result)") }
        )
    }
}
