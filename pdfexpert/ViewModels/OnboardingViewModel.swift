//
//  OnboardingViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/04/23.
//

import Foundation
import Factory

extension Container {
    var onboardingViewModel: Factory<OnboardingViewModel> {
        self { OnboardingViewModel() }.shared
    }
}

public class OnboardingViewModel : ObservableObject {
    
    @Published var monetizationShow: Bool = false
    @Published var pageIndex = 0
    
    @Injected(\.store) private var store
    @Injected(\.coordinator) private var coordinator
    @Injected(\.cacheManager) private var cacheManager
    @Injected(\.analyticsManager) private var analyticsManager
    
    let questions: [OnboardingQuestion] = OnboardingQuestion.allCases
    
    private var selectedOptions: [OnboardingQuestion: OnboardingOption] = [:]
    
    func onMonetizationClose() {
        self.coordinator.goHome()
    }
    
    func selectOption(forQuestion question: OnboardingQuestion, option: OnboardingOption) {
        self.selectedOptions[question] = option
        if self.selectedOptions.count == self.questions.count {
            
            self.cacheManager.onboardingShown = true
            self.analyticsManager.track(event: .onboardingCompleted(results: self.selectedOptions))
            
            if self.store.isPremium.value {
                self.coordinator.goHome()
            } else {
                self.monetizationShow = true
            }
            
        } else {
            self.pageIndex += 1
        }
    }
}
