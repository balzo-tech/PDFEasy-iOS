//
//  PdfPageRangeEditorViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/08/23.
//

import Foundation
import Factory
import SwiftUI

extension Container {
    var pdfPageRangeEditorViewModel: ParameterFactory<PdfPageRangeEditorViewModel.Params, PdfPageRangeEditorViewModel> {
        self { PdfPageRangeEditorViewModel(params: $0) }
    }
}

typealias PdfPageRangeEditorConfirmCallback = () -> ()
typealias PdfPageRangeEditorCancelCallback = () -> ()

class PdfPageRangeEditorViewModel: ObservableObject {
    
    struct Params {
        let pageRanges: Binding<[ClosedRange<Int>]>
        let totalPages: Int
        let confirmCallback: PdfPageRangeEditorConfirmCallback
        let cancelCallback: PdfPageRangeEditorCancelCallback
    }
    
    private var pageRanges: Binding<[ClosedRange<Int>]>
    
    @Published var pageRangeLowerBounds: [String]
    @Published var pageRangeUpperBounds: [String]
    
    private let totalPages: Int
    private let confirmCallback: PdfPageRangeEditorConfirmCallback
    private let cancelCallback: PdfPageRangeEditorCancelCallback
    
    init(params: Params) {
        self.pageRanges = params.pageRanges
        self.totalPages = params.totalPages
        self.confirmCallback = params.confirmCallback
        self.cancelCallback = params.cancelCallback
        
        self.pageRangeLowerBounds = params.pageRanges.wrappedValue.map { "\($0.lowerBound + 1)" }
        self.pageRangeUpperBounds = params.pageRanges.wrappedValue.map { "\($0.upperBound + 1)" }
    }
    
    func confirm() {
        guard let pageRanges = self.getPageRangesFromRangeStrings() else {
            self.cancelCallback()
            return
        }
        self.pageRanges.wrappedValue = pageRanges
        self.confirmCallback()
    }
    
    func cancel() {
        self.cancelCallback()
    }
    
    func addRange() {
        self.pageRangeLowerBounds.append("1")
        self.pageRangeUpperBounds.append("\(self.totalPages + 1)")
    }
    
    func removeRange(atIndex index: Int) {
        self.pageRangeLowerBounds.remove(at: index)
        self.pageRangeUpperBounds.remove(at: index)
    }
    
    private func getPageRangesFromRangeStrings() -> [ClosedRange<Int>]? {
        guard self.pageRangeLowerBounds.count == self.pageRangeUpperBounds.count else {
            assertionFailure("lower bounds count and upper bounds count don't match")
            return nil
        }
        
        var result: [ClosedRange<Int>] = []
        
        for index in 0..<self.pageRangeLowerBounds.count {
            let userFriendlyLowerBound = Int(self.pageRangeLowerBounds[index])
            let userFriendlyUpperBound = Int(self.pageRangeUpperBounds[index])
            if let userFriendlyLowerBound, let userFriendlyUpperBound {
                let lowerBound = userFriendlyLowerBound - 1
                let upperBound = userFriendlyUpperBound - 1
                if lowerBound >= 0, upperBound < self.totalPages, lowerBound <= upperBound {
                    result.append(lowerBound...upperBound)
                } else {
                    assertionFailure("Lower or upper bound contained invalid values")
                }
            } else {
                assertionFailure("Lower or upper bound strings couldn't be parsed")
            }
        }
        
        return result
    }
}
