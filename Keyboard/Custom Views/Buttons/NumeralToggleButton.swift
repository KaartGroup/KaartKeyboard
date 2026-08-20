//
//  NumeralToggleButton.swift
//  KaartKeyboard
//
//  Copyright (c) 2018 Kaart Group. All rights reserved.
//

import Foundation
import UIKit

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
    static let legendFontSize: CGFloat = 14.4
    
    // MARK: Properties
    
    fileprivate let topLabel = UILabel()
    fileprivate let bottomLabel = UILabel()
    fileprivate let divider = UIView()
    
    // MARK: Constructors
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        for label in [topLabel, bottomLabel] {
            label.font = UIFont(name: "HelveticaNeue", size: NumeralToggleButton.legendFontSize)
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
        let half = bounds.height / 2
        
        // Each line owns a full half of the key and is centred in it, which leaves roughly 6pt
        // between the text and the divider without a clearance constant to keep in step.
        topLabel.frame = CGRect(x: inset, y: 0, width: width, height: half)
        bottomLabel.frame = CGRect(x: inset, y: half, width: width, height: half)
        divider.frame = CGRect(x: inset, y: half - rule / 2, width: width, height: rule)
    }
}
