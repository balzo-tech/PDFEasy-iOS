//
//  ContentView.swift
//  OpenAI chat-dalle
//
//  Created by kz on 07/02/2023.
//

import SwiftUI
import Factory

struct ContentView: View {
    
    @Injected(\.appTrackingTransparancy) var appTrackingTransparency
    @InjectedObject(\.mainCoordinator) var coordinator
    @Injected(\.store) var store
    @Injected(\.configService) var configService
    @Injected(\.attibutionManager) var attibutionManager
    
    var body: some View {
        self.content
            .background(ColorPalette.primaryBG)
            .reviewFlowView(flow: self.coordinator.reviewFlow)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task {
                    await self.appTrackingTransparency.requestPermissionIfNeeded()
                }
                self.configService.onApplicationDidBecomeActive()
            }
            .onOpenURL { url in
                self.coordinator.handleOpenUrl(url: url)
                self.attibutionManager.onOpenUrl(url: url)
            }
    }
    
    var content: some View {
        switch self.coordinator.rootView {
        case .onboarding:
            return AnyView(
                NavigationStack(path: self.$coordinator.path) {
                    WelcomeView()
                        .navigationDestination(for: MainCoordinator.Route.self) { route in
                            switch route {
                            case .onboarding:
                                OnboardingView()
                            }
                        }
                }
            )
        case .main:
            return AnyView(MainTabView())
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
