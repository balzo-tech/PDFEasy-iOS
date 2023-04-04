//
//  Coordinator.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 24/02/23.
//

import Foundation
import SwiftUI
import Factory

class Coordinator: ObservableObject {
    
    @Published var path: [Route] = []
    @Published var monetizationShown = false
    
    @Injected(\.cacheManager) private var cacheManager
    
    init() {
        if self.cacheManager.onboardingShown {
            self.goHome()
        } else {
            self.goToWelcome()
        }
    }
    
    func goToBack() {
        guard self.path.count > 1 else {
            return
        }
        self.path.removeLast()
    }
    
    func goToWelcome() {
        self.path = [.welcome]
    }
    
    func showOnboarding() {
        self.path.append(.onboarding)
    }
    
    func goHome() {
        self.path = [.home]
    }
    
    func showMonetizationView() {
        self.monetizationShown = true
    }
    
    func dismissMonetizationView() {
        self.monetizationShown = false
    }
    
    func showProfile() {
        self.path.append(.profile)
    }
}

extension Container {
    var coordinator: Factory<Coordinator> {
        self { Coordinator() }.singleton
    }
}
