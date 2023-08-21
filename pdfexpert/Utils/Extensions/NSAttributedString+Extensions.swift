//
//  NSAttributedString+Extensions.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/08/23.
//

import Foundation

extension NSAttributedString {
     public func attributedStringByTrimmingCharacterSet(charSet: CharacterSet) -> NSAttributedString {
         let modifiedString = NSMutableAttributedString(attributedString: self)
        modifiedString.trimCharactersInSet(charSet: charSet)
         return NSAttributedString(attributedString: modifiedString)
     }
}

extension NSMutableAttributedString {
     public func trimCharactersInSet(charSet: CharacterSet) {
        var range = (string as NSString).rangeOfCharacter(from: charSet as CharacterSet)

         // Trim leading characters from character set.
         while range.length != 0 && range.location == 0 {
            replaceCharacters(in: range, with: "")
            range = (string as NSString).rangeOfCharacter(from: charSet)
         }

         // Trim trailing characters from character set.
        range = (string as NSString).rangeOfCharacter(from: charSet, options: .backwards)
         while range.length != 0 && NSMaxRange(range) == length {
            replaceCharacters(in: range, with: "")
            range = (string as NSString).rangeOfCharacter(from: charSet, options: .backwards)
         }
     }
}
