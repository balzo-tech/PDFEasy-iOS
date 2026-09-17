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
    /// Closing the browser without choosing anything. Optional because most
    /// callers have nothing to do about it — but it is the outcome that was
    /// invisible: a document that lives in a mail, in a chat or on a computer
    /// cannot be picked here, and the person backs out of an empty folder.
    let onCancelled: (() -> Void)?
    
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
        FilePickerCoordinator(onPickedFiles: self.onPickedFiles, onCancelled: self.onCancelled)
    }
}

class FilePickerCoordinator: NSObject, UIDocumentPickerDelegate {
    
    let onPickedFiles: FilePickerCallback
    let onCancelled: (() -> Void)?

    init(onPickedFiles: @escaping FilePickerCallback, onCancelled: (() -> Void)? = nil) {
        self.onPickedFiles = onPickedFiles
        self.onCancelled = onCancelled
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.onPickedFiles(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.onCancelled?()
    }
}

extension View {
    @ViewBuilder func filePicker(isPresented: Binding<Bool>,
                                 fileTypes: [UTType],
                                 multipleSelection: Bool = false,
                                 onPickedFiles: @escaping FilePickerCallback,
                                 onCancelled: (() -> Void)? = nil) -> some View {
        if UIDevice.hasDesktopClassLayout {
            self.sheet(isPresented: isPresented) {
                FilePicker(fileTypes: fileTypes,
                           multipleSelection: multipleSelection,
                           onPickedFiles: onPickedFiles,
                           onCancelled: onCancelled)
            }
        } else {
            self.fullScreenCover(isPresented: isPresented) {
                FilePicker(fileTypes: fileTypes,
                           multipleSelection: multipleSelection,
                           onPickedFiles: onPickedFiles,
                           onCancelled: onCancelled)
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
                                                               onPickedFiles: @escaping FilePickerCallback,
                                                               onCancelled: (() -> Void)? = nil) -> some View {
        if UIDevice.hasDesktopClassLayout {
            self.sheet(item: item) {
                FilePicker(fileTypes: $0.fileTypes,
                           multipleSelection: multipleSelection,
                           onPickedFiles: onPickedFiles,
                           onCancelled: onCancelled)
            }
        } else {
            self.fullScreenCover(item: item) {
                FilePicker(fileTypes: $0.fileTypes,
                           multipleSelection: multipleSelection,
                           onPickedFiles: onPickedFiles,
                           onCancelled: onCancelled)
            }
        }
    }
}
