//
//  PdfCoordinator.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import Foundation
import Factory

class PdfCoordinator: ObservableObject {
    
    enum RootView {
        case edit
    }
    
    enum Route: Hashable {
        case viewer(pdf: Pdf, marginOption: MarginsOption, quality: CGFloat)
    }
    
    @Published var rootView: RootView = .edit
    @Published var path: [Route] = []
    
    func showViewer(pdf: Pdf, marginOption: MarginsOption, quality: CGFloat) {
        self.path.append(.viewer(pdf: pdf, marginOption: marginOption, quality: quality))
    }
    
    func goBack(fromRoute route: Route) {
        if let firstRouteIndex = self.path.firstIndex(of: route) {
            self.path.removeSubrange(firstRouteIndex..<self.path.count)
        }
    }
}

extension Container {
    var pdfCoordinator: Factory<PdfCoordinator> {
        self { PdfCoordinator() }.singleton
    }
}
