//
//  SubscriptionPickerView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 08/08/23.
//

import SwiftUI
import Factory

struct SubscriptionPickerView: View {
    
    fileprivate struct SubscriptionFeature: Hashable {
        let imageName: String
        let text: String
    }
    
    private let subscriptionFeatures: [SubscriptionFeature] = [
        SubscriptionFeature(imageName: "subscription_feature_convert",
                       text: "Convert file to PDF"),
        SubscriptionFeature(imageName: "subscription_feature_chat_pdf",
                       text: "Ask any question to PDF and get insights fast"),
        SubscriptionFeature(imageName: "subscription_feature_signature",
                       text: "Enter and edit your signature"),
        SubscriptionFeature(imageName: "subscription_feature_password",
                       text: "Protect your files with password"),
        SubscriptionFeature(imageName: "subscription_feature_edit",
                       text: "Edit, save and share your PDF"),
    ]
    
    @InjectedObject(\.subscriptionPickerViewModel) var viewModel
    
    @State var showPlansPicker: Bool = false
    
    var onComplete: () -> ()
    
    var body: some View {
        ZStack {
            self.getCloseButton(color: ColorPalette.primaryText.opacity(0.3)) {
                self.onComplete()
            }
            self.content
        }
        .background(ColorPalette.primaryBG)
        .asyncView(asyncItem: self.$viewModel.purchaseRequest)
        .asyncView(asyncItem: self.$viewModel.restorePurchaseRequest)
        .onAppear() {
            self.viewModel.onAppear()
        }
        .fullScreenCover(isPresented: self.$showPlansPicker) {
            Button(action: { self.showPlansPicker = false }) {
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 0) {
                        Text("Choose period")
                            .font(FontPalette.fontRegular(withSize: 20))
                            .foregroundColor(ColorPalette.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer().frame(height: 20)
                        ForEach(Array(self.viewModel.subscriptionPlans.enumerated()), id: \.offset) { index, item in
                            VStack(spacing: 0) {
                                self.getSubscriptionPlan(subscriptionPlan: item, index: index)
                                Spacer().frame(height: 21)
                            }
                        }
                    }
                    .padding([.leading, .trailing], 16)
                    .padding(.top, 40)
//                    .cornerRadius(10, corners: [.topLeft, .topRight])
                    .background(ColorPalette.secondaryBG)
                }
            }
            .background(FullScreenClearBackground())
        }
        .onChange(of: self.viewModel.isPremium, perform: { newValue in
            if newValue {
                self.onComplete()
            }
        })
    }
    
    var content: some View {
        switch self.viewModel.asyncSubscriptionPlanPairs.status {
        case .empty: return AnyView(Spacer())
        case .loading: return AnyView(AnimationType.dots.view)
        case .data: return AnyView(self.mainView)
        case .error: return AnyView(SubscriptionErrorView(onButtonPressed: {
            self.viewModel.refresh()
        }))
        }
    }
    
    var mainView: some View {
        VStack(spacing: 0) {
            self.restorePurchaseButton
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 26)
                    Text("Choose a plan")
                        .font(FontPalette.fontRegular(withSize: 16))
                        .foregroundColor(ColorPalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(height: 26)
                    SubscriptionPickerPlanView(subscriptionPlanPickerItem: self.viewModel.currentSubscriptionPlan,
                                               pickerButtonPressed: {
                        self.showPlansPicker = true
                    })
                    Spacer().frame(height: 20)
                    Spacer()
                }
                VStack(spacing: 0) {
                    Text("What you get")
                        .font(FontPalette.fontRegular(withSize: 16))
                        .foregroundColor(ColorPalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(height: 16)
                    ForEach(self.subscriptionFeatures, id:\.self) { feature in
                        VStack(spacing: 0) {
                            self.getSubscriptionFeature(feature: feature)
                            ColorPalette.fourthText.frame(height: 1)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            VStack(spacing: 0) {
                self.freeTrialView
                self.getDefaultButton(text: "Subscribe",
                                      onButtonPressed: { self.viewModel.subscribe() })
                self.currentSubscriptionPlanView
            }
            .background(ColorPalette.primaryBG)
            .padding(.top, 16)
        }
        .padding([.leading, .trailing], 16)
    }
    
    private var restorePurchaseButton: some View {
        Button(action: { self.viewModel.restorePurchases() }) {
            Text("Restore purchase")
                .frame(maxHeight: .infinity)
                .underline()
                .font(FontPalette.fontLight(withSize: 15))
                .foregroundColor(ColorPalette.primaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }
    
    private func getSubscriptionFeature(feature: SubscriptionFeature) -> some View {
        HStack(spacing: 16) {
            Image(feature.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            Text(feature.text)
                .font(FontPalette.fontMedium(withSize: 12))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22).bold())
                .foregroundColor(ColorPalette.buttonGradientStart)
        }
        .frame(height: 52)
    }
    
    private var freeTrialView: some View {
        VStack(spacing: 0) {
            if let currentSubscriptionPlanPair = self.viewModel.currentSubscriptionPlanPair,
               currentSubscriptionPlanPair.standardSubscriptionPlan != nil,
               currentSubscriptionPlanPair.freeTrialSubscriptionPlan != nil {
                SubscriptionFreeTrialToggleView(isFreeTrial: self.$viewModel.isFreeTrialEnabled)
                Spacer().frame(height: 20)
            }
        }
    }
    
    private var currentSubscriptionPlanView: some View {
        Text(self.viewModel.currentSubscriptionPlan?.fullDescriptionText ?? "")
            .font(FontPalette.fontMedium(withSize: 18))
            .foregroundColor(ColorPalette.primaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 40)
            .minimumScaleFactor(0.5)
    }
    
    private func getSubscriptionPlan(subscriptionPlan: SubscriptionPlanPickerItem, index: Int) -> some View {
        ZStack {
            Button(action: {
                self.showPlansPicker = false
                self.viewModel.selectedSubscriptionPairIndex = index
            }) {
                HStack(spacing: 0) {
                    Text(subscriptionPlan.period + " | ")
                        .font(FontPalette.fontMedium(withSize: 18))
                        .foregroundColor(ColorPalette.primaryText)
                    Text(subscriptionPlan.priceText)
                        .font(FontPalette.fontMedium(withSize: 18))
                        .foregroundColor(ColorPalette.thirdText)
                    Spacer()
                    Text(subscriptionPlan.descriptionText)
                        .font(FontPalette.fontRegular(withSize: 12))
                        .foregroundColor(ColorPalette.thirdText)
                }
                .padding(16)
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ColorPalette.fourthText, lineWidth: 1))
            if let bestDiscountText = subscriptionPlan.bestDiscountText {
                HStack {
                    Spacer()
                    GeometryReader { geometry in
                        HStack {
                            Spacer()
                            Text(bestDiscountText)
                                .font(FontPalette.fontRegular(withSize: 12))
                                .foregroundColor(.black)
                                .frame(alignment: .trailing)
                                .padding([.leading, .trailing], 6)
                                .padding([.bottom, .top], 2)
                                .background(ColorPalette.extra)
                                .cornerRadius(2)
                        }.position(x: geometry.size.width/2, y: 0)
                    }
                }
                .padding([.trailing], 16)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
//        .padding([.leading, .trailing], 1)
    }
}

struct SubscriptionPickerView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionPickerView(onComplete: {})
    }
}



struct FullScreenClearBackground: UIViewControllerRepresentable {
    
    public func makeUIViewController(context: UIViewControllerRepresentableContext<Self>) -> UIViewController {
        return Controller()
    }
    
    public func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<Self>) {
    }
    
    class Controller: UIViewController {
        
        override func viewDidLoad() {
            super.viewDidLoad()
            self.view.backgroundColor = .clear
        }
        
        override func willMove(toParent parent: UIViewController?) {
            super.willMove(toParent: parent)
            parent?.view?.backgroundColor = .clear
            parent?.modalPresentationStyle = .overCurrentContext
        }
    }
}
