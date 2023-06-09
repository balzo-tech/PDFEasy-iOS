//
//  OnboardingTutorialViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 25/05/23.
//

import Foundation
import Factory

extension Container {
    var onboardingTutorialViewModel: Factory<OnboardingTutorialViewModel> {
        self { OnboardingTutorialViewModel() }
    }
}

struct OnboardingTutorialItem {
    let imageName: String
    let title: String
    let description: String
}

public class OnboardingTutorialViewModel : ObservableObject {
    
    let items: [OnboardingTutorialItem] = [
        OnboardingTutorialItem(
            imageName: "onboarding_tutorial_1",
            title: "Convert files\nto PDF",
            description: "You can convert to pdf a lot of file types from the programs you prefer."
        ),
        OnboardingTutorialItem(
            imageName: "onboarding_tutorial_2",
            title: "Enter and edit your\nsignature",
            description: "Insert your signature in the pdf you created with a single tap."
        ),
        OnboardingTutorialItem(
            imageName: "onboarding_tutorial_3",
            title: "Edit, share and save your\nPDF",
            description: "You can add new pages, edit your pdf, save it and share it with anyone."
        ),
        OnboardingTutorialItem(
            imageName: "onboarding_tutorial_4",
            title: "Protect your files with\npassword",
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
            self.analyticsManager.track(event: .onboardingTutorialCompleted)
            self.closeOnboarding()
        } else {
            self.pageIndex += 1
        }
    }
    
    func skipButtonPressed() {
        self.analyticsManager.track(event: .onboardingTutorialSkipped)
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
