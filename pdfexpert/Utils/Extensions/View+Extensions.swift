//
//  View+Extensions.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 10/03/23.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

extension View {
    
    func getCloseButton(color: Color, onClose: @escaping () -> ()) -> some View {
        VStack {
            HStack {
                Button(action: { onClose() }) {
                    Image(systemName: "xmark.circle")
                        .resizable()
                        .frame(width: 34, height: 34.0)
                        .foregroundColor(color)
                }
                Spacer()
            }
            .padding(.leading)
            Spacer()
        }
        .padding(.top)
    }
    
//    func getShopButton(onTap: @escaping () -> ()) -> some View {
//        VStack {
//            HStack {
//                Spacer()
//                Button(action: { onTap() }) {
//                    Image("shop")
//                }
//            }
//            .padding(.trailing)
//            Spacer()
//        }
//        .padding(.top)
//    }
    
    static func getAttributedText(forUrlString urlString: String,
                                  text: String) -> AttributedString {
        var attributedString = try! AttributedString(markdown: "[\(text)](\(urlString))")
        attributedString.underlineStyle = .single
        return attributedString
    }
}

extension Binding where Value == String {
    func max(_ limit: Int) -> Self {
        if self.wrappedValue.count > limit {
            DispatchQueue.main.async {
                self.wrappedValue = String(self.wrappedValue.dropLast())
            }
        }
        return self
    }
}
