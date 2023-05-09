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
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var passwordView: UIStackView!
    @IBOutlet weak var passwordTextField: UITextField!
    
    private let pdfView = PDFView()
    
    private var confirmedPassword: String?
    private var buttonOriginalText: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.activityIndicatorView.startAnimating()
        
        self.button.addTarget(self, action: #selector(self.onButtonPressed), for: .touchUpInside)
        
        self.buttonOriginalText = self.button.title(for: .normal) ?? ""
        
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
        
        self.passwordTextField.delegate = self
        
        self.updateUI()
        self.loadFile()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // MARK: - Private Methods
    
    private func loadFile() {
        
        if let extensionContext = self.extensionContext {
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
                                    self?.updateUI()
                                }
                            } else {
                                debugPrint("ShareViewController - Failed to convert file to pdf!")
                            }
                        })
                }
            }
        }
    }
    
    private func updateUI() {
        if let pdfDocument = self.pdfView.document {
            if pdfDocument.isLocked {
                self.pdfContainerView.isHidden = true
                self.activityIndicatorView.isHidden = true
                self.button.isHidden = false
                self.passwordView.isHidden = false
                self.button.setTitle("Unlock", for: .normal)
            } else {
                self.pdfContainerView.isHidden = false
                self.activityIndicatorView.isHidden = true
                self.button.isHidden = false
                self.passwordView.isHidden = true
                self.button.setTitle(self.buttonOriginalText, for: .normal)
            }
        } else {
            self.pdfContainerView.isHidden = true
            self.activityIndicatorView.isHidden = false
            self.button.isHidden = true
            self.passwordView.isHidden = true
        }
    }
    
    private func unlockPdf(pdfDocument: PDFDocument) {
        let password = self.passwordTextField.text ?? ""
        if pdfDocument.unlock(withPassword: password) {
            debugPrint("Share Extension - Pdf Unlocked!")
            self.confirmedPassword = password
            self.updateUI()
        } else {
            self.passwordTextField.text = nil
            let alert = UIAlertController(title: "Error", message: "Wrong Password", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func sharePdf(pdfDocument: PDFDocument) {
        guard let extensionContext = self.extensionContext else {
            assertionFailure("Missing expected extensionContext")
            return
        }
        
        guard let url = URL(string: "pdfpro://") else {
            assertionFailure("Cannot create url to app")
            return
        }
        
        guard let pdfData = pdfDocument.dataRepresentation() else {
            assertionFailure("Missing expected pdf document data")
            self.showGenericErrorAlert()
            return
        }
        
        SharedStorage.pdfDataShareExtensionExistanceFlag = true
        SharedStorage.pdfDataShareExtension = pdfData
        if let confirmedPassword = self.confirmedPassword {
            SharedStorage.pdfDataShareExtensionPassword = confirmedPassword
        }
        let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: Int64(pdfData.count), countStyle: .file)
        debugPrint("Share Extension - Saved pdf data with size: \(fileSizeWithUnit)")
        if self.openURL(url) {
            extensionContext.completeRequest(returningItems: [], completionHandler: nil)
        } else {
            assertionFailure("Failed to open containing app")
        }
    }
    
    private func showGenericErrorAlert() {
        let alert = UIAlertController(title: "Ooops!", message: "Something went wrong! Please try again later.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Actions
    
    @objc fileprivate func onButtonPressed() {
        guard let pdfDocument = self.pdfView.document else {
            assertionFailure("Missing expected pdf document")
            return
        }
        
        if pdfDocument.isLocked {
            self.unlockPdf(pdfDocument: pdfDocument)
        } else {
            self.sharePdf(pdfDocument: pdfDocument)
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

extension ShareViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.onButtonPressed()
        return true
    }
}
