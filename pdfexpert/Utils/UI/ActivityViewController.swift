//
//  ActivityViewController.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 30/03/23.
//

import SwiftUI
import UIKit
import LinkPresentation


struct ActivityViewController: UIViewControllerRepresentable {

    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var thumbnail: UIImage? = nil
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        var activityItems: [Any] = self.activityItems
        activityItems.append(self.makeCoordinator())
        let controller = UIActivityViewController(activityItems: activityItems,
                                                  applicationActivities: self.applicationActivities)
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            self.presentationMode.wrappedValue.dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
    
    func makeCoordinator() -> ActivityCoordinator {
        ActivityCoordinator(thumbnail: self.thumbnail)
    }
}

class ActivityCoordinator: NSObject, UIActivityItemSource {
    
    var thumbnail: UIImage? = nil

    init(thumbnail: UIImage?) {
        self.thumbnail = thumbnail
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return ""
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return nil
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        guard let thumbnail = self.thumbnail else { return nil }
        let metadata = LPLinkMetadata()
        metadata.imageProvider = NSItemProvider(object: thumbnail)
        return metadata
    }
}

struct ActivityViewController_Previews: PreviewProvider {
    static var previews: some View {
        ActivityViewController(activityItems: [URL(string: "https://www.apple.com")!])
    }
}
