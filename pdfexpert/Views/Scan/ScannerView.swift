//
//  ScannerView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/03/23.
//

import SwiftUI
import VisionKit

struct ScannerView: UIViewControllerRepresentable {
    
    let onScannerResult: ScannerResultCallback
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
    
    func makeCoordinator() -> ScannerViewCoordinator {
        ScannerViewCoordinator(onScannerResult: self.onScannerResult)
    }
}

struct ScannerResult {
    let scan: VNDocumentCameraScan
}

typealias ScannerResultCallback = (ScannerResult) -> ()

class ScannerViewCoordinator: NSObject, VNDocumentCameraViewControllerDelegate {
    
    let onScannerResult: ScannerResultCallback

    init(onScannerResult: @escaping ScannerResultCallback) {
        self.onScannerResult = onScannerResult
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                      didFinishWith scan: VNDocumentCameraScan) {
        self.onScannerResult(ScannerResult(scan: scan))
    }
}

struct ScannerView_Previews: PreviewProvider {
    static var previews: some View {
        ScannerView(onScannerResult: { _ in })
    }
}
