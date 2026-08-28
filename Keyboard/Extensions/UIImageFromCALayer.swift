//
//  UIImageFromCALayer.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import Foundation
import UIKit
import QuartzCore

extension CALayer {
    /**
        Creates a UIImage from a CALayer.

        - returns: A UIImage that appears identical to the CALayer, or nil if the layer has no
                   area to render into.
    */
    // Optional rather than force unwrapping the context. A layer whose frame is empty -- one
    // sized from a view's bounds before Auto Layout has run, say -- gives
    // UIGraphicsBeginImageContextWithOptions nothing to work with, and it returns no context.
    func UIImageFromCALayer() -> UIImage? {
        guard frame.size.width > 0, frame.size.height > 0 else { return nil }
        UIGraphicsBeginImageContextWithOptions(frame.size, true, 0)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

/// Solid-colour key backgrounds, keyed by colour.
///
/// Every key sets at least one background image, and the whole keyboard is rebuilt on a language
/// switch and on every relayout, so this ran a graphics context sixty-odd times for what is only
/// ever a handful of distinct colours. UIColor's equality compares components, so two separately
/// constructed colours of the same value share an entry.
///
/// Main thread only, which is where the keyboard builds its keys.
private enum SolidColorImageCache {
    static var images: [UIColor: UIImage] = [:]
}

extension UIImage {
    static func fromColor(_ color: UIColor) -> UIImage {
        if let cached = SolidColorImageCache.images[color] { return cached }

        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
        context.setFillColor(color.cgColor)
        context.fill(rect)
        guard let img = UIGraphicsGetImageFromCurrentImageContext() else { return UIImage() }

        SolidColorImageCache.images[color] = img
        return img
    }
}
