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
protocol CharacterButtonDelegate: AnyObject {
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

    /// Muted brown for the corner accent/swipe glyph, matched against the reference mockup.
    static let cornerGlyphColor = UIColor(red: 140.0/255, green: 115.0/255, blue: 85.0/255, alpha: 1.0)
    
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

        // Both labels are placed by layoutSubviews below, so they are created at zero and the
        // geometry lives in one place. They used to be sized here, from the frame the key is
        // constructed with -- and addCharacterButtons() runs in viewDidLoad, where the input
        // view is still (0, 0, 0, 0), so that frame is zero wide. See the comment on
        // layoutSubviews for what that did to the letter.
        primaryLabel = UILabel(frame: .zero)
        primaryLabel.font = UIFont(name: "Helvetica", size: CharacterButton.primaryFontSize)
        primaryLabel.textColor = KeyButton.defaultTitleColor
        primaryLabel.textAlignment = .center
        primaryLabel.text = primaryCharacter
        addSubview(primaryLabel)
        
        secondaryLabel = UILabel(frame: .zero)
        secondaryLabel.font = UIFont(name: "HelveticaNeue", size: 11.5)
        secondaryLabel.adjustsFontSizeToFitWidth = true
        secondaryLabel.textColor = CharacterButton.cornerGlyphColor
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
    
    // MARK: Overridden methods

    /// Places the letter and its corner glyph against the size the key was actually given.
    ///
    /// The keys are built at one size and then positioned and resized by constraints, exactly as
    /// the number keys are -- so the frames handed to the labels in init describe a key that no
    /// longer exists by the time anything is drawn. SymbolKeyButton already lays its glyph out
    /// here for that reason; CharacterButton did not, and kept the frames it was born with.
    ///
    /// Since addCharacterButtons() runs in viewDidLoad, where the input view has not been sized,
    /// those frames were zero wide: the letter got a fixed 60pt-wide label at x = 0 and so sat
    /// centred on 30pt rather than on the middle of the key. Measured on an iPad Pro 11", every
    /// letter was 4.8-5.8pt left of centre on the top row and 8.2-9.8pt left on the other two --
    /// the error is keyWidth / 2 - 30, so it grows with the key. The number, preset and space
    /// keys, which centre their titles through UIButton, were all dead on centre, which is what
    /// made the character rows look subtly wrong next to them.
    ///
    /// It also went the other way on a narrow key: 60pt of label does not fit an iPhone's ~31pt
    /// letter key, and the overflow was clipped by KeyButton's masksToBounds.
    override func layoutSubviews() {
        super.layoutSubviews()

        // The full key, so the letter centres on it the way every other key's title does.
        primaryLabel.frame = bounds

        // Top-left corner, inset off the edge, over the upper half of the key.
        secondaryLabel.frame = CGRect(x: CharacterButton.secondaryInset,
                                      y: 0.0,
                                      width: max(0, bounds.width - CharacterButton.secondaryInset),
                                      height: bounds.height * 0.5)
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
    
    // Only on .began. A long press also reports .changed for every touch move that follows
    // recognition, and .ended on release, and the delegate builds a fresh accent popup each time
    // it is called -- so holding a key and sliding a finger stacked a new set of buttons per
    // move. One press, one call.
    @objc func buttonLongPressed(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        guard longPressGestureRecognizer.state == .began else { return }
        delegate?.handleLongPressForButton(self)
    }
}
