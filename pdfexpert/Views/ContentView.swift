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
    @InjectedObject(\.coordinator) var coordinator
    @Injected(\.store) var store
    
    var body: some View {
        self.content
            .background(ColorPalette.primaryBG)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task {
                    await self.appTrackingTransparency.requestPermissionIfNeeded()
                }
            }
    }
    
    var content: some View {
        switch self.coordinator.rootView {
        case .onboarding:
            return AnyView(
                NavigationStack(path: self.$coordinator.onboardingPath) {
                    WelcomeView()
                        .navigationDestination(for: OnboardingRoute.self) { route in
                            switch route {
                            case .onboarding: OnboardingView()
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
