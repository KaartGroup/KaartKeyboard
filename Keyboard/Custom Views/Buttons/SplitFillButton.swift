//
//  SplitFillButton.swift
//  KaartKeyboard
//
//  Copyright (c) 2018 Kaart Group. All rights reserved.
//

import Foundation
import UIKit

/**
    A KeyButton whose fill is divided corner to corner, from the bottom-left to the top-right,
    into two triangles of different greys. Toggling the key swaps which grey is on which side, so
    the fill itself carries the key's state -- the title stays fixed.

    Drawn with shape layers re-pathed in layoutSubviews rather than a baked background image, so
    the diagonal stays exact when the key is re-sized on rotation.
*/
class SplitFillButton: KeyButton {
    
    // MARK: Constants
    
    /// The upper triangle in the unflipped state; the lower one when flipped.
    static let upperFill = UIColor(white: 148.0/255, alpha: 1.0)
    /// The lower triangle in the unflipped state; the upper one when flipped.
    static let lowerFill = UIColor(white: 187.0/255, alpha: 1.0)
    
    // MARK: Properties
    
    fileprivate let upperLayer = CAShapeLayer()
    fileprivate let lowerLayer = CAShapeLayer()
    
    /// false is the resting state: upperFill above the diagonal. true swaps the two.
    var isFlipped: Bool = false {
        didSet { applyFills() }
    }
    
    // MARK: Constructors
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // KeyButton fills itself with a white background image, which UIButton renders in a
        // subview -- above anything inserted into the layer. Clear it or it hides the split.
        setBackgroundImage(nil, for: .normal)
        
        layer.insertSublayer(lowerLayer, at: 0)
        layer.insertSublayer(upperLayer, at: 1)
        applyFills()
        
        titleLabel?.font = UIFont(name: "HelveticaNeue-Bold", size: KeyButton.titleFontSize)
            ?? UIFont.boldSystemFont(ofSize: KeyButton.titleFontSize)
        setTitleColor(UIColor.black, for: .normal)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Overridden methods
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let width = bounds.width
        let height = bounds.height
        
        // The divide runs bottom-left to top-right, so the upper triangle carries the top edge
        // and the lower one carries the bottom edge.
        let upper = UIBezierPath()
        upper.move(to: CGPoint(x: 0, y: 0))
        upper.addLine(to: CGPoint(x: width, y: 0))
        upper.addLine(to: CGPoint(x: 0, y: height))
        upper.close()
        
        let lower = UIBezierPath()
        lower.move(to: CGPoint(x: width, y: 0))
        lower.addLine(to: CGPoint(x: width, y: height))
        lower.addLine(to: CGPoint(x: 0, y: height))
        lower.close()
        
        upperLayer.frame = bounds
        lowerLayer.frame = bounds
        upperLayer.path = upper.cgPath
        lowerLayer.path = lower.cgPath
    }
    
    // MARK: Methods
    
    fileprivate func applyFills() {
        upperLayer.fillColor = (isFlipped ? SplitFillButton.lowerFill : SplitFillButton.upperFill).cgColor
        lowerLayer.fillColor = (isFlipped ? SplitFillButton.upperFill : SplitFillButton.lowerFill).cgColor
    }
}
