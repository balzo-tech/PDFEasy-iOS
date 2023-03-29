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
    case loading(Progress)
}

struct AsyncOperation<T, E: LocalizedError> {
    let status: AsyncOperationStatus<T, E>
}

extension AsyncOperation where E: LocalizedError {
    
    func updateLoadingProgress(loadingProgress: Progress, onlyIfLess: Bool = true) -> Self {
        switch self.status {
        case .loading(let progress):
            if !onlyIfLess || progress.completedUnitCount < loadingProgress.completedUnitCount {
                return AsyncOperation(status: .loading(loadingProgress))
            } else {
                return self
            }
        default:
            return self
        }
    }
}
