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
    
    /**
     Respond to the CharacterButton being long-pressed.
     
     - parameter button: The CharacterButton that was long-pressed.
     */
    func handleLongPressForButton(_ button: CharacterButton)
}

/**
    CharacterButton is a KeyButton subclass associated with three characters (primary, secondary, and tertiary) as well as three gestures (press, swipe up, and swipe down).
*/
class CharacterButton: KeyButton {
    
    // MARK: Constants
    
    /// Left inset for the secondary glyph, which is left-aligned and would otherwise sit hard
    /// against the key's edge.
    static let secondaryInset: CGFloat = 4.0

    /// Size of the letter itself. Two points above KeyButton.titleFontSize, which the word and
    /// preset keys use: a single letter has the room for it where a whole word does not.
    static let primaryFontSize: CGFloat = 22.0
    
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
            refreshCornerGlyph(uppercase: glyphIsUppercased)
        }
    }
    var tertiaryCharacters: [String] {
        didSet {
            if tertiaryLabel != nil {
                tertiaryLabel.text = tertiaryCharacters.count > 0 ? tertiaryCharacters[0] : "-"
            }
            refreshCornerGlyph(uppercase: glyphIsUppercased)
        }
    }

    /// True for the keys that carry a letter in any script -- Latin, Greek, Cyrillic -- and false
    /// for the punctuation keys (comma, period) that share the letter rows. Derived from the
    /// character rather than from a per-language list so it holds for every language file.
    var isLetterKey: Bool {
        return primaryCharacter.rangeOfCharacter(from: .letters) != nil
    }

    /// The glyph in the key's top-left corner, and what a downward swipe types. A letter key
    /// previews its long-press list -- the first accent -- and shows nothing at all when it has
    /// no accents to offer. The punctuation keys keep their own symbol, which is the only place
    /// it appears on the keyboard.
    var cornerGlyph: String {
        return isLetterKey ? (tertiaryCharacters.first ?? "") : secondaryCharacter
    }

    /// Tracked so the glyph can be rebuilt in the current shift case whenever the characters
    /// behind it change, without CharacterButton having to know about the keyboard's shift mode.
    fileprivate var glyphIsUppercased = false
    
    fileprivate(set) var primaryLabel: UILabel!
    fileprivate(set) var secondaryLabel: UILabel!
    fileprivate(set) var tertiaryLabel: UILabel!
    
    // MARK: Constructors
    
    init(frame: CGRect, primaryCharacter: String, secondaryCharacter: String, tertiaryCharacters: [String], delegate: CharacterButtonDelegate?) {
        
        self.primaryCharacter = primaryCharacter
        self.secondaryCharacter = secondaryCharacter
        self.tertiaryCharacters = tertiaryCharacters
        self.delegate = delegate
        
        super.init(frame: frame)
        print(frame.width < 60 ? "TRUE" : "FALSE")
        print(frame.width)
        
//        primaryLabel = UILabel(frame: CGRect(x: frame.width * 0.45, y: 0.0, width: 60 , height: frame.height ))
        primaryLabel = UILabel(frame: CGRect(x: frame.width < 50 ? frame.width * 0.5 : 0.0, y: 0.0, width: frame.width < 50 ? 60 :frame.width, height: frame.height ))
        primaryLabel.font = UIFont(name: "Helvetica", size: CharacterButton.primaryFontSize)
        primaryLabel.textColor = UIColor(white: 0, alpha: 1.0)
        primaryLabel.textAlignment = .center
        primaryLabel.text = primaryCharacter
        addSubview(primaryLabel)
        
        secondaryLabel = UILabel(frame: CGRect(x: CharacterButton.secondaryInset, y: 0.0, width: 60, height: frame.height * 0.5)) // width = 60
        secondaryLabel.font = UIFont(name: "HelveticaNeue", size: 20.0)
        secondaryLabel.adjustsFontSizeToFitWidth = true
        secondaryLabel.textColor = UIColor(white: 187.0/255, alpha: 1.0)
        secondaryLabel.textAlignment = .left
        secondaryLabel.text = cornerGlyph
        addSubview(secondaryLabel)
        
        tertiaryLabel = UILabel(frame: CGRect(x: 0.0, y: frame.height * 0.65, width: frame.width * 0.9, height: frame.height * 0.25))
        tertiaryLabel.font = UIFont(name: "HelveticaNeue", size: 12.0)
        tertiaryLabel.textColor = UIColor(white: 187.0/255, alpha: 1.0)
        tertiaryLabel.adjustsFontSizeToFitWidth = true
        tertiaryLabel.textAlignment = .center
        tertiaryLabel.text = tertiaryCharacters.count > 0 ? tertiaryCharacters[0] : "-"
        //addSubview(tertiaryLabel)
        
        addTarget(self, action: #selector(CharacterButton.buttonPressed(_:)), for: .touchUpInside)
        
        let swipeUpGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(CharacterButton.buttonSwipedUp(_:)))
        swipeUpGestureRecognizer.direction = .up
        addGestureRecognizer(swipeUpGestureRecognizer)
        
        let swipeDownGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(CharacterButton.buttonSwipedDown(_:)))
        swipeDownGestureRecognizer.direction = .down
        addGestureRecognizer(swipeDownGestureRecognizer)
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(CharacterButton.buttonLongPressed(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.3
        addGestureRecognizer(longPressGestureRecognizer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Methods

    /// Cases an accent for display or insertion, leaving it alone when uppercasing would make it
    /// longer. Sharp s uppercases to "SS", which would crowd the corner and type two letters off
    /// one swipe, so glyphs like it stay in the form the language file lists them in.
    static func cased(_ glyph: String, uppercase: Bool) -> String {
        guard uppercase else { return glyph.lowercased() }
        let uppercased = glyph.uppercased()
        return uppercased.count == glyph.count ? uppercased : glyph
    }

    /// Repaints the corner glyph, casing it with the keyboard's shift mode. Only letter keys are
    /// cased -- the punctuation symbols have no case, and gating on that keeps a casing call off
    /// glyphs it could only ever leave alone.
    func refreshCornerGlyph(uppercase: Bool) {
        glyphIsUppercased = uppercase
        guard secondaryLabel != nil else { return }
        let glyph = cornerGlyph
        secondaryLabel.text = isLetterKey ? CharacterButton.cased(glyph, uppercase: uppercase) : glyph
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
    
    @objc func buttonLongPressed(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.handleLongPressForButton(self)
    }
}
