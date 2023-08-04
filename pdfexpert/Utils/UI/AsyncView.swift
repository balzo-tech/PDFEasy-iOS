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
                .allowsHitTesting(!self.asyncOperation.isLoading)
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





extension View {
    
    func asyncView<AsyncItem: AsyncFailable & AsyncLoadable>(
        asyncItem: Binding<AsyncItem>) -> some View {
            return self
                .asyncFailableView(asyncItem: asyncItem)
                .asyncLoadableView(asyncItem: asyncItem, loadingView: { ProgressView() })
    }
    
    func asyncView<LoadingView: View, AsyncItem: AsyncFailable & AsyncLoadable>(
        asyncItem: Binding<AsyncItem>,
        @ViewBuilder loadingView: @escaping () -> LoadingView) -> some View {
            return self
                .asyncFailableView(asyncItem: asyncItem)
                .asyncLoadableView(asyncItem: asyncItem, loadingView: loadingView)
    }
    
    func asyncView<AsyncItem: AsyncFailable>(
        asyncItem: Binding<AsyncItem>) -> some View {
            return self
                .asyncFailableView(asyncItem: asyncItem)
    }
    
    func asyncView<AsyncItem: AsyncLoadable>(
        asyncItem: Binding<AsyncItem>) -> some View {
            return self
                .asyncLoadableView(asyncItem: asyncItem, loadingView: { ProgressView() })
    }
    
    func asyncView<LoadingView: View, AsyncItem: AsyncLoadable>(
        asyncItem: Binding<AsyncItem>,
        @ViewBuilder loadingView: @escaping () -> LoadingView) -> some View {
            return self
                .asyncLoadableView(asyncItem: asyncItem, loadingView: loadingView)
    }
    
    func asyncFailableView<AsyncItem: AsyncFailable>(
        asyncItem: Binding<AsyncItem>) -> some View {
        return self.modifier(
            AsyncFailableView(asyncItem: asyncItem)
        )
    }
    
    func asyncLoadableView<LoadingView: View, AsyncItem: AsyncLoadable>(
        asyncItem: Binding<AsyncItem>,
        @ViewBuilder loadingView: @escaping () -> LoadingView) -> some View {
        return self.modifier(
            AsyncLoadableView(asyncItem: asyncItem, loadingView: loadingView)
        )
    }
}

struct AsyncFailableView<AsyncItem: AsyncFailable>: ViewModifier {
    
    @Binding var asyncItem: AsyncItem
    
    init(asyncItem: Binding<AsyncItem>) {
        self._asyncItem = asyncItem
    }
    
    func body(content: Content) -> some View {
        content.errorAlert(asyncFailable: self.$asyncItem)
    }
}

struct AsyncLoadableView<LoadingView: View, AsyncItem: AsyncLoadable>: ViewModifier {
    
    @Binding var asyncItem: AsyncItem
    
    var loadingView: (() -> LoadingView)
    
    init(asyncItem: Binding<AsyncItem>, loadingView: @escaping (() -> LoadingView)) {
        self._asyncItem = asyncItem
        self.loadingView = loadingView
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content.allowsHitTesting(!self.asyncItem.isLoading)
            if self.asyncItem.isLoading {
                Color(.black).opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                self.loadingView()
            }
        }
    }
}
