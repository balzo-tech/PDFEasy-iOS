//
//  PdfScanUtility.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/05/23.
//

import Foundation
import SwiftUI
import WeScan

class PdfScanUtility {
    
    static func convertScan(scannerResult: ScannerResult, asyncOperation: Binding<AsyncOperation<PdfEditable, SharedLocalizedError>>) {
        guard let imageScannerResult = scannerResult.results else {
            if let error = scannerResult.error {
                debugPrint(for: type(of: Self.self), message: "Scan failed. Error: \(error)")
                asyncOperation.wrappedValue = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            } else {
                asyncOperation.wrappedValue = AsyncOperation(status: .empty)
            }
            return
        }
        
        asyncOperation.wrappedValue = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        
        var scan = imageScannerResult.croppedScan
        
        if imageScannerResult.doesUserPreferEnhancedScan, let enhancedScan = imageScannerResult.enhancedScan {
            scan = enhancedScan
        }
        
        scan.generatePDFData { result in
            switch result {
            case .success(let data):
                guard let pdfEditable = PdfEditable(data: data) else {
                    asyncOperation.wrappedValue = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
                    return
                }
                asyncOperation.wrappedValue = AsyncOperation(status: .data(pdfEditable))
            case .failure(let error):
                debugPrint(for: Self.self, message: "Scan to pdf conversion failed. Error: \(error.localizedDescription)")
                asyncOperation.wrappedValue = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            }
        }
    }
}
