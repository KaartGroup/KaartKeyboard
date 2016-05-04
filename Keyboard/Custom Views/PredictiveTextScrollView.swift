//
//  PredictiveTextScrollView.swift
//  ELDeveloperKeyboard
//
//  Created by Kari Kraam on 2016-04-25.
//  Copyright (c) 2016 Kari Kraam. All rights reserved.
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
    
    override func touchesShouldCancelInContentView(view: UIView) -> Bool {
        return view is UIButton ? true : super.touchesShouldCancelInContentView(view)
    }
}