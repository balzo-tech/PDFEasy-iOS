//
//  PhotoLibrarySaver.swift
//  PdfExpert
//
//  Writes scanned pages to the camera roll.
//
//  Add-only authorization on purpose: saving a scan needs permission to *add* a
//  photo, not to read the user's library, and iOS shows a noticeably softer
//  prompt for the narrower request.
//

import Foundation
import Photos
import UIKit
import UniformTypeIdentifiers

enum PhotoLibrarySaveError: Error {
    /// The user declined, or Screen Time forbids it. The caller offers Settings.
    case notAuthorized
    case failed
}

enum PhotoLibrarySaver {

    /// Saves each image as its own photo, in the order given.
    ///
    /// `keepingTransparency` writes PNG instead of JPEG. A scan has no alpha and
    /// JPEG is the right call for it; a cut-out is nothing *but* alpha, and JPEG
    /// flattens it onto black — the background the tool was asked to remove,
    /// back again, in the camera roll.
    static func save(images: [UIImage], keepingTransparency: Bool = false) async throws {
        guard !images.isEmpty else { return }
        guard await self.requestAddOnlyAuthorization() else {
            throw PhotoLibrarySaveError.notAuthorized
        }

        let type: UTType = keepingTransparency ? .png : .jpeg
        let data = images.compactMap {
            keepingTransparency ? $0.pngData() : $0.jpegData(compressionQuality: K.Misc.ScanJpegQuality)
        }
        guard data.count == images.count else { throw PhotoLibrarySaveError.failed }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                for imageData in data {
                    let request = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    options.uniformTypeIdentifier = type.identifier
                    request.addResource(with: .photo, data: imageData, options: options)
                }
            }
        } catch {
            throw PhotoLibrarySaveError.failed
        }
    }

    private static func requestAddOnlyAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let requested = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return requested == .authorized || requested == .limited
        default:
            return false
        }
    }
}
