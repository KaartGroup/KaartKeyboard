//
//  SplitViewController.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 10/9/18.
//  Copyright © 2018 Kaart Group. All rights reserved.
//

import UIKit

class SplitViewController: UISplitViewController {
    
    override func loadView() {
        super.loadView()
        self.preferredDisplayMode = .allVisible
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let appDelegate: AppDelegate? = UIApplication.shared.delegate as? AppDelegate
        
        if !((appDelegate?.isKeyboardExtensionEnabled())!){
            let storyboard = UIStoryboard(name: "MainStoryboard", bundle: nil)
            let controller = storyboard.instantiateViewController(withIdentifier: "SetUpController")
            self.present(controller, animated: true, completion: nil)
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
