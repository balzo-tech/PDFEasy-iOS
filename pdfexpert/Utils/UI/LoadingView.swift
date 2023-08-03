//
//  LoadingView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/08/23.
//

import SwiftUI

extension View {
    
    func loadingView(show: Binding<Bool>) -> some View {
        return self.modifier(
            LoadingView(show: show, loadingView: { ProgressView() })
        )
    }
    
    func loadingView<T: View>(
        show: Binding<Bool>,
        @ViewBuilder loadingView: @escaping () -> T) -> some View {
        return self.modifier(
            LoadingView(show: show, loadingView: loadingView)
        )
    }
}

struct LoadingView<T: View>: ViewModifier {
    
    @Binding var show: Bool
    
    var loadingView: (() -> T)
    
    init(show: Binding<Bool>,
         loadingView: @escaping (() -> T)) {
        self._show = show
        self.loadingView = loadingView
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .allowsHitTesting(!self.show)
            if self.show {
                self.loadingView()
            }
        }
    }
}
