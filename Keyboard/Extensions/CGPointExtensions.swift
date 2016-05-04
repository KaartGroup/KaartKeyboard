//
//  CGPointMidpoint.swift
//  ELDeveloperKeyboard
//
//  Created by Kari Kraam on 2016-04-25.
//  Copyright (c) 2016 Kari Kraam. All rights reserved.
//

import Foundation
import UIKit

extension CGPoint {
    /**
        Calculates the midpoint between two CGPoints.
    
        - returns: The CGPoint at the midpoint of two CGPoints.
    */
    func midPoint(point: CGPoint) -> CGPoint {
        return CGPointMake((x + point.x) / 2.0, (y + point.y) / 2.0)
    }
    
    /**
        Calculates the distance between two CGPoints.
        - returns: The distance between two CGPoints.
    */
    func distance(point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
}