//
//  TouchForwardingView.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import Foundation
import UIKit

/**
    The methods declared in the TouchForwardingViewDelegate protocol allow the adopting delegate to respond to override the behaviour of hitTest:withEvent: for the TouchForwardingView class.
*/
protocol TouchForwardingViewDelegate: class {
    /**
        Allows the delegate to override the behaviour of hitTest:withEvent: for this view.
     
        - parameter point: The CGPoint that was touched.
        - parameter event: The touch event.
        - parameter superResult: The UIView returned by the call to super.
    
        - returns: A UIView that the delegate decides should receive the touch event.
    */
    func viewForHitTestWithPoint(_ point: CGPoint, event: UIEvent?, superResult: UIView?) -> UIView?
}

class TouchForwardingView: UIView {
    
    // MARK: Properties
    
    weak var delegate: TouchForwardingViewDelegate?
    
    // MARK: Constructors
    
    init(frame: CGRect, delegate: TouchForwardingViewDelegate?) {
        self.delegate = delegate
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Overridden methods
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if let unwrappedDelegate = delegate {
            return unwrappedDelegate.viewForHitTestWithPoint(point, event: event, superResult: result)
        }
        return result
    }
}
