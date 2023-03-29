//
//  ContentView.swift
//  OpenAI chat-dalle
//
//  Created by kz on 07/02/2023.
//

import SwiftUI
import Factory

struct ContentView: View {
    
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
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
