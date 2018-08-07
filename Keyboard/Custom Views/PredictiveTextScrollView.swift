//
//  PredictiveTextScrollView.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import Foundation
import UIKit

/**
    PredictiveTextScrollView is a subclass of UIScrollView designed to contain a number of UIButton subviews, cancelling their touches to allow scrolling behaviour.
*/
class PredictiveTextScrollView: UIScrollView {
    
    // MARK: Constructors
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        canCancelContentTouches = true
        delaysContentTouches = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Overridden Methods
    
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return view is UIButton ? true : super.touchesShouldCancel(in: view)
    }
}
