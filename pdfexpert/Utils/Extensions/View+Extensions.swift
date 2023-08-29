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
    
    func getEditButton(color: Color, font: Font, editMode: Binding<EditMode>) -> some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        if editMode.wrappedValue == .active {
                            editMode.wrappedValue = .inactive
                        } else {
                            editMode.wrappedValue = .active
                        }
                    }
                }) {
                    Text(editMode.wrappedValue.text)
                        .font(font)
                        .foregroundColor(color)
                }
            }
            .padding(.trailing)
            Spacer()
        }
        .padding(.top)
    }
    
    @ViewBuilder func addCustomBackButton(color: Color, onPress: @escaping () -> ()) -> some View {
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
            .font(.system(size: 16).bold())
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
    
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder func actionDialog<A>(_ title: Text,
                                      isPresented: Binding<Bool>,
                                      titleVisibility: Visibility = .automatic,
                                      @ViewBuilder actions: () -> A) -> some View where A : View {
        // This platform branching is needed because, on iPad, confirmationDialog brokes interaction subsequent modals
        // See: http://openradar.appspot.com/radar?id=5597349300666368
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.alert(title, isPresented: isPresented, actions: actions)
        } else {
            self.confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions)
        }
    }
    
    var isScrollToAvailable: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // ScrollViewProxy.scrollTo() method crashes on certain conditions on iPadOS < 16.4.1
            // https://developer.apple.com/forums/thread/712510
            if #available(iOS 16.4.1, *) {
                return true
            } else {
                return false
            }
        } else {
            return true
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

fileprivate extension EditMode {
    var text: String {
        switch self {
        case .active: return "Done"
        case .inactive: return "Edit"
        case .transient: return ""
        @unknown default: return ""
        }
    }
}
