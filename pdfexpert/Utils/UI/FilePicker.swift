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

typealias FilePickerCallback = ([URL]) -> ()

struct FilePicker: UIViewControllerRepresentable {
    
    let fileTypes: [UTType]
    let multipleSelection: Bool
    let onPickedFiles: FilePickerCallback
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: self.fileTypes, asCopy: true)
        controller.allowsMultipleSelection = self.multipleSelection
        controller.shouldShowFileExtensions = true
        controller.view.backgroundColor = UIColor(ColorPalette.primaryBG)
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    func makeCoordinator() -> FilePickerCoordinator {
        FilePickerCoordinator(onPickedFiles: self.onPickedFiles)
    }
}

class FilePickerCoordinator: NSObject, UIDocumentPickerDelegate {
    
    let onPickedFiles: FilePickerCallback

    init(onPickedFiles: @escaping FilePickerCallback) {
        self.onPickedFiles = onPickedFiles
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.onPickedFiles(urls)
    }
}

extension View {
    @ViewBuilder func filePicker(isPresented: Binding<Bool>,
                                 fileTypes: [UTType],
                                 multipleSelection: Bool = false,
                                 onPickedFiles: @escaping FilePickerCallback) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.sheet(isPresented: isPresented) {
                FilePicker(fileTypes: fileTypes, multipleSelection: multipleSelection, onPickedFiles: onPickedFiles)
            }
        } else {
            self.fullScreenCover(isPresented: isPresented) {
                FilePicker(fileTypes: fileTypes, multipleSelection: multipleSelection, onPickedFiles: onPickedFiles)
            }
        }
    }
}

protocol FilePickerTypeProvider: Identifiable {
    var fileTypes: [UTType] { get }
}

extension View {
    @ViewBuilder func filePicker<Item: FilePickerTypeProvider>(item: Binding<Item?>,
                                                               multipleSelection: Bool = false,
                                                               onPickedFiles: @escaping FilePickerCallback) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.sheet(item: item) {
                FilePicker(fileTypes: $0.fileTypes, multipleSelection: multipleSelection, onPickedFiles: onPickedFiles)
            }
        } else {
            self.fullScreenCover(item: item) {
                FilePicker(fileTypes: $0.fileTypes, multipleSelection: multipleSelection, onPickedFiles: onPickedFiles)
            }
        }
    }
}
