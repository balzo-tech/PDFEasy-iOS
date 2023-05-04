//
//  ObservableObject+Extensions.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/05/23.
//

import Foundation
import SwiftUI

extension ObservableObject {
    func asyncSubject<T, E>(_ keyPath: WritableKeyPath<Self, AsyncOperation<T, E>>) -> Binding<AsyncOperation<T, E>> {
        let defaultValue = self[keyPath: keyPath]
        return .init(get: { [weak self] in
            self?[keyPath: keyPath] ?? defaultValue
        }, set: { [weak self] in
            self?[keyPath: keyPath] = $0
        })
    }
}
