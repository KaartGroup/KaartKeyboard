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
    
    /// Whether the keys are being laid out for a phone, which several of the sizes below depend on.
    ///
    /// The idiom and not the size class: an iPad in a narrow split is still an iPad, and the app
    /// that hosts this keyboard forces a compact horizontal size class on the screen it is raised
    /// over, so a size-class test would give a phone's sizes on an iPad.
    static var isPhoneLayout: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }

    /// The gutter the keyboard lays out between keys. Single source of truth for
    /// KeyboardViewController.spacing and for the touch outset below.
    static let gutter: CGFloat = 5.0
    
    /// Title size for the letter and word keys.
    static let titleFontSize: CGFloat = 20.0

    /// The cream fill and brown text every plain key -- letters, space, backspace -- starts
    /// from, matched against a reference mockup's palette.
    static let defaultKeyFill = UIColor(red: 234.0/255, green: 227.0/255, blue: 210.0/255, alpha: 1.0)
    static let defaultTitleColor = UIColor(red: 72.0/255, green: 55.0/255, blue: 42.0/255, alpha: 1.0)

    /// The selected state, a shade down from the cream so a held key reads as held.
    ///
    /// This used to be a red-to-grey CAGradientLayer rendered to an image, in a palette nothing
    /// else in the keyboard uses, and sized to `bounds` inside init -- before Auto Layout had
    /// given the key a size -- so the image it produced was junk regardless.
    ///
    /// The preset and number keys set their own selected fill, and the only other key that asks
    /// for this state is shift in caps mode, which nothing can currently reach: the only
    /// assignment of ShiftMode.caps is the self-transition in shiftButtonPressed.
    static let defaultSelectedKeyFill = UIColor(red: 205.0/255, green: 196.0/255, blue: 178.0/255, alpha: 1.0)

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
    /// A phone's keys are 46pt tall against the iPad's 58.6, and these four are bounded by that
    /// height, so they come down with it or they clip. One factor rather than four more literals:
    /// the four have been tuned against each other, and scaling them together is what keeps that
    /// tuning intact on a shorter key.
    static var glyphScale: CGFloat {
        return isPhoneLayout ? 0.78 : 1.0
    }

    static var backspaceTitleFontSize: CGFloat { return 42.0 * glyphScale }
    static var returnTitleFontSize: CGFloat { return 38.0 * glyphScale }
    static var globeTitleFontSize: CGFloat { return 38.0 * glyphScale }
    static var shiftTitleFontSize: CGFloat { return 32.0 * glyphScale }

    /// The swap glyph on the phone's combined control key. Bounded by the key's *width* rather than
    /// its height, unlike the four above: that key is as narrow as a number key -- it shares the
    /// column -- while standing a full key tall, so width is what runs out first.
    static let swapTitleFontSize: CGFloat = 22.0

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
        setTitleColor(KeyButton.defaultTitleColor, for: .normal)
        titleLabel?.sizeToFit()

        setBackgroundImage(UIImage.fromColor(KeyButton.defaultKeyFill), for: .normal)
        setBackgroundImage(UIImage.fromColor(KeyButton.defaultSelectedKeyFill), for: .selected)

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
    static let padSymbolFontSize: CGFloat = 18.0

    /// What a phone takes off that: 30%.
    ///
    /// A phone's number key is roughly a third the width of an iPad's, and the symbol shares the key
    /// with a numeral centred across the whole of it, so the size the iPad reads comfortably at
    /// crowds the numeral here.
    static let phoneSymbolScale: CGFloat = 0.7

    static var symbolFontSize: CGFloat {
        return isPhoneLayout ? padSymbolFontSize * phoneSymbolScale : padSymbolFontSize
    }

    /// The fraction of the key's height the symbol is centred within, measured from the top.
    ///
    /// The symbol sits in the middle of this band and the numeral is centred across the whole key,
    /// so shortening the band is what lifts the symbol clear of the numeral. A phone's key is the
    /// same height as an iPad's but carries a numeral nearly as large across a third of the width,
    /// which is what brought the two together.
    static var symbolBandHeight: CGFloat {
        return isPhoneLayout ? 0.34 : 0.5
    }

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
        // Same white as this key's numeral, and as the preset keys.
        symbolLabel.textColor = UIColor.white
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
                                   height: bounds.height * SymbolKeyButton.symbolBandHeight)
    }
}
