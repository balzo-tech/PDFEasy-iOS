//
//  AsyncView.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation
import SwiftUI

struct AsyncView<T, E: LocalizedError>: View {
    
    @Binding var asyncOperation: AsyncOperation<T, E>
    
    var body: some View {
        switch asyncOperation.status {
        case .empty:
            return AnyView(Color(.clear))
        case .loading: return
            AnyView(
                ZStack {
                    Color(.black).opacity(0.5)
                    ProgressView()
                }
                    .edgesIgnoringSafeArea(.all)
            )
        case .error:
            return AnyView(Color(.clear).errorAlert(asyncOperation: $asyncOperation))
        case .data:
            return AnyView(Color(.clear))
        }
    }
}

fileprivate enum AsyncViewError: LocalizedError {}

struct AsyncView_Previews: PreviewProvider {
    
    @State fileprivate static var testAsyncOperation = AsyncOperation<Void, AsyncViewError>(status: .loading(0.0))
    
    static var previews: some View {
        AsyncView(asyncOperation: $testAsyncOperation)
    }
}
