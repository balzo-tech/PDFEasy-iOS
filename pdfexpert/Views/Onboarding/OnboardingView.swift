//
//  OnboardingView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/04/23.
//

import SwiftUI
import Factory
import PagerTabStripView

struct OnboardingView: View {
    
    @InjectedObject(\.onboardingViewModel) var onboardingViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            PageControl(currentPageIndex: self.onboardingViewModel.pageIndex,
                        numberOfPages: self.onboardingViewModel.questions.count,
                        currentPageColor: ColorPalette.buttonGradientStart,
                        normalPageColor: ColorPalette.thirdText)
            PagerTabStripView(
                swipeGestureEnabled: .constant(false),
                selection: self.$onboardingViewModel.pageIndex
            ) {
                ForEach(Array(self.onboardingViewModel.questions.enumerated()), id: \.offset) { index, question in
                    OnboardingPageView(question: question, onButtonPressed: { onboardingOption in
                        self.onboardingViewModel.selectOption(forQuestion: question, option: onboardingOption)
                    })
                    .pagerTabItem(tag: index) { }
                }
            }
            .pagerTabStripViewStyle(.bar() { Color(.clear) })
        }
        .padding(.top, 16)
        .padding(.bottom, 30)
        .background(ColorPalette.primaryBG)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: self.$onboardingViewModel.monetizationShow) {
            SubscriptionView(onComplete: { self.onboardingViewModel.onMonetizationClose() })
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
