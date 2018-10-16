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
    
    struct Row: Decodable {
        var row: [Character]
    }
    
    struct Character: Decodable {
        var primary: String
        var secondary: String
        var tertiary: [String]
    }
}


