//
//  ViewController.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import UIKit

//    var keyboardHeight: CGFloat!

class ELViewController: UIViewController {
    
    var textView: UITextView!
    
    public func isKeyboardExtensionEnabled() -> Bool {
        guard let appBundleIdentifier = Bundle.main.bundleIdentifier else {
            fatalError("isKeyboardExtensionEnabled(): Cannot retrieve bundle identifier.")
        }
        
        guard let keyboards = UserDefaults.standard.dictionaryRepresentation()["AppleKeyboards"] as? [String] else {
            // There is no key `AppleKeyboards` in NSUserDefaults. That happens sometimes.
            return false
        }
        
        let keyboardExtensionBundleIdentifierPrefix = appBundleIdentifier + "."
        for keyboard in keyboards {
            if keyboard.hasPrefix(keyboardExtensionBundleIdentifierPrefix) {
                print("Keyboard Enabled")
                return true
            }
        }
        print("Keyboard Disabled")
        return false
    }
    
    
    @IBAction func settings(_ sender: UIButton) {
        guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString + Bundle.main.bundleIdentifier!) else {
            return
        }
        
        print(settingsUrl)
        if UIApplication.shared.canOpenURL(settingsUrl) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                    print("Settings opened: \(success)") // Prints true
                })
            } else {
                // Fallback on earlier versions
            }
        }
    }
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
//        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
//    }

    override func loadView() {
        super.loadView()
        if isKeyboardExtensionEnabled() {
            print("TRUE")
            self.view = UIView(frame: UIScreen.main.applicationFrame)
            self.textView = UITextView(frame: self.view.frame)
            self.textView.isScrollEnabled = true
            self.textView.isUserInteractionEnabled = true
            self.view.addSubview(self.textView)
        

        
        if #available(iOS 9.0, *) {
            self.textView.inputAssistantItem.leadingBarButtonGroups = []
            self.textView.autocorrectionType = .default;
        } else {
            // Fallback on earlier versions
        }
        if #available(iOS 9.0, *) {
            self.textView.inputAssistantItem.trailingBarButtonGroups = []
        } else {
            // Fallback on earlier versions
        }
        self.textView.deleteBackward()
        }
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
