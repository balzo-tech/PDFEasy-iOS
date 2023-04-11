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
        case viewer(pdf: Pdf)
    }
    
    @Published var rootView: RootView = .edit
    @Published var path: [Route] = []
    
    func showViewer(pdf: Pdf) {
        self.path.append(.viewer(pdf: pdf))
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
