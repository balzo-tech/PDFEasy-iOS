//
//  DebugUtils.swift
//  FourBooks
//
//  Created by Leonardo Passeri on 15/06/2020.
//  Copyright © 2020 4Books. All rights reserved.
//

import Foundation

@discardableResult
public func debugPrintElapsedTimeSince(operationName: String, startTime: CFAbsoluteTime) -> CFAbsoluteTime {
    let currentTime = CFAbsoluteTimeGetCurrent()
    print("Debug - Time elapsed for \(operationName): \(currentTime - startTime) s.")
    return currentTime
}

public func debugPrint(for type: Any.Type, message: String, function: String = #function) {
    print("\(String(describing: type)) - \(function) - \(message)")
}

public func debugPrint(for instance: Any, message: String, function: String = #function) {
    debugPrint(for: type(of: instance), message: message)
}

public func isPreview() -> Bool {
    return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}
