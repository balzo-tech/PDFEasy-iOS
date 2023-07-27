//
//  PdfScanUtility.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/05/23.
//

import Foundation
import SwiftUI
import PDFKit

class PdfScanUtility {
    
    static func convertScan(scannerResult: ScannerResult, asyncOperation: Binding<AsyncOperation<PdfEditable, PdfEditableError>>) {
        
        let progress = Progress(totalUnitCount: Int64(scannerResult.scan.pageCount))
        asyncOperation.wrappedValue = AsyncOperation(status: .loading(progress))
        
        DispatchQueue.global(qos: .userInitiated).async {

            let pdfDocument = PDFDocument()
            for pageIndex in 0..<scannerResult.scan.pageCount {
                let pageImage = scannerResult.scan.imageOfPage(at: pageIndex)
                if let page = pageImage.pdfPage() {
                    pdfDocument.insert(page, at: pdfDocument.pageCount)
                }
                
                DispatchQueue.main.async {
                    progress.completedUnitCount = Int64(pageIndex)
                    asyncOperation.wrappedValue = AsyncOperation(status: .loading(progress))
                }
            }
            
            DispatchQueue.main.async {
                asyncOperation.wrappedValue = AsyncOperation(status: .data(PdfEditable(storeId: nil, pdfDocument: pdfDocument)))
            }
        }
    }
}
