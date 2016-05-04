//
//  WeightedString.swift
//  ELDeveloperKeyboard
//
//  Created by Kari Kraam on 2016-04-25.
//  Copyright (c) 2016 Kari Kraam. All rights reserved.
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