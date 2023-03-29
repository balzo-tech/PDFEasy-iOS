//
//  Async.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 23/02/23.
//

import Foundation

enum AsyncOperationStatus<T, E: LocalizedError> {
    case empty
    case data(T)
    case error(E)
    case loading(Float)
}

struct AsyncOperation<T, E: LocalizedError> {
    let status: AsyncOperationStatus<T, E>
}

extension AsyncOperation where E: LocalizedError {
    
    func updateLoadingProgress(loadingProgress: Float, onlyIfLess: Bool = true) -> Self {
        switch self.status {
        case .loading(let progress):
            if !onlyIfLess || progress < loadingProgress {
                return AsyncOperation(status: .loading(loadingProgress))
            } else {
                return self
            }
        default:
            return self
        }
    }
}
