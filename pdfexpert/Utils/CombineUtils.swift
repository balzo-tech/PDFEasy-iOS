//
//  CombineUtils.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 20/07/23.
//

import Foundation
import Combine

extension Just {
    static func withErrorType<E>(_ value: Output, _ errorType: E.Type
    ) -> AnyPublisher<Output, E> {
        return Just(value)
            .setFailureType(to: E.self)
            .eraseToAnyPublisher()
    }
}

extension Publisher where Failure: LocalizedError {
    func sinkToAsyncStatus(_ completion: @escaping (AsyncOperationStatus<Output, Failure>) -> Void) -> AnyCancellable {
        return sink(receiveCompletion: { subscriptionCompletion in
            if let error = subscriptionCompletion.error {
                completion(AsyncOperationStatus<Output, Failure>.error(error))
            }
        }, receiveValue: { value in
            completion(AsyncOperationStatus<Output, Failure>.data(value))
        })
    }
}

extension Subscribers.Completion {
    var error: Failure? {
        switch self {
        case let .failure(error): return error
        default: return nil
        }
    }
}
