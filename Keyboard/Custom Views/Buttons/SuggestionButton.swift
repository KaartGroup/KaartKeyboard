//
//  SuggestionButton.swift
//  ELDeveloperKeyboard
//
//  Created by Eric Lin on 2014-07-04.
//  Copyright (c) 2014 Eric Lin. All rights reserved.
//

import Foundation
import UIKit

/**
    The method declared in the SuggestionButtonDelegate protocol allow the adopting delegate to respond to messages from the SuggestionButton class, handling button presses.
*/
protocol SuggestionButtonDelegate: class {
    /**
        Respond to the SuggestionButton being pressed.
    
        - parameter button: The SuggestionButton that was pressed.
    */
    func handlePressForSuggestionButton(button: SuggestionButton)
}

class SuggestionButton: UIButton {
    
    // MARK: Properties
    
    weak var delegate: SuggestionButtonDelegate?
    
    var title: String {
        didSet {
            setTitle(title, forState: .Normal)
        }
    }
    
    // MARK: Constructors
    
    init(frame: CGRect, title: String, delegate: SuggestionButtonDelegate?) {
        self.title = title
        self.delegate = delegate
        
        super.init(frame: frame)
        
        setTitle(title, forState: .Normal)
        titleLabel?.font = UIFont(name: "HelveticaNeue", size: 18.0)
        titleLabel?.textAlignment = .Center
        setTitleColor(UIColor.blackColor(), forState: .Normal)
        setTitleColor(UIColor.darkGrayColor(), forState: .Highlighted)
        titleLabel?.sizeToFit()
        addTarget(self, action: #selector(SuggestionButton.buttonPressed(_:)), forControlEvents: .TouchUpInside)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Event handlers
    
    func buttonPressed(button: SuggestionButton) {
        delegate?.handlePressForSuggestionButton(self)
    }
}