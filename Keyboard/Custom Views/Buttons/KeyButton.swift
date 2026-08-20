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

    /// Title size for the keys whose label is a symbol rather than text -- backspace, shift,
    /// return, and the globe. Symbols like U+232B and U+21E7 are drawn well inside their em
    /// box, so at titleFontSize they read visibly smaller than the capitals beside them.
    ///
    /// Kept under the key height: KeyButton sets masksToBounds, so a glyph too large for the
    /// key is clipped rather than allowed to overflow. 42pt yields a 49pt label against a
    /// 58.5pt key in portrait and a 54pt key in landscape, so this is close to the ceiling --
    /// raising it further wants a landscape check.
    static let glyphTitleFontSize: CGFloat = 42.0

    /// Shift sits 15% under the other glyph keys. Written as a literal rather than derived
    /// from glyphTitleFontSize so the number you read is the number that applies.
    static let shiftTitleFontSize: CGFloat = 35.7

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
        setTitleColor(UIColor(white: 1.0/255, alpha: 1.0), for: .normal)
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
    func useGlyphTitleFont(size: CGFloat = KeyButton.glyphTitleFontSize) {
        titleLabel?.font = UIFont(name: "HelveticaNeue", size: size)
    }
}
