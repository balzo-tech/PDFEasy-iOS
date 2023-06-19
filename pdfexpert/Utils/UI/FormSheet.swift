//
//  FormSheet.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 14/06/23.
//

import SwiftUI

// MARK: - FormSheet Boolean

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

// MARK: - FormSheet Identifiable

public protocol FormSheetItem: Identifiable {
    var viewSize: CGSize { get }
}

class FormSheetWrapperIdentifiable<Content: View, Item: FormSheetItem>: UIViewController, UIPopoverPresentationControllerDelegate {
    
    var content: (Item) -> Content
    var onDismiss: (() -> Void)?

    private var hostVC: UIHostingController<Content>?

    required init?(coder: NSCoder) { fatalError("") }

    init(content: @escaping (Item) -> Content) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    func show(item: Item) {
        guard hostVC == nil else { return }
        let vc = UIHostingController(rootView: content(item))

        vc.preferredContentSize = item.viewSize
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

struct FormSheetIdentifiable<Content: View, Item: FormSheetItem> : UIViewControllerRepresentable {

    @Binding var item: Item?

    let content: (Item) -> Content

    func makeUIViewController(context: UIViewControllerRepresentableContext<FormSheetIdentifiable<Content, Item>>) -> FormSheetWrapperIdentifiable<Content, Item> {

        let vc = FormSheetWrapperIdentifiable(content: content)
        vc.onDismiss = { self.item = nil }
        return vc
    }

    func updateUIViewController(_ uiViewController: FormSheetWrapperIdentifiable<Content, Item>,
                                context: UIViewControllerRepresentableContext<FormSheetIdentifiable<Content, Item>>) {
        if let item = self.item {
            uiViewController.show(item: item)
        }
        else {
            uiViewController.hide()
        }
    }
}

// MARK: - View Extensions

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
    
    @ViewBuilder public func formSheet<Content: View, Item: FormSheetItem>(item: Binding<Item?>,
                                                                          @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.background(FormSheetIdentifiable(item: item,
                                                  content: content))
        } else {
            self.sheet(item: item) { item in
                content(item)
                    .presentationDetents([.height(item.viewSize.height)])
            }
        }
    }
}
