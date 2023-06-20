//
//  PageControl.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/04/23.
//

import SwiftUI
import UIKit

struct PageControl: UIViewRepresentable {
    
    var currentPageIndex: Int
    var numberOfPages: Int
    var currentPageColor: Color
    var normalPageColor: Color
    var enableInteraction: Bool
    
    func makeUIView(context: Context) -> UIPageControl {
        let pageControl = UIPageControl()
        pageControl.pageIndicatorTintColor = UIColor(self.normalPageColor)
        pageControl.currentPageIndicatorTintColor = UIColor(self.currentPageColor)
        pageControl.numberOfPages = self.numberOfPages
        pageControl.isUserInteractionEnabled = self.enableInteraction
        return pageControl
    }
    
    func updateUIView(_ uiView: UIPageControl, context: Context) {
        uiView.currentPage = self.currentPageIndex
    }
}

struct PageControl_Previews: PreviewProvider {
    static var previews: some View {
        PageControl(currentPageIndex: 0,
                    numberOfPages: 3,
                    currentPageColor: .red,
                    normalPageColor: .blue,
                    enableInteraction: false)
    }
}
