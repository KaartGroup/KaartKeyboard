//
//  StringSubscripts.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import Foundation

/**
    A String extension that allows accessing substrings using subscript syntax.
*/
extension String {
    /// The Character at `i`, as a String.
    ///
    /// Indexes through the string rather than building an Array of every Character first, which is
    /// what this did before. Same result -- String is Character-indexed either way -- without
    /// allocating a copy of the whole string on each subscript.
    subscript(i: Int) -> String {
        return String(self[index(startIndex, offsetBy: i)])
    }

    subscript(range: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(startIndex, offsetBy: range.upperBound)
        return String(self[start ..< end])
    }
}
