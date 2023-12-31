//
//  OnboardingView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 25/05/23.
//

import SwiftUI
import PagerTabStripView
import Factory

struct OnboardingView: View {
    
    @InjectedObject(\.onboardingViewModel) var viewModel
    
    @State private var rect: CGRect = .zero
    
    var pageCount: Int { self.viewModel.items.count }
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            PagerTabStripView(selection: self.$viewModel.pageIndex) {
                ForEach(Array(self.viewModel.items.enumerated()), id: \.offset) { index, item in
                    OnboardingPageView(imageName: item.imageName,
                                       title: item.title,
                                       description: item.description)
                    .pagerTabItem(tag: index) { }
                }
            }
            .pagerTabStripViewStyle(.bar() { Color(.clear) })
            Spacer()
            PageControl(currentPageIndex: self.viewModel.pageIndex,
                        numberOfPages: self.pageCount,
                        currentPageColor: ColorPalette.buttonGradientStart,
                        normalPageColor: ColorPalette.buttonGradientStart.opacity(0.3),
                        enableInteraction: false)
            .frame(height: 40)
            Spacer().frame(height: 40)
            self.getDefaultButton(text: "Continue",
                                  onButtonPressed: self.viewModel.continueButtonPressed)
            .padding([.leading, .trailing], 16)
        }
        .padding(.top, 16)
        .padding(.bottom, 64)
        .background(ColorPalette.primaryBG)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { self.viewModel.skipButtonPressed() }) {
                    Text("Skip")
                        .font(forCategory: .body1)
                        .foregroundColor(ColorPalette.primaryText)
                }
            }
        }
        .toolbarBackground(ColorPalette.primaryBG, for: .navigationBar)
        .onAppear() {
            Container.shared.analyticsManager().track(event: .reportScreen(.onboarding))
        }
        .fullScreenCover(isPresented: self.$viewModel.monetizationShow) {
            self.getSubscriptionView(onComplete: {
                self.viewModel.onMonetizationClose()
            })
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
