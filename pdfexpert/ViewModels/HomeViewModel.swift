//
//  HomeViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/03/23.
//

import Foundation
import Factory

extension Container {
    var homeViewModel: Factory<HomeViewModel> {
        self { HomeViewModel() }.shared
    }
}

public class HomeViewModel : ObservableObject {
    
    @Published var imageToPdfPickerShow: Bool = false
    
    @Injected(\.repository) var repository
    
    func convertImageToPdf() {
        self.imageToPdfPickerShow = true
    }
    
    func convertWordToPdf() {
        debugPrint(for: self, message: "TODO: Open File Picker")
    }
    
    func scanPdf() {
        debugPrint(for: self, message: "TODO: Open Scanner")
    }
    
    func openFilePicker() {
        debugPrint(for: self, message: "TODO: Open File Picker")
    }
    
    func openCamera() {
        debugPrint(for: self, message: "TODO: Open Camera")
    }
    
    func openGallery() {
        debugPrint(for: self, message: "TODO: Open Gallery")
    }
}
