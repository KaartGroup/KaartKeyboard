//
//  StringSubscripts.swift
//  ELDeveloperKeyboard
//
//  Created by Kari Kraam on 2016-04-25.
//  Copyright (c) 2016 Kari Kraam. All rights reserved.
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
