//
//  View+Preview.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 07/03/23.
//

import Foundation
import SwiftUI

extension View {
    func previewOrientation() -> some View {
        self.previewInterfaceOrientation(.landscapeLeft)
    }
}
