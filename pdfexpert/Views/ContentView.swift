//
//  ContentView.swift
//  PdfExpert
//
//  Created by kz on 07/02/2023.
//

import SwiftUI
import Factory

struct ContentView: View {
    
    @InjectedObject(\.mainCoordinator) var coordinator
    @Injected(\.store) var store
    @Injected(\.configService) var configService

    var body: some View {
        self.content
            .background(ColorPalette.primaryBG)
            .reviewFlowView(flow: self.coordinator.reviewFlow)
            // The tracking prompt used to be asked here, on every activation.
            // It is asked once at the end of the onboarding now, where the tour
            // has just said what the app does — see `OnboardingViewModel`.
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                self.configService.onApplicationDidBecomeActive()
            }
            .onOpenURL { url in
                self.coordinator.handleOpenUrl(url: url)
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
            return AnyView(RootShellView())
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
