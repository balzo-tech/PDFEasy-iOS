//
//  ActivityViewController.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 30/03/23.
//

import SwiftUI
import UIKit

struct ActivityViewController: UIViewControllerRepresentable {

    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            self.presentationMode.wrappedValue.dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}

}

struct ActivityViewController_Previews: PreviewProvider {
    static var previews: some View {
        ActivityViewController(activityItems: [URL(string: "https://www.apple.com")!])
    }
}
