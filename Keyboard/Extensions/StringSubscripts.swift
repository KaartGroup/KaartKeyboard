//
//  StringSubscripts.swift
//  ELDeveloperKeyboard
//
//  Created by Eric Lin on 2014-07-02.
//  Copyright (c) 2014 Eric Lin. All rights reserved.
//

import Foundation

/**
    A String extension that allows accessing substrings using subscript syntax.
*/
extension String {
    subscript(i: Int) -> String {
        return String(Array(self.characters)[i])
    }
    subscript(range: Range<Int>) -> String {
        let start = startIndex.advancedBy(range.startIndex)
        let end = startIndex.advancedBy(range.endIndex)
        return substringWithRange(Range(start: start, end: end))
    }
}
