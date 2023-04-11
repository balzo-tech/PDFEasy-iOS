//
//  MainCoordinator.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 24/02/23.
//

import Foundation
import SwiftUI
import Factory

class MainCoordinator: ObservableObject {
    
    enum RootView {
        case onboarding
        case main
    }
    
    enum Route: Hashable {
        case onboarding
    }
    
    @Published var rootView: RootView = .onboarding
    @Published var path: [Route] = []
    
    @Injected(\.cacheManager) private var cacheManager
    
    init() {
        if self.cacheManager.onboardingShown {
            self.rootView = .main
        } else {
            self.rootView = .onboarding
        }
    }
    
    func showOnboarding() {
        self.path.append(.onboarding)
    }
    
    func goToMain() {
        self.rootView = .main
    }
}

extension Container {
    var mainCoordinator: Factory<MainCoordinator> {
        self { MainCoordinator() }.singleton
    }
}
