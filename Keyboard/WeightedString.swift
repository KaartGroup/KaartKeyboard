//
//  WeightedString.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import Foundation

/**
    WeightedString is a structure representing a term and its relative frequency, for use in autosuggestion.
*/
struct WeightedString {
    /**
        The suggestable term.
    */
    let term: String

    /**
        The weight associated with the term.
    */
    let weight: Int
}
