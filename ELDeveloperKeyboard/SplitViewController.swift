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
    
    /// Set once the onboarding has been put on screen, so it is offered on the way in and not again
    /// every time this controller reappears -- which is what dismissing the modal, or coming back
    /// from Settings, would otherwise do.
    private var hasOfferedSetUp = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Onboarding is for people who have *not* added the keyboard yet. The test used to be the
        // other way round -- present the walkthrough when the keyboard is already enabled -- which
        // was harmless only because AppDelegateSingleton's unassigned property made the whole
        // condition false. Fixing that check without also turning this around would have started
        // showing "here is how to enable the keyboard" to the one group who had already done it.
        guard !hasOfferedSetUp, !AppDelegate.isKeyboardExtensionEnabled() else { return }
        hasOfferedSetUp = true

        let storyboard = UIStoryboard(name: "MainStoryboard", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "SetUpController")
        self.present(controller, animated: true, completion: nil)
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
