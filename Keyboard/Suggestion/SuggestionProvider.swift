//
//  SuggestionProvider.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import Foundation

/**
    The SuggestionProvider protocol defines an interface for loading an array of weighted terms and providing autosuggest suggestions from those terms.
*/
protocol SuggestionProvider {
    /**
        Returns an array of autosuggest suggestions that begin with the prefix string provided.
    
        - parameter prefix: The prefix string that suggestions begin with.
    
        - returns: An array of autosuggest suggestions.
    */
    func suggestionsForPrefix(_ prefix: String) -> [String]
    
    /**
        Loads autosuggest terms.
    
        - parameter weightedStrings: An array of WeightedStrings representing autosuggest terms and their relative frequencies.
    */
    func loadWeightedStrings(_ weightedStrings: [WeightedString])
    
    /**
        Clears previously loaded autosuggest terms.
    */
    func clear()
}
