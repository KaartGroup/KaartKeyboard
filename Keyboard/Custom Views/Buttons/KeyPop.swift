//
//  KeyPop.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 10/11/18.
//  Copyright © 2018 Kaart Group. All rights reserved.
//

import Foundation
import UIKit

protocol KeyPopDelegate: class {
    /**
     Respond to the SuggestionButton being pressed.
     
     - parameter button: The SuggestionButton that was pressed.
     */
//    func handlePressForKeyPop(_ button: SuggestionButton)
}

class KeyPopView: UIView {
    
    static let widthPadding : CGFloat = 5.0
    static let leftOffset : CGFloat = -5.0
    
    init(frame: CGRect, letters: [String]) {
        super.init(frame: frame)
        addLetters(letters: letters)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//    override class func layerClass() -> AnyClass {
//        return CAShapeLayer.self
//    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        var run : CGFloat = KeyPopView.widthPadding
        for l in labels {
            let s = sizeForLabel(l: l)
            let mh = maxHeight(ls: labels)
            l.frame = CGRect(x: run, y: -mh, width: s.width, height: s.height)
            run += s.width + KeyPopView.widthPadding
        }
    }
    
    var shapeLayer: CAShapeLayer {
        get {
            return layer as! CAShapeLayer
        }
    }
    
    var path: CGPath {
        get {
            return shapeLayer.path!
        }
        set(nv) {
            shapeLayer.shadowPath = nv
            shapeLayer.path = nv
        }
    }
    
    var labels : [UILabel] = [] {
        willSet {
            for l in labels {
                l.removeFromSuperview()
            }
        }
        didSet {
            for l in labels {
                addSubview(l)
            }
            path = keyPopPath(ls: labels, cornerRadius: cornerRadius).cgPath
        }
    }
    
    var cornerRadius : CGFloat = 4 {
        didSet {
            path = keyPopPath(ls: labels, cornerRadius: cornerRadius).cgPath
        }
    }
    
    override var backgroundColor: UIColor? {
        set(newValue) {
            shapeLayer.fillColor = newValue?.cgColor
        }
        get {
            return UIColor(cgColor: shapeLayer.fillColor!)
        }
    }
    
    func keyPopPath(ls : [UILabel], cornerRadius: CGFloat) -> UIBezierPath {
        let radius = CGSize(width: cornerRadius, height:cornerRadius);
        let f = CGRect(x: 0, y: 0, width: frame.width + KeyPopView.widthPadding * 2, height: frame.height)
        let mh = maxHeight(ls: ls)
        var b = UIBezierPath(roundedRect: CGRect(x: KeyPopView.leftOffset, y: -mh, width: widthForLabels(ls: ls) - KeyPopView.leftOffset + KeyPopView.widthPadding, height: mh), byRoundingCorners: UIRectCorner.allCorners, cornerRadii: radius)
        b.append(UIBezierPath(roundedRect: f, byRoundingCorners: UIRectCorner(rawValue: UIRectCorner.bottomLeft.rawValue | UIRectCorner.bottomRight.rawValue), cornerRadii: radius))
        return b
    }
    
    func addLetters(letters : [String]) {
        labels = letters.map({(s: String) -> UILabel in
            var l = UILabel()
            l.text = s
            return l
        })
    }
    
    func widthForLabels(ls: [UILabel]) -> CGFloat {
        return ls.reduce(0, {(t, l) in t + sizeForLabel(l: l).width + KeyPopView.widthPadding}) + KeyPopView.widthPadding
    }
    
    func sizeForLabel(l: UILabel) -> CGSize {
        return l.text!.size(withAttributes: [NSAttributedStringKey.font: l.font])
    }
    
    func maxHeight(ls: [UILabel]) -> CGFloat {
        var m : CGFloat = 0;
        for l in ls {
            let h = sizeForLabel(l: l).height
            m = m > h ? m : h
        }
        return m
    }
}
