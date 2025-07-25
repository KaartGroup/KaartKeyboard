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
