//
//  ShareViewController.swift
//  ShareFileExtension
//
//  Created by Leonardo Passeri on 05/05/23.
//

import UIKit
import UniformTypeIdentifiers
import PDFKit

class ShareViewController: UIViewController {

    @IBOutlet weak var pdfContainerView: UIView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var openButton: UIButton!
    
    private let pdfView = PDFView()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.openButton.addTarget(self, action: #selector(self.onOpenButtonPressed), for: .touchUpInside)
        self.activityIndicatorView.isHidden = true
        self.openButton.isHidden = true
        self.pdfContainerView.isHidden = true
        
        self.pdfContainerView.addSubview(self.pdfView)
        self.pdfView.translatesAutoresizingMaskIntoConstraints = false
        self.pdfContainerView.addConstraint(NSLayoutConstraint(item: self.pdfView,
                                                               attribute: .top,
                                                               relatedBy: .equal,
                                                               toItem: self.pdfContainerView,
                                                               attribute: .top,
                                                               multiplier: 1,
                                                               constant: 0))
        self.pdfContainerView.addConstraint(NSLayoutConstraint(item: self.pdfView,
                                                               attribute: .bottom,
                                                               relatedBy: .equal,
                                                               toItem: self.pdfContainerView,
                                                               attribute:.bottom,
                                                               multiplier: 1,
                                                               constant: 0))
        self.pdfContainerView.addConstraint(NSLayoutConstraint(item: self.pdfView,
                                                               attribute: .leading,
                                                               relatedBy: .equal,
                                                               toItem: self.pdfContainerView,
                                                               attribute: .leading,
                                                               multiplier: 1, constant: 0))
        self.pdfContainerView.addConstraint(NSLayoutConstraint(item: self.pdfView, attribute: .trailing,
                                                               relatedBy: .equal,
                                                               toItem: self.pdfContainerView,
                                                               attribute: .trailing,
                                                               multiplier: 1,
                                                               constant: 0))
        
        self.loadFile()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // MARK: - Private Methods
    
    private func loadFile() {
        
        self.activityIndicatorView.isHidden = false
        
        if let extensionContext = extensionContext {
            debugPrint("ShareViewController - Extension Context exist...")
            if let item = extensionContext.inputItems.first as? NSExtensionItem, let itemProvider = item.attachments?.first {
                
                if itemProvider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    itemProvider.loadItem(
                        forTypeIdentifier: UTType.pdf.identifier,
                        options: nil,
                        completionHandler: { [weak self](result, error) in
                            
                            guard let result = result else {
                                debugPrint("ShareViewController - Missing results")
                                return
                            }
                            
                            if let error = error {
                                debugPrint("ShareViewController - Coulnd't load file. Error: \(error.localizedDescription)")
                                return
                            }
                            
                            var pdfDocument: PDFDocument?
                            
                            if let url = result as? URL {
                                pdfDocument = PDFDocument(url: url)
                            }
                            
                            if let data = result as? Data {
                                pdfDocument = PDFDocument(data: data)
                            }
                            
                            if let pdfDocument = pdfDocument {
                                debugPrint("ShareViewController - Successfully retreived pdf through action extension!")
                                DispatchQueue.main.async {
                                    self?.pdfView.document = pdfDocument
                                    self?.pdfView.autoScales = true
                                    self?.activityIndicatorView.isHidden = true
                                    self?.pdfContainerView.isHidden = false
                                    self?.openButton.isHidden = false
                                }
                            } else {
                                debugPrint("ShareViewController - Failed to convert file to pdf!")
                            }
                        })
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func onOpenButtonPressed() {
        guard let extensionContext = self.extensionContext else {
            assertionFailure("Missing expected extensionContext")
            return
        }
        guard let pdfDocumentData = self.pdfView.document?.dataRepresentation() else {
            assertionFailure("Missing expected pdf document data")
            return
        }
        guard let url = URL(string: "pdfpro://") else {
            assertionFailure("Cannot create url to app")
            return
        }
        SharedStorage.pdfDataShareExtensionExistanceFlag = true
        SharedStorage.pdfDataShareExtension = pdfDocumentData
        let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: Int64(pdfDocumentData.count), countStyle: .file)
        debugPrint("Share Extension - Saved pdf data with size: \(fileSizeWithUnit)")
        if self.openURL(url) {
            extensionContext.completeRequest(returningItems: [], completionHandler: nil)
        } else {
            assertionFailure("Failed to open containing app")
        }
    }
    
    //  Function must be named exactly like this so a selector can be found by the compiler!
    //  Anyway - it's another selector in another instance that would be "performed" instead.
    @objc func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                return application.perform(#selector(openURL(_:)), with: url) != nil
            }
            responder = responder?.next
        }
        return false
    }
}
