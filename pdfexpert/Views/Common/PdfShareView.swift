//
//  PdfShareView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/07/23.
//

import SwiftUI
import Factory

struct PdfShareView: ViewModifier {
    
    @ObservedObject var coordinator: PdfShareCoordinator

    func body(content: Content) -> some View {
        content
            .showSubscriptionView(self.$coordinator.monetizationShow, onComplete: { self.coordinator.onMonetizationClose() })
            .sharePdf(self.$coordinator.pdfToBeShared, applyPostProcess: false)
    }
}

extension View {
    func showShareView(coordinator: PdfShareCoordinator) -> some View {
        modifier(PdfShareView(coordinator: coordinator))
    }
}

struct PdfShareView_Previews: PreviewProvider {
    
    static let coordinator: PdfShareCoordinator
    = Container.shared.pdfShareCoordinator(PdfShareCoordinator.Params(applyPostProcess: false))
    
    static var previews: some View {
        Color(.white)
            .showShareView(coordinator: Self.coordinator)
    }
}
