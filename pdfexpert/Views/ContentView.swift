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
    
    var body: some View {
        NavigationStack(path: self.$coordinator.path) {
            Color(.clear)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .home:
                        HomeView()
                            .navigationBarHidden(true)
                    }
                }
        }.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await self.appTrackingTransparency.requestPermissionIfNeeded()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
