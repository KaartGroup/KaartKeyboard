//
//  KeyButton.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import Foundation
import UIKit
import QuartzCore

/**
    KeyButton is a UIButton subclass with keyboard button styling.
*/
class KeyButton: UIButton {
    
    // MARK: Properties
    
    /// The gutter the keyboard lays out between keys. Single source of truth for
    /// KeyboardViewController.spacing and for the touch outset below.
    static let gutter: CGFloat = 5.0
    
    /// Title size for the letter and word keys.
    static let titleFontSize: CGFloat = 20.0

    /// Title sizes for the keys labelled with a symbol rather than text. Symbols like U+232B
    /// and U+21E7 are drawn well inside their em box, so at titleFontSize they read visibly
    /// smaller than the capitals beside them and need their own, larger sizes.
    ///
    /// One literal per key, and no size derived from another: these four have been tuned
    /// separately and in different directions more than once, so a shared base with overrides
    /// only obscured which number actually applied where.
    ///
    /// All are bounded by the key height, because KeyButton sets masksToBounds and clips a
    /// glyph too large for its key rather than letting it overflow. Backspace at 42pt is the
    /// largest and yields a 49pt label against a 58.5pt key in portrait and a 54pt key in
    /// landscape, so it is near the ceiling; going above it wants a landscape check.
    static let backspaceTitleFontSize: CGFloat = 42.0
    static let returnTitleFontSize: CGFloat = 38.0
    static let globeTitleFontSize: CGFloat = 38.0
    static let shiftTitleFontSize: CGFloat = 32.0

    /// Extends the tap region beyond the painted key so no touch is wasted in the gutters.
    /// Half a gutter means neighbouring keys meet at the midline without overlapping.
    /// Set to 0 for keys laid out edge to edge, such as the accent popup, where there is no
    /// gutter to reclaim and an outset would only make neighbours fight over the same strip.
    var touchOutset: CGFloat = KeyButton.gutter / 2
    
    // MARK: Overridden methods
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if touchOutset <= 0 {
            return super.point(inside: point, with: event)
        }
        return bounds.insetBy(dx: -touchOutset, dy: -touchOutset).contains(point)
    }
    
    // MARK: Constructors
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel?.font = UIFont(name: "HelveticaNeue", size: KeyButton.titleFontSize)
        titleLabel?.textAlignment = .center
        setTitleColor(UIColor.black, for: .normal)
        titleLabel?.sizeToFit()
        
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        let gradientColors: [AnyObject] = [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor, UIColor(red: 254.0/255, green: 254.0/255, blue: 254.0/255, alpha: 1.0).cgColor]
        gradient.colors = gradientColors // Declaration broken into two lines to prevent 'unable to bridge to Objective C' error.
        //setBackgroundImage(gradient.UIImageFromCALayer(), forState: .Normal)
        
        setBackgroundImage(UIImage.fromColor(UIColor.white), for: .normal)
        let selectedGradient = CAGradientLayer()
        selectedGradient.frame = bounds
        let selectedGradientColors: [AnyObject] = [UIColor(red: 1.0, green: 1.0/255, blue: 1.0/255, alpha: 1.0).cgColor, UIColor(red: 200.0/255, green: 210.0/255, blue: 214.0/255, alpha: 1.0).cgColor]
        selectedGradient.colors = selectedGradientColors // Declaration broken into two lines to prevent 'unable to bridge to Objective C' error.
        setBackgroundImage(selectedGradient.UIImageFromCALayer(), for: .selected)
        
        layer.masksToBounds = true
        layer.cornerRadius = 3.0
        
        contentVerticalAlignment = .center
        contentHorizontalAlignment = .center
        contentEdgeInsets = UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Methods
    
    /// Switches this key to a larger symbol title size. For keys labelled with a glyph
    /// rather than text, so the font name stays in one place.
    func useGlyphTitleFont(size: CGFloat) {
        titleLabel?.font = UIFont(name: "HelveticaNeue", size: size)
    }
}

/**
    A key carrying a muted symbol in its top-left corner, typed by a downward swipe -- the same
    affordance the letter keys use for their accents. The number row uses it to host the
    punctuation that used to sit on the letter keys.
*/
class SymbolKeyButton: KeyButton {

    /// Matches CharacterButton.secondaryInset so the corner glyph sits at the same offset on
    /// both rows.
    static let symbolInset: CGFloat = 4.0

    /// Smaller than the letter keys' corner glyph: a number key is narrower than a letter key and
    /// its numeral is centred across the same width, so a full-size glyph crowds it.
    static let symbolFontSize: CGFloat = 16.0

    fileprivate(set) var symbolLabel: UILabel!

    /// The symbol this key carries. Empty leaves the corner blank and makes the downward swipe
    /// a no-op, so a language with fewer than ten symbols simply has quieter keys.
    var symbol: String = "" {
        didSet {
            symbolLabel?.text = symbol
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        symbolLabel = UILabel(frame: .zero)
        symbolLabel.font = UIFont(name: "HelveticaNeue", size: SymbolKeyButton.symbolFontSize)
        symbolLabel.adjustsFontSizeToFitWidth = true
        symbolLabel.textAlignment = .left
        // Muted against this key's black numeral, as the letter keys' glyph is muted against
        // their black letter. Black at low alpha rather than a fixed grey, so it stays muted by
        // the same proportion if the key's fill is ever lightened or darkened again.
        symbolLabel.textColor = UIColor(white: 0.0, alpha: 0.38)
        addSubview(symbolLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // The number keys are built at a placeholder width and then sized by constraints, so the
    // glyph is positioned from the laid-out bounds rather than the initial frame.
    override func layoutSubviews() {
        super.layoutSubviews()
        symbolLabel.frame = CGRect(x: SymbolKeyButton.symbolInset,
                                   y: 0.0,
                                   width: bounds.width - SymbolKeyButton.symbolInset,
                                   height: bounds.height * 0.5)
    }
}
