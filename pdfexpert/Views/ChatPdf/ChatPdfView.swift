//
//  ChatPdfView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/07/23.
//

import SwiftUI
import Factory

struct ChatPdfView: View {
    
    @InjectedObject(\.chatPdfSelectionViewModel) var viewModel
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .background(ColorPalette.primaryBG)
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: { self.dismiss() })
            .onAppear() {
                self.viewModel.onAppear()
            }
        }
        .background(ColorPalette.primaryBG)
    }
}

struct ChatPdfView_Previews: PreviewProvider {
    static var previews: some View {
        ChatPdfView()
    }
}
