//
//  ViewController.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import UIKit

//    var keyboardHeight: CGFloat!

class SetUpController: UIViewController {
    
    
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
                UIApplication.shared.openURL(settingsUrl)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(updateView), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
    }
    
    @objc func updateView() {
        let appDelegate: AppDelegate? = UIApplication.shared.delegate as? AppDelegate
        if ((appDelegate?.isKeyboardExtensionEnabled())!){
            let storyboard = UIStoryboard(name: "MainStoryboard", bundle: nil)
            let controller = storyboard.instantiateViewController(withIdentifier: "SplitViewController")
            self.present(controller, animated: true, completion: nil)
        }
    }
}
