//
//  ImportOption.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/07/23.
//

import Foundation
import SwiftUI

enum ImportOption: Hashable, Identifiable {
    
    var id: Self { return self }
    
    case camera
    case gallery
    case scan
    case file(fileSource: FileSource)
}

enum ImportOptionGroup: Hashable, Identifiable {
    
    var id: Self { return self }
    
    case image
    case fileAndScan
    
    var options: [ImportOption] {
        switch self {
        case .image: return [.camera, .gallery, .file(fileSource: .files)]
        case .fileAndScan: return [.file(fileSource: .files), .scan]
        }
    }
}

extension ImportView {
    
    @ViewBuilder static func getImportView(forImportOptionGroup importOptionGroup: ImportOptionGroup,
                                           importViewCallback: @escaping (ImportOption) -> ()) -> some View {
        ImportView(items: importOptionGroup.options.map { importOption in
            let callback = { importViewCallback(importOption) }
            switch importOption {
            case .camera:
                return ImportItem(title: "Camera",
                                  imageName: "camera",
                                  callBack: callback)
            case .gallery:
                return ImportItem(title: "Gallery",
                                  imageName: "gallery",
                                  callBack: callback)
            case .scan:
                return ImportItem(title: "Scan a file",
                           imageName: "scan",
                           callBack: callback)
            case .file(let fileSource):
                switch fileSource {
                case .google:
                    return ImportItem(title: "Google Drive",
                               imageName: "home_file_source_google",
                               callBack: callback)
                case .dropbox:
                    return ImportItem(title: "Dropbox",
                               imageName: "home_file_source_dropbox",
                               callBack: callback)
                case .icloud:
                    return ImportItem(title: "iCloud",
                               imageName: "home_file_source_icloud",
                               callBack: callback)
                case .files:
                    return ImportItem(title: "Files",
                               imageName: "home_file_source_files",
                               callBack: callback)
                }
            }
        })
    }
}
