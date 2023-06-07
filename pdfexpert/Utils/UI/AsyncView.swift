//
//  AsyncView.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation
import SwiftUI

extension View {
    
    func asyncView<DataType, ErrorType: LocalizedError>(
        asyncOperation: Binding<AsyncOperation<DataType, ErrorType>>) -> some View {
        return self.modifier(
            AsyncView(asyncOperation: asyncOperation, loadingView: { ProgressView() })
        )
    }
    
    func asyncView<LoadingView: View, DataType, ErrorType: LocalizedError>(
        asyncOperation: Binding<AsyncOperation<DataType, ErrorType>>,
        @ViewBuilder loadingView: @escaping () -> LoadingView) -> some View {
        return self.modifier(
            AsyncView(asyncOperation: asyncOperation, loadingView: loadingView)
        )
    }
}

struct AsyncView<LoadingView: View, DataType, ErrorType: LocalizedError>: ViewModifier {
    
    @Binding var asyncOperation: AsyncOperation<DataType, ErrorType>
    
    var loadingView: (() -> LoadingView)
    
    init(asyncOperation: Binding<AsyncOperation<DataType, ErrorType>>,
         loadingView: @escaping (() -> LoadingView)) {
        self._asyncOperation = asyncOperation
        self.loadingView = loadingView
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
            self.additionalContent
        }.errorAlert(asyncOperation: self.$asyncOperation)
    }
    
    @ViewBuilder var additionalContent: some View {
        switch self.asyncOperation.status {
        case .empty: Spacer()
        case .loading:
            Color(.black).opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            self.loadingView()
        case .error: Spacer()
        case .data:  Spacer()
        }
    }
}

fileprivate enum AsyncViewError: LocalizedError {}

struct AsyncView_Previews: PreviewProvider {
    
    @State fileprivate static var testAsyncOperation = AsyncOperation<Void, AsyncViewError>(status: .loading(Progress(totalUnitCount: 1)))
    
    static var previews: some View {
        Color(.white)
            .asyncView(asyncOperation: $testAsyncOperation)
    }
}
