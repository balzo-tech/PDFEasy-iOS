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
                    Self.getSystemClose(color: color)
                }
                Spacer()
            }
            .padding(.leading)
            Spacer()
        }
        .padding(.top)
    }
    
    @ViewBuilder func getCustomBackButton(color: Color, onPress: @escaping () -> ()) -> some View {
        self.navigationBarBackButtonHidden()
            .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { onPress() }) {
                    Self.getSystemChevron(color: color, directionRight: false)
                }
            }
        }
    }
    
    static func getAttributedText(forUrlString urlString: String,
                                  text: String) -> AttributedString {
        var attributedString = try! AttributedString(markdown: "[\(text)](\(urlString))")
        attributedString.underlineStyle = .single
        return attributedString
    }
    
    static func getSystemChevron(color: Color, directionRight: Bool = true) -> some View {
        Image(systemName: directionRight ? "chevron.right" : "chevron.left")
            .font(.system(size: 20, weight: .medium, design: .default))
            .foregroundColor(color)
    }
    
    static func getSystemClose(color: Color) -> some View {
        Image(systemName: "xmark")
            .resizable()
            .frame(width: 20, height: 20)
            .foregroundColor(color)
    }
    
    func addSystemCloseButton(color: Color, onPress: @escaping () -> ()) -> some View {
        self.navigationBarBackButtonHidden()
            .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { onPress() }) {
                    Self.getSystemClose(color: color)
                }
            }
        }
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
