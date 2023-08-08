//
//  PdfPageRangeEditorViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/08/23.
//

import Foundation
import Factory
import SwiftUI
import Combine

extension Container {
    var pdfPageRangeEditorViewModel: ParameterFactory<PdfPageRangeEditorViewModel.Params, PdfPageRangeEditorViewModel> {
        self { PdfPageRangeEditorViewModel(params: $0) }
    }
}

typealias PdfPageRangeEditorConfirmCallback = () -> ()
typealias PdfPageRangeEditorCancelCallback = () -> ()

enum PdfPageRangeFocusable: Hashable {
    case lowerBound(index: Int)
    case upperBound(index: Int)
}

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
    
    @Published var pdfPageRangeInFocus: PdfPageRangeFocusable? = nil
    
    private let totalPages: Int
    private let confirmCallback: PdfPageRangeEditorConfirmCallback
    private let cancelCallback: PdfPageRangeEditorCancelCallback
    
    private var cancelBag = Set<AnyCancellable>()
    
    init(params: Params) {
        self.pageRanges = params.pageRanges
        self.totalPages = params.totalPages
        self.confirmCallback = params.confirmCallback
        self.cancelCallback = params.cancelCallback
        
        self.pageRangeLowerBounds = params.pageRanges.wrappedValue.map { "\($0.lowerBound + 1)" }
        self.pageRangeUpperBounds = params.pageRanges.wrappedValue.map { "\($0.upperBound + 1)" }
        
        self.$pdfPageRangeInFocus
            .withPrevious(nil)
            .sink { [weak self] previousField, _ in
                guard let self else { return }
                // Validate the focus field that is losing focus.
                if let previousField {
                    self.validateField(field: previousField)
                }
            }.store(in: &self.cancelBag)
    }
    
    func focus(index: Int, isLowerBound: Bool) {
        self.pdfPageRangeInFocus = isLowerBound ? .lowerBound(index: index) : .upperBound(index: index)
    }
    
    func confirm() {
        self.pdfPageRangeInFocus = nil
        guard let pageRanges = self.getPageRangesFromRangeStrings() else {
            self.cancelCallback()
            return
        }
        self.pageRanges.wrappedValue = pageRanges
        self.confirmCallback()
    }
    
    func cancel() {
        self.pdfPageRangeInFocus = nil
        self.cancelCallback()
    }
    
    func onConfirmRange() {
        self.pdfPageRangeInFocus = nil
    }
    
    func addRange() {
        self.pdfPageRangeInFocus = nil
        self.pageRangeLowerBounds.append("1")
        self.pageRangeUpperBounds.append("\(self.totalPages)")
    }
    
    func removeRange(atIndex index: Int) {
        self.pdfPageRangeInFocus = nil
        self.pageRangeLowerBounds.remove(at: index)
        self.pageRangeUpperBounds.remove(at: index)
    }
    
    func validateLowerBound(forIndex index: Int) {
        guard self.pageRangeLowerBounds.count == self.pageRangeUpperBounds.count else {
            assertionFailure("lower bounds count and upper bounds count don't match")
            return
        }
        
        guard index >= 0, index < self.pageRangeLowerBounds.count else {
            assertionFailure("Given index is out of range!")
            return
        }
        
        let userFriendlyUpperBound = Int(self.pageRangeUpperBounds[index])
        
        guard let userFriendlyUpperBound else {
            assertionFailure("Upper bound strings couldn't be parsed")
            return
        }
        
        let userFriendlyLowerBound = Int(self.pageRangeLowerBounds[index])
        
        if let userFriendlyLowerBound {
            if userFriendlyLowerBound < 1 {
                self.pageRangeLowerBounds[index] = 1.toString
            } else if userFriendlyLowerBound > userFriendlyUpperBound {
                self.pageRangeLowerBounds[index] = userFriendlyUpperBound.toString
            } else {
                // This is a normalizing step. E.g.: Input: 03 -> Output 3
                self.pageRangeLowerBounds[index] = userFriendlyLowerBound.toString
            }
        } else {
            self.pageRangeLowerBounds[index] = 1.toString
        }
    }
    
    func getTextFieldText(index: Int, isLowerBound: Bool) -> Binding<String> {
        // Inline binding avoid out of index exception when deleting an in-focus range
        Binding(get: {
            guard index < self.pageRangeLowerBounds.count else {
                return ""
            }
            return isLowerBound
            ? self.pageRangeLowerBounds[index]
            : self.pageRangeUpperBounds[index]
        }, set: { newValue in
            guard index < self.pageRangeLowerBounds.count else {
                return
            }
            if isLowerBound {
                self.pageRangeLowerBounds[index] = newValue
            } else {
                self.pageRangeUpperBounds[index] = newValue
            }
        })
    }
    
    private func validateField(field: PdfPageRangeFocusable) {
        switch field {
        case .lowerBound(let index):
            self.validateLowerBound(forIndex: index)
        case .upperBound(let index):
            self.validateUpperBound(forIndex: index)
        }
    }
    
    func validateUpperBound(forIndex index: Int) {
        guard self.pageRangeLowerBounds.count == self.pageRangeUpperBounds.count else {
            assertionFailure("lower bounds count and upper bounds count don't match")
            return
        }
        
        guard index >= 0, index < self.pageRangeUpperBounds.count else {
            assertionFailure("Given index is out of range!")
            return
        }
        
        let userFriendlyLowerBound = Int(self.pageRangeLowerBounds[index])
        
        guard let userFriendlyLowerBound else {
            assertionFailure("Lower bound strings couldn't be parsed")
            return
        }
        
        let userFriendlyUpperBound = Int(self.pageRangeUpperBounds[index])
        
        if let userFriendlyUpperBound {
            if userFriendlyUpperBound > self.totalPages {
                self.pageRangeUpperBounds[index] = self.totalPages.toString
            } else if userFriendlyLowerBound > userFriendlyUpperBound {
                self.pageRangeUpperBounds[index] = userFriendlyLowerBound.toString
            } else {
                // This is a normalizing step. E.g.: Input: 03 -> Output 3
                self.pageRangeUpperBounds[index] = userFriendlyUpperBound.toString
            }
        } else {
            self.pageRangeUpperBounds[index] = self.totalPages.toString
        }
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
        
//        print("PdfPageRangeEditorViewModel - Lower Bounds: \(self.pageRangeLowerBounds)")
//        print("PdfPageRangeEditorViewModel - Upper Bounds: \(self.pageRangeUpperBounds)")
//        print("PdfPageRangeEditorViewModel - Result: \(result)")
        
        return result
    }
}
