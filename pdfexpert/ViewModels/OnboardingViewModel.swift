//
//  OnboardingViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 25/05/23.
//

import Foundation
import Factory

extension Container {
    var onboardingViewModel: Factory<OnboardingViewModel> {
        self { OnboardingViewModel() }
    }
}

struct OnboardingItem {
    let imageName: String
    let title: String
    let description: String
}

public class OnboardingViewModel : ObservableObject {
    
    let items: [OnboardingItem] = [
        OnboardingItem(
            imageName: "onboarding_chat_pdf",
            title: "Chat with any PDF files",
            description: "You can ask questions to any PDF and get quick insights and clarifications."
        ),
        OnboardingItem(
            imageName: "onboarding_convert",
            title: "Convert files to PDF",
            description: "You can convert to pdf a lot of file types from the programs you prefer."
        ),
        OnboardingItem(
            imageName: "onboarding_signature",
            title: "Enter and edit your signature",
            description: "Insert your signature in the pdf you created with a single tap."
        ),
        OnboardingItem(
            imageName: "onboarding_password",
            title: "Protect your files with password",
            description: "Enter a password to protect your pdf, you can delete it and change it whenever you want."
        ),
    ]
    
    @Published var monetizationShow: Bool = false
    @Published var pageIndex = 0
    
    @Injected(\.store) private var store
    @Injected(\.mainCoordinator) private var coordinator
    @Injected(\.cacheManager) private var cacheManager
    @Injected(\.analyticsManager) private var analyticsManager
    
    func onMonetizationClose() {
        self.coordinator.goToMain()
    }
    
    func continueButtonPressed() {
        if self.pageIndex >= self.items.count - 1 {
            self.analyticsManager.track(event: .onboardingCompleted)
            self.closeOnboarding()
        } else {
            self.pageIndex += 1
        }
    }
    
    func skipButtonPressed() {
        self.analyticsManager.track(event: .onboardingSkipped)
        self.closeOnboarding()
    }
    
    private func closeOnboarding() {
        self.cacheManager.onboardingShown = true
        
        if self.store.isPremium.value {
            self.coordinator.goToMain()
        } else {
            self.monetizationShow = true
        }
    }
}
