//
//  Enum+Extensions.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 09/03/23.
//

import Foundation

extension CaseIterable where Self: Equatable {
    
    static var totalCases: Int {
        return Self.allCases.count
    }
    
    var index: Int {
        return Array(Self.allCases).firstIndex(of: self)!
    }
    
    var next: Self? {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        let next = all.index(after: idx)
        return next != all.endIndex ? all[next] : nil
    }
    
    var previous: Self? {
        let all = Array(Self.allCases)
        let idx = all.firstIndex(of: self)!
        let previous = all.index(before: idx)
        return previous >= 0 ? all[previous] : nil
    }
}
