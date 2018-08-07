//
//  CharacterButton.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import Foundation
import UIKit

/**
    The methods declared in the CharacterButtonDelegate protocol allow the adopting delegate to respond to messages from the CharacterButton class, handling button presses and swipes.
*/
protocol CharacterButtonDelegate: class {
    /**
        Respond to the CharacterButton being pressed.
        
        - parameter button: The CharacterButton that was pressed.
    */
    func handlePressForCharacterButton(_ button: CharacterButton)
    
    /**
        Respond to the CharacterButton being up-swiped.
     
        - parameter button: The CharacterButton that was up-swiped.
    */
    func handleSwipeUpForButton(_ button: CharacterButton)
    
    /**
        Respond to the CharacterButton being down-swiped.
     
        - parameter button: The CharacterButton that was down-swiped.
    */
    func handleSwipeDownForButton(_ button: CharacterButton)
}

/**
    CharacterButton is a KeyButton subclass associated with three characters (primary, secondary, and tertiary) as well as three gestures (press, swipe up, and swipe down).
*/
class CharacterButton: KeyButton {
    
    // MARK: Properties
    
    weak var delegate: CharacterButtonDelegate?
    
    var primaryCharacter: String {
        didSet {
            if primaryLabel != nil {
                primaryLabel.text = primaryCharacter
            }
        }
    }
    var secondaryCharacter: String {
        didSet {
            if secondaryLabel != nil {
                secondaryLabel.text = secondaryCharacter
            }
        }
    }
    var tertiaryCharacter: String {
        didSet {
            if tertiaryLabel != nil {
                tertiaryLabel.text = tertiaryCharacter
            }
        }
    }
    
    fileprivate(set) var primaryLabel: UILabel!
    fileprivate(set) var secondaryLabel: UILabel!
    fileprivate(set) var tertiaryLabel: UILabel!
    
    // MARK: Constructors
    
    init(frame: CGRect, primaryCharacter: String, secondaryCharacter: String, tertiaryCharacter: String, delegate: CharacterButtonDelegate?) {
        
        self.primaryCharacter = primaryCharacter
        self.secondaryCharacter = secondaryCharacter
        self.tertiaryCharacter = tertiaryCharacter
        self.delegate = delegate
        
        super.init(frame: frame)
        
        primaryLabel = UILabel(frame: CGRect(x: frame.width * 0.45, y: 0.0, width: 60 , height: frame.height ))
        primaryLabel.font = UIFont(name: "HelveticaNeue", size: 20.0)
        primaryLabel.textColor = UIColor(white: 0, alpha: 1.0)
        primaryLabel.textAlignment = .center
        primaryLabel.text = primaryCharacter
        addSubview(primaryLabel)
        
        secondaryLabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: frame.width * 0.9, height: frame.height * 0.3))
        secondaryLabel.font = UIFont(name: "HelveticaNeue", size: 12.0)
        secondaryLabel.adjustsFontSizeToFitWidth = true
        secondaryLabel.textColor = UIColor(white: 187.0/255, alpha: 1.0)
        secondaryLabel.textAlignment = .right
        secondaryLabel.text = secondaryCharacter
        //addSubview(secondaryLabel)
        
        tertiaryLabel = UILabel(frame: CGRect(x: 0.0, y: frame.height * 0.65, width: frame.width * 0.9, height: frame.height * 0.25))
        tertiaryLabel.font = UIFont(name: "HelveticaNeue", size: 12.0)
        tertiaryLabel.textColor = UIColor(white: 187.0/255, alpha: 1.0)
        tertiaryLabel.adjustsFontSizeToFitWidth = true
        tertiaryLabel.textAlignment = .right
        tertiaryLabel.text = tertiaryCharacter
        //addSubview(tertiaryLabel)
        
        addTarget(self, action: #selector(CharacterButton.buttonPressed(_:)), for: .touchUpInside)
        
        let swipeUpGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(CharacterButton.buttonSwipedUp(_:)))
        swipeUpGestureRecognizer.direction = .up
        addGestureRecognizer(swipeUpGestureRecognizer)
        
        let swipeDownGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(CharacterButton.buttonSwipedDown(_:)))
        swipeDownGestureRecognizer.direction = .down
        addGestureRecognizer(swipeDownGestureRecognizer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Event handlers
    
    @objc func buttonPressed(_ sender: KeyButton) {
        delegate?.handlePressForCharacterButton(self)
    }
    
    @objc func buttonSwipedUp(_ swipeUpGestureRecognizer: UISwipeGestureRecognizer) {
        delegate?.handleSwipeUpForButton(self)
    }
    
    @objc func buttonSwipedDown(_ swipeDownGestureRecognizer: UISwipeGestureRecognizer) {
        delegate?.handleSwipeDownForButton(self)
    }
}
