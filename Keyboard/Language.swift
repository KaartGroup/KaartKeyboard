//
//  Language.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 10/10/18.
//  Copyright © 2018 Kaart Group. All rights reserved.
//

import Foundation

/**
 A class to construct a language for use creating character buttons
 **/
class Language: Decodable{
    var title: String
    var rows: [Row]

    /// The ten symbols the number row carries, one per key, shown in the key's top-left corner
    /// and typed by a downward swipe. These used to sit on the letter keys, which now preview
    /// their accents instead. Optional so a language file without the key still decodes; a
    /// language that omits it falls back to `Language.defaultNumberRowSymbols`.
    var numberRowSymbols: [String]?

    /// Latin-layout punctuation, used when a language file names no set of its own.
    static let defaultNumberRowSymbols = ["'", "\"", ":", ";", "-", "/", "(", ")", "#", "*"]

    /// The shifted number row: the symbol that belongs to each key 1-9,0, in key order. This is
    /// the Arabic plane, whole and identical in every language, so the row reads the way a
    /// shifted number row does anywhere else rather than carrying whichever punctuation a
    /// language file happened to list first.
    static let shiftedNumberRowSymbols = ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"]

    /// Splits a language's symbols across the two numeral planes the Num key swaps between.
    ///
    /// The Arabic plane is always `shiftedNumberRowSymbols`. A language's own set then supplies
    /// the Roman plane -- but only the part of it that the Arabic plane does not already carry,
    /// so a language naming `#` or `(` does not have to spend a Roman key repeating a symbol
    /// that is one plane away. What is left keeps its listed order and fills from I rightwards,
    /// which for English is `'` `"` `:` `;` `-` `/` on I-VI.
    ///
    /// Nothing a language file defines is dropped, and nothing appears twice.
    static func numberRowSymbolPlanes(_ symbols: [String]?, paddedTo count: Int) -> (arabic: [String], roman: [String]) {
        var arabic = Array(shiftedNumberRowSymbols.prefix(count))
        arabic += Array(repeating: "", count: count - arabic.count)

        let carriedByArabic = Set(arabic)
        let leftovers = (symbols ?? defaultNumberRowSymbols)
            .filter { $0.isEmpty == false && carriedByArabic.contains($0) == false }

        var roman = Array(leftovers.prefix(count))
        roman += Array(repeating: "", count: count - roman.count)

        return (arabic, roman)
    }

    struct Row: Decodable {
        var row: [Character]
    }
    
    struct Character: Decodable {
        var primary: String
        var secondary: String
        var tertiary: [String]
    }
}


