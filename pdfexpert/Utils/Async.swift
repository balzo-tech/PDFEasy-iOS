//
//  Async.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 23/02/23.
//

import Foundation
import SwiftUI

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
    
    var success: Bool {
        switch self.status {
        case .empty: return false
        case .data: return true
        case .error: return false
        case .loading: return false
        }
    }
    
    var isLoading: Bool {
        switch self.status {
        case .empty: return false
        case .data: return false
        case .error: return false
        case .loading: return true
        }
    }
    
    var data: T? {
        switch self.status {
        case .empty: return nil
        case .data(let data): return data
        case .error: return nil
        case .loading: return nil
        }
    }
    
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
