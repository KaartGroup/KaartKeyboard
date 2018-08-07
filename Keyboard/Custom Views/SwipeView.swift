//
//  SwipeView.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import Foundation
import UIKit

/**
    A subclass of UIView that takes points and draws them to the screen.
*/
class SwipeView: UIView {
    
    // MARK: Constants
    
    fileprivate let maxLength = CGFloat(300.0)
    
    // MARK: Properties
    
    fileprivate lazy var points = [CGPoint]()
    
    fileprivate var swipeLength: CGFloat {
        get {
            if (points.count < 2) {
                return 0
            }
            var total = CGFloat(0.0)
            var currentPoint: CGPoint!
            var previousPoint: CGPoint!
            for i in 2..<points.count {
                currentPoint = points[i]
                previousPoint = points[i - 1]
                total += currentPoint.distance(previousPoint)
            }
            return total
        }
    }
    
    // MARK: Constructors
    
    init(containerView: UIView, topOffset: CGFloat) {
        super.init(frame: CGRect(x: 0.0, y: topOffset, width: containerView.frame.width, height: containerView.frame.height - topOffset))
        isOpaque = false
        backgroundColor = UIColor.clear
        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Overridden methods
    
    override func draw(_ rect: CGRect) {
        if points.count >= 3 {
            let context = UIGraphicsGetCurrentContext()
            
            for i in 2..<points.count {
                // Interpolate gradient and calculate line width.
                let percentage = CGFloat(i) / CGFloat(points.count)
                context!.setStrokeColor(red: (41.0 + (67.0 - 41.0) * percentage)/255, green: (10.0 + (116.0 - 10.0) * percentage)/255, blue: (199.0 + (224.0 - 199.0) * percentage)/255, alpha: 1.0)
                context!.setLineWidth(pow(percentage, 0.5) * 4.0)

                // Three points needed for quadratic bezier smoothing.
                let currentPoint = points[i]
                let previousPoint1 = points[i - 1]
                let previousPoint2 = points[i - 2]
                
                // Calculate midpoints used in quadratic bezier smoothing.
                let midPoint1 = previousPoint1.midPoint(previousPoint2)
                let midPoint2 = currentPoint.midPoint(previousPoint1)
            
                // Draw bezier.
                context!.move(to: CGPoint(x: midPoint1.x, y: midPoint1.y))
                //CGContextAddQuadCurveToPoint(context!, previousPoint1.x, previousPoint1.y, midPoint2.x, midPoint2.y)
                context!.addQuadCurve(to: CGPoint(x:previousPoint1.x, y:previousPoint1.y), control: CGPoint(x:midPoint2.x, y:midPoint2.y))
                context!.strokePath()
            }
        }
    }
    
    // MARK: Overridden methods
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawTouch(touches.first)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawTouch(touches.first)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        clear()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clear()
    }

    // MARK: Helper methods
    
    fileprivate func clear() {
        points.removeAll(keepingCapacity: false)
        setNeedsDisplay()
    }
    
    fileprivate func drawTouch(_ touch: UITouch?) {
        if let touch = touch {
            let touchPoint = touch.location(in: self)
            let point = CGPoint(x: touchPoint.x, y: touchPoint.y)
            points.append(point)
            while swipeLength > maxLength {
                points.remove(at: 0)
            }
            setNeedsDisplay()
        }
    }
}
