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

    /// Where a symbol sits on a shifted number row, as a zero-based index into keys 1-9,0. Only
    /// the ten symbols that have a conventional number home appear; everything else -- quotes,
    /// colons, the hyphen, the slash -- has no number it belongs to and is placed by
    /// `numberRowSymbolPlanes` on the Roman plane instead.
    static let symbolHomeOnNumberKey: [String: Int] = [
        "!": 0, "@": 1, "#": 2, "$": 3, "%": 4, "^": 5, "&": 6, "*": 7, "(": 8, ")": 9
    ]

    /// Splits a language's symbols across the two numeral planes the Num key swaps between.
    ///
    /// A symbol that belongs to a number goes on that number's key -- `#` on 3, `(` on 9 -- so
    /// the Arabic plane reads the way a shifted number row does anywhere else, with gaps where
    /// the language names no symbol for that digit. Everything left over keeps its listed order
    /// and fills the Roman plane from I rightwards, so no symbol the language defines is lost;
    /// it just costs one tap of Num to reach.
    ///
    /// Two symbols claiming the same digit is not something any current language file does, but
    /// if it happened the first listed keeps the key and the second falls through to the Roman
    /// plane rather than overwriting it.
    static func numberRowSymbolPlanes(_ symbols: [String]?, paddedTo count: Int) -> (arabic: [String], roman: [String]) {
        let resolved = symbols ?? defaultNumberRowSymbols

        var arabic = Array(repeating: "", count: count)
        var leftovers: [String] = []

        for symbol in resolved where symbol.isEmpty == false {
            if let home = symbolHomeOnNumberKey[symbol], home < count, arabic[home].isEmpty {
                arabic[home] = symbol
            } else {
                leftovers.append(symbol)
            }
        }

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


