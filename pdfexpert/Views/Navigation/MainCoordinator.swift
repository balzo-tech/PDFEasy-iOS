//
//  MainCoordinator.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 24/02/23.
//

import Foundation
import SwiftUI
import Factory

enum MainTab: Int, CaseIterable {
    case archive
    case home
    case chatPdf
    case settings
}

struct PdfEditFlowData: Hashable, Identifiable {
    
    var id: Self { return self }
    
    let pdfEditable: PdfEditable
    let startAction: PdfEditStartAction?
    let isNewPdf: Bool
}

class MainCoordinator: ObservableObject {
    
    enum RootView {
        case onboarding
        case main
    }
    
    enum Route: Hashable {
        case onboarding
    }
    
    @Published var rootView: RootView = .onboarding
    @Published var tab: MainTab = MainTab.home
    @Published var path: [Route] = []
    @Published var pdfEditFlowData: PdfEditFlowData? = nil
    
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
    
    func goToArchive() {
        self.tab = MainTab.archive
    }
    
    func showPdfEditFlow(pdfEditable: PdfEditable, startAction: PdfEditStartAction? = nil, isNewPdf: Bool) {
        self.pdfEditFlowData = PdfEditFlowData(pdfEditable: pdfEditable, startAction: startAction, isNewPdf: isNewPdf)
    }
    
    func closePdfEditFlow() {
        self.pdfEditFlowData = nil
    }
}

extension Container {
    var mainCoordinator: Factory<MainCoordinator> {
        self { MainCoordinator() }.singleton
    }
}
