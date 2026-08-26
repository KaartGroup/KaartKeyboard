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

    /// A set of number-row symbols padded or trimmed to `count` keys, so a language file that is
    /// short a few entries leaves those keys blank rather than shifting every symbol left. Takes
    /// the array rather than reading `self` so a nil language can be resolved without standing up
    /// a placeholder Language to ask.
    static func numberRowSymbols(_ symbols: [String]?, paddedTo count: Int) -> [String] {
        let resolved = symbols ?? defaultNumberRowSymbols
        if resolved.count >= count { return Array(resolved.prefix(count)) }
        return resolved + Array(repeating: "", count: count - resolved.count)
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


