//
//  Async.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 23/02/23.
//

import Foundation
import SwiftUI

protocol AsyncLoadable {
    var isLoading: Bool { get }
    func updateLoadingProgress(loadingProgress: Progress, onlyIfLess: Bool) -> Self
}

protocol AsyncFailable {
    
    associatedtype E: LocalizedError
    
    var error: E? { get }
    static var resetState: Self { get }
}

enum AsyncOperationStatus<T, E: LocalizedError> {
    case empty
    case data(T)
    case error(E)
    case loading(Progress)
}

struct AsyncOperation<T, E: LocalizedError> {
    let status: AsyncOperationStatus<T, E>
}

extension AsyncOperation: AsyncLoadable, AsyncFailable where E: LocalizedError {
    
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
    
    var error: E? {
        switch self.status {
        case .empty: return nil
        case .data: return nil
        case .error(let error): return error
        case .loading: return nil
        }
    }
    
    func updateLoadingProgress(loadingProgress: Progress, onlyIfLess: Bool = true) -> Self {
        switch self.status {
        case .loading(let progress):
            return AsyncOperation(status: .loading(progress.update(newProgress: loadingProgress, onlyIfLess: onlyIfLess)))
        default:
            return self
        }
    }
    
    static var resetState: Self { .init(status: .empty) }
}

enum AsyncEmptyFailable<E: LocalizedError>: AsyncLoadable, AsyncFailable {
    case idle
    case loading(Progress)
    case error(E)
    
    var isLoading: Bool {
        switch self {
        case .idle: return false
        case .error: return false
        case .loading: return true
        }
    }
    
    var error: E? {
        switch self {
        case .idle: return nil
        case .error(let error): return error
        case .loading: return nil
        }
    }
    
    func updateLoadingProgress(loadingProgress: Progress, onlyIfLess: Bool = true) -> Self {
        switch self {
        case .loading(let progress):
            return .loading(progress.update(newProgress: loadingProgress, onlyIfLess: onlyIfLess))
        default:
            return self
        }
    }
    
    static var resetState: Self { .idle }
}

enum AsyncEmpty: AsyncLoadable {
    case idle
    case loading(Progress)
    
    var isLoading: Bool {
        switch self {
        case .idle: return false
        case .loading: return true
        }
    }
    
    func updateLoadingProgress(loadingProgress: Progress, onlyIfLess: Bool = true) -> Self {
        switch self {
        case .loading(let progress):
            return .loading(progress.update(newProgress: loadingProgress, onlyIfLess: onlyIfLess))
        default:
            return self
        }
    }
}

extension Progress {
    static var undeterminedProgress: Self {
        .init(totalUnitCount: 1)
    }
    
    func update(newProgress: Progress, onlyIfLess: Bool = true) -> Progress {
        if !onlyIfLess || self.completedUnitCount < newProgress.completedUnitCount {
            return newProgress
        } else {
            return self
        }
    }
}
