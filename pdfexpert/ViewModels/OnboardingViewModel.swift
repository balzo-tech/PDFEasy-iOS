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
    let illustration: OnboardingIllustration
    let title: String
    let description: String
}

public class OnboardingViewModel : ObservableObject {
    
    /// The four things the app is for, in the order someone reaches for them.
    /// Scanning leads because it is the one thing people open this app for while
    /// standing over a piece of paper — and because it was missing here entirely,
    /// while a page still advertised a password screen.
    ///
    /// Every string goes through `String(localized:)`: these are handed to
    /// `Text` as plain `String`s, and that overload does not localize. The four
    /// sentences this replaced were English in every language for that reason.
    let items: [OnboardingItem] = [
        OnboardingItem(
            illustration: .scan,
            title: String(localized: "Scan anything into a PDF"),
            description: String(localized: "Point the camera at a page. It comes out straight, sharp and ready to send.")
        ),
        OnboardingItem(
            illustration: .convert,
            title: String(localized: "Turn any file into a PDF"),
            description: String(localized: "Documents, spreadsheets, slides and photos — converted on your phone, not on a server.")
        ),
        OnboardingItem(
            illustration: .signature,
            title: String(localized: "Sign without printing"),
            description: String(localized: "Draw your signature once, then place it on any document with a tap.")
        ),
        OnboardingItem(
            illustration: .chat,
            title: String(localized: "Ask your document"),
            description: String(localized: "The short version of a long PDF, or the one answer you were looking for.")
        ),
        OnboardingItem(
            illustration: .toolbox,
            // Counted, not written down. A number typed into a sentence is wrong
            // the first time someone adds a tool, and nothing tells you — and
            // this one moves on its own anyway: the tools that need the online
            // service leave the catalog when it is switched off.
            title: String(localized: "\(ToolCatalog.allTools.count) tools in one app"),
            description: String(localized: "Merge, split, compress, protect, redact, read aloud — and all of it on your phone.")
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
