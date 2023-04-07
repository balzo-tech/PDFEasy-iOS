//
//  Coordinator.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 24/02/23.
//

import Foundation
import SwiftUI
import Factory

enum RootView {
    case onboarding
    case main
}

class Coordinator: ObservableObject {
    
    @Published var rootView: RootView = .onboarding
    
    @Published var onboardingPath: [OnboardingRoute] = []
    @Published var monetizationShown = false
    
    @Injected(\.cacheManager) private var cacheManager
    
    init() {
        if self.cacheManager.onboardingShown {
            self.rootView = .main
        } else {
            self.rootView = .onboarding
        }
    }
    
    func showOnboarding() {
        self.onboardingPath.append(.onboarding)
    }
    
    func goToMain() {
        self.rootView = .main
    }
    
    func showMonetizationView() {
        self.monetizationShown = true
    }
    
    func dismissMonetizationView() {
        self.monetizationShown = false
    }
}

extension Container {
    var coordinator: Factory<Coordinator> {
        self { Coordinator() }.singleton
    }
}
