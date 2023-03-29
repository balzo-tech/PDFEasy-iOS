//
//  HomeView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/03/23.
//

import SwiftUI
import Factory
import PopupView

struct HomeView: View {
    
    @InjectedObject(\.homeViewModel) var homeViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            HomeItemView(title: "Convert\npicture to PDF",
                         buttonText: "Start to convert",
                         onButtonPressed: { self.homeViewModel.convertImageToPdf() })
            HomeItemView(title: "Convert\nWord to PDF",
                         buttonText: "Start to convert",
                         onButtonPressed: { self.homeViewModel.convertWordToPdf() })
            HomeItemView(title: "PDF\nScanner",
                         buttonText: "Start to scan",
                         onButtonPressed: { self.homeViewModel.scanPdf() })
            Spacer()
        }
        .background(ColorPalette.primaryBG)
        .popup(isPresented: self.$homeViewModel.imageToPdfPickerShow) {
            ImportView(onFileImportPressed: { self.homeViewModel.openFilePicker() },
                       onCameraImportPressed: { self.homeViewModel.openCamera() },
                       onGalleryImportPressed: { self.homeViewModel.openGallery() })
        } customize: {
            $0
                .type(.toast)
                .closeOnTapOutside(true)
                .closeOnTap(false)
                .backgroundColor(ColorPalette.primaryBG.opacity(0.5))
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
