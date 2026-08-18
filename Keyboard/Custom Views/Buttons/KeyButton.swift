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
        
        titleLabel?.font = UIFont(name: "HelveticaNeue", size: 20.0)
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
}

/**
    NumeralToggleButton is a KeyButton carrying a two-line legend instead of a title: the preset
    groups it swaps on a long press, a hairline, then the numeral planes it swaps on a tap.
    Laid out in layoutSubviews so the legend follows the button's constrained width rather than the
    frame it happened to be created with.
*/
class NumeralToggleButton: KeyButton {
    
    // MARK: Constants
    
    /// Keeps the legend off the key's edges.
    static let legendInset: CGFloat = 4.0
    static let dividerThickness: CGFloat = 1.0
    
    // MARK: Properties
    
    fileprivate let topLabel = UILabel()
    fileprivate let bottomLabel = UILabel()
    fileprivate let divider = UIView()
    
    // MARK: Constructors
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        for label in [topLabel, bottomLabel] {
            label.font = UIFont(name: "HelveticaNeue", size: 12.0)
            label.textAlignment = .center
            label.textColor = UIColor(white: 1.0/255, alpha: 1.0)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            addSubview(label)
        }
        topLabel.text = "P1/P2"
        bottomLabel.text = "4/IV"
        
        divider.backgroundColor = UIColor(white: 1.0/255, alpha: 0.45)
        addSubview(divider)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Overridden methods
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let inset = NumeralToggleButton.legendInset
        let rule = NumeralToggleButton.dividerThickness
        let width = bounds.width - inset * 2
        let lineHeight = (bounds.height - inset * 2 - rule) / 2
        
        topLabel.frame = CGRect(x: inset, y: inset, width: width, height: lineHeight)
        divider.frame = CGRect(x: inset, y: inset + lineHeight, width: width, height: rule)
        bottomLabel.frame = CGRect(x: inset, y: divider.frame.maxY, width: width, height: lineHeight)
    }
}
