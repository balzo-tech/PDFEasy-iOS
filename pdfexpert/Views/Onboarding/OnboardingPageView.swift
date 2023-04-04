//
//  OnboardingPageView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/04/23.
//

import SwiftUI

protocol OnboardingOptionView: OnboardingOption {
    var id: String { get }
    var displayText: String { get }
    var displayImageName: String { get }
}

protocol OnboardingQuestionView {
    var title: String { get }
    var subtitle: String { get }
    var options: [any OnboardingOptionView] { get }
}

struct OnboardingPageView: View {
    
    let question: OnboardingQuestionView
    let onButtonPressed: (OnboardingOption) -> ()
    
    @State var selectedOption: OnboardingOptionView? = nil
    
    var buttonEnabled: Bool { self.selectedOption != nil }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                Text(self.question.title)
                    .font(FontPalette.fontBold(withSize: 22))
                    .foregroundColor(ColorPalette.primaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer().frame(height: 16)
                VStack(spacing: 0) {
                    Text(self.question.subtitle)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .font(FontPalette.fontRegular(withSize: 15))
                        .foregroundColor(ColorPalette.primaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }.frame(height: 64)
            }
            List() {
                ForEach(self.question.options, id: \.displayText) { option in
                    Button(action: { self.selectedOption = option }) {
                        HStack(spacing: 20) {
                            Image(option.displayImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            Text(option.displayText)
                                .font(FontPalette.fontRegular(withSize: 15))
                                .foregroundColor(ColorPalette.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding([.leading, .trailing], 20)
                    }
                    .frame(height: 48)
                    .background(self.getItemBackground(forOption: option))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .cornerRadius(10)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }
                .frame(maxWidth: .infinity)
            }
            .background(ColorPalette.primaryBG)
            .scrollIndicators(.never)
            .listStyle(.plain)
            Spacer(minLength: 30)
            Button(action: {
                if let selectedOption = self.selectedOption {
                    self.onButtonPressed(selectedOption)
                }
            }) {
                Text("Next")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .font(FontPalette.fontBold(withSize: 16))
                    .foregroundColor(ColorPalette.primaryText)
                    .contentShape(Capsule())
            }
            .disabled(!self.buttonEnabled)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(self.buttonBackground)
            .cornerRadius(10)
        }
        .padding([.leading, .trailing], 16)
    }
    
    var buttonBackground: some View {
        self.buttonEnabled
        ? AnyView(self.defaultGradientBackground)
        : AnyView(ColorPalette.thirdText)
    }
    
    func getItemBackground(forOption option: any OnboardingOptionView) -> some View {
        self.selectedOption?.id == option.id
        ? AnyView(self.defaultGradientBackground)
        : AnyView(ColorPalette.secondaryBG)
    }
}

struct OnboardingPageView_Previews: PreviewProvider {
    
    static var previews: some View {
        OnboardingPageView(question: OnboardingQuestion.role, onButtonPressed: { _ in })
            .background(ColorPalette.primaryBG)
    }
}
