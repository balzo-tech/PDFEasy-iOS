//
//  FormSheet.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 14/06/23.
//

import SwiftUI

class FormSheetWrapper<Content: View>: UIViewController, UIPopoverPresentationControllerDelegate {

    var size: CGSize
    var content: () -> Content
    var onDismiss: (() -> Void)?

    private var hostVC: UIHostingController<Content>?

    required init?(coder: NSCoder) { fatalError("") }

    init(size: CGSize, content: @escaping () -> Content) {
        self.size = size
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    func show() {
        guard hostVC == nil else { return }
        let vc = UIHostingController(rootView: content())

        vc.preferredContentSize = self.size
        vc.modalPresentationStyle = .formSheet
        vc.presentationController?.delegate = self
        hostVC = vc
        self.present(vc, animated: true, completion: nil)
    }

    func hide() {
        guard let vc = self.hostVC, !vc.isBeingDismissed else { return }
        dismiss(animated: true, completion: nil)
        hostVC = nil
    }

    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        hostVC = nil
        self.onDismiss?()
    }
}

struct FormSheet<Content: View> : UIViewControllerRepresentable {

    @Binding var show: Bool
    let size: CGSize

    let content: () -> Content

    func makeUIViewController(context: UIViewControllerRepresentableContext<FormSheet<Content>>) -> FormSheetWrapper<Content> {

        let vc = FormSheetWrapper(size: self.size, content: content)
        vc.onDismiss = { self.show = false }
        return vc
    }

    func updateUIViewController(_ uiViewController: FormSheetWrapper<Content>,
                                context: UIViewControllerRepresentableContext<FormSheet<Content>>) {
        if show {
            uiViewController.show()
        }
        else {
            uiViewController.hide()
        }
    }
}

extension View {
    @ViewBuilder public func formSheet<Content: View>(isPresented: Binding<Bool>,
                                         size: CGSize,
                                         @ViewBuilder content: @escaping () -> Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.background(FormSheet(show: isPresented,
                                      size: size,
                                      content: content))
        } else {
            self.sheet(isPresented: isPresented) {
                content()
                    .presentationDetents([.height(size.height)])
            }
        }
    }
}
