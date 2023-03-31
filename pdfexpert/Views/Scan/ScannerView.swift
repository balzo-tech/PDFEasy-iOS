//
//  ScannerView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/03/23.
//

import SwiftUI
import WeScan

struct ScannerView: UIViewControllerRepresentable {
    
    let onScannerResult: ScannerResultCallback
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let controller = ImageScannerController()
        controller.imageScannerDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    func makeCoordinator() -> ScannerViewCoordinator {
        ScannerViewCoordinator(onScannerResult: self.onScannerResult)
    }
}

struct ScannerResult {
    let results: ImageScannerResults?
    let error: Error?
}

typealias ScannerResultCallback = (ScannerResult) -> ()

class ScannerViewCoordinator: NSObject, ImageScannerControllerDelegate {
    
    let onScannerResult: ScannerResultCallback

    init(onScannerResult: @escaping ScannerResultCallback) {
        self.onScannerResult = onScannerResult
    }
    
    func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error) {
        self.onScannerResult(ScannerResult(results: nil, error: error))
    }

    func imageScannerController(_ scanner: ImageScannerController,
                                didFinishScanningWithResults results: ImageScannerResults) {
        self.onScannerResult(ScannerResult(results: results, error: nil))
    }

    func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
        self.onScannerResult(ScannerResult(results: nil, error: nil))
    }
}

struct ScannerView_Previews: PreviewProvider {
    static var previews: some View {
        ScannerView(onScannerResult: { _ in })
    }
}
