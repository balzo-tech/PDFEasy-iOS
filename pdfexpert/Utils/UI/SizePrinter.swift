//
//  SizePrinter.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 01/06/23.
//

import Foundation
import SwiftUI

struct SizePrinter: ViewModifier {
    
    @State var size: CGSize = .zero { didSet { print("SizePrinter - size: \(self.size)") } }
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear // we just want the reader to get triggered, so let's use an empty color
                        .onAppear {
                            self.size = proxy.size
                        }
                }
            )
    }
}

extension View {
    func printSize() -> some View {
        modifier(SizePrinter())
    }
}
