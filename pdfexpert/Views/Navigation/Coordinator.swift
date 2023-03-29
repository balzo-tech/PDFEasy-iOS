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
    
    init() {
        self.goHome()
    }
    
    func goToBack() {
        guard self.path.count > 1 else {
            return
        }
        self.path.removeLast()
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
}

extension Container {
    var coordinator: Factory<Coordinator> {
        self { Coordinator() }.singleton
    }
}