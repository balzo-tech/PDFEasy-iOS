//
//  View+Alert.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 24/02/23.
//

import Foundation
import SwiftUI

extension View {
    func errorAlert<T, E>(asyncOperation: Binding<AsyncOperation<T, E>>, buttonTitle: String = "OK") -> some View {
        var localizedError: E? = nil
        switch asyncOperation.wrappedValue.status {
        case .error(let error): localizedError = error
        default: break
        }
        return alert("Error", isPresented: .constant(localizedError != nil), presenting: localizedError) { _ in
            Button(buttonTitle) {
                asyncOperation.wrappedValue = AsyncOperation(status: .empty)
            }
        } message: { localizedError in
            Text(localizedError.errorDescription ?? "")
        }
    }
}
