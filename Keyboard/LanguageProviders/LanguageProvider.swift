//
//  LanguageProvider.swift
//  ELDeveloperKeyboard
//
//  Created by Kari Kraam on 2016-04-25.
//  Copyright (c) 2016 Kari Kraam. All rights reserved.
//

import Foundation

/**
    The LanguageProvider protocol defines the properties associated with a programming language, including the positioning of symbols on the keyboard and that language's keywords.
*/
protocol LanguageProvider {
    /** The name of the language. */
    var language: String { get }
    
    /** An array of String arrays, defining the keyboard's secondary characters. */
    var secondaryCharacters: [[String]] { get }
    
    /** An array of String arrays, defining the keyboard's tertiary characters. */
    var tertiaryCharacters: [[String]] { get }
    
    /** An array of words that usually precede a capitalized word. */
    var autocapitalizeAfter: [String] { get }
    
    /** An array of WeightedStrings representing the language's keywords and their relative frequencies. */
    var suggestionDictionary: [WeightedString] { get }
}