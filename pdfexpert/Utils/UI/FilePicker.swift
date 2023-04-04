//
//  FilePicker.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/03/23.
//

import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers.UTType

typealias FilePickerCallback = (URL) -> ()

struct FilePicker: UIViewControllerRepresentable {
    
    let fileTypes: [UTType]
    let onPickedFile: FilePickerCallback
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: self.fileTypes, asCopy: true)
        controller.allowsMultipleSelection = false
        controller.shouldShowFileExtensions = true
        controller.view.backgroundColor = UIColor(ColorPalette.primaryBG)
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    func makeCoordinator() -> FilePickerCoordinator {
        FilePickerCoordinator(onPickedFile: self.onPickedFile)
    }
}

class FilePickerCoordinator: NSObject, UIDocumentPickerDelegate {
    
    let onPickedFile: FilePickerCallback

    init(onPickedFile: @escaping FilePickerCallback) {
        self.onPickedFile = onPickedFile
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        self.onPickedFile(url)
    }
}
