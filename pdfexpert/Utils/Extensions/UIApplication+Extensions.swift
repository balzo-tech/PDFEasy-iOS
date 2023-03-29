//
//  UIApplication+Extensions.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation
import SwiftUI

extension UIApplication {
    static func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
