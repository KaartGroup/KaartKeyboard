//
//  ViewController.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import UIKit

//    var keyboardHeight: CGFloat!

class ViewController: UIViewController {
    
    var textView: UITextView!
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override func loadView() {
        super.loadView()
        self.view = UIView(frame: UIScreen.main.applicationFrame)
        self.textView = UITextView(frame: self.view.frame)
        self.textView.isScrollEnabled = true
        self.textView.isUserInteractionEnabled = true
        self.view.addSubview(self.textView)
            
        if #available(iOS 9.0, *) {
            //self.textView.inputAssistantItem.leadingBarButtonGroups = []
            self.textView.autocorrectionType = .default;
        } else {
            // Fallback on earlier versions
        }
        if #available(iOS 9.0, *) {
            //self.textView.inputAssistantItem.trailingBarButtonGroups = []
        } else {
            // Fallback on earlier versions
        }
        self.textView.deleteBackward()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.textView.becomeFirstResponder()
            }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.becomeFirstResponder()
    }
}
