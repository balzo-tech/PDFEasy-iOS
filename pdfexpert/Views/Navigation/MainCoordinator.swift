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
}

struct PdfEditFlowData: Hashable, Identifiable {
    
    var id: Self { return self }
    
    let pdf: Pdf
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
    @Published var settingsShow: Bool = false
    
    @Injected(\.cacheManager) private var cacheManager
    @Injected(\.reviewFlow) var reviewFlow
    
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
    
    func showPdfEditFlow(pdf: Pdf, startAction: PdfEditStartAction? = nil, isNewPdf: Bool) {
        self.pdfEditFlowData = PdfEditFlowData(pdf: pdf, startAction: startAction, isNewPdf: isNewPdf)
    }
    
    func closePdfEditFlow() {
        self.pdfEditFlowData = nil
    }
    
    func handleOpenUrl(url: URL) {
        if let deeplink = Deeplink(fromCustomUrl: url) {
            self.handleDeeplink(deeplink: deeplink)
        }
    }
    
    func startReview() {
        self.reviewFlow.startFlowIfNeeded()
    }
    
    private func handleDeeplink(deeplink: Deeplink) {
        switch deeplink {
        case .chatPdf:
            self.cacheManager.onboardingShown = true
            self.rootView = .main
            self.tab = .chatPdf
        }
    }
}

extension Container {
    var mainCoordinator: Factory<MainCoordinator> {
        self { MainCoordinator() }.singleton
    }
}
