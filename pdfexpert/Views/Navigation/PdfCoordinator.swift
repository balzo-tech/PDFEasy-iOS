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
    
    @Published var rootView: RootView = .edit
}

extension Container {
    var pdfCoordinator: Factory<PdfCoordinator> {
        self { PdfCoordinator() }.shared
    }
}
