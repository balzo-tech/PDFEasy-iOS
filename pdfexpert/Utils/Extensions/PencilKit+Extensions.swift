//
//  PencilKit+Extensions.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/05/23.
//

import Foundation
import PencilKit

extension PKDrawing {
    
    /**
     Same behaviour as PKDrawing.image(from:scale:), with the only difference that the provided
     UIUserInterfaceStyle will be the one used as reference for color conversion upon image creation.
     
     This is useful to prevent unwanted automatic color conversion of dark colors to bright colors (and vice versa)
     in case of dark mode.
     */
    func image(from rect: CGRect, scale: CGFloat, userInterfaceStyle: UIUserInterfaceStyle) -> UIImage {
        let currentTraits = UITraitCollection.current
        UITraitCollection.current = UITraitCollection(userInterfaceStyle: userInterfaceStyle)
        let image = self.image(from: rect, scale: scale)
        UITraitCollection.current = currentTraits
        return image
    }
}
