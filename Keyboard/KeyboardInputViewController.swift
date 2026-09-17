//
//  KeyboardInputViewController.swift
//  Keyboard
//
//  Copyright (c) 2026 Kaart Group, LLC. All rights reserved.
//

import UIKit

/// The keyboard extension's entry point, named by `NSExtensionPrincipalClass` in Info.plist.
///
/// It owns no keys of its own. The keyboard is `KeyboardViewController`, an ordinary view
/// controller hosted here as a child, and this supplies the two things only an extension can:
/// the document to type into, and the switch to another keyboard.
class KeyboardInputViewController: UIInputViewController {
    private let keyboard = KeyboardViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        keyboard.textTarget = DocumentProxyTextTarget(inputViewController: self)

        addChild(keyboard)
        view.addSubview(keyboard.view)
        keyboard.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyboard.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.view.topAnchor.constraint(equalTo: view.topAnchor),
            keyboard.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        keyboard.didMove(toParent: self)

        // The keyboard builds this key and leaves it unwired, because showing the input-mode list
        // is a UIInputViewController method and there is no such list to show when an app hosts the
        // same keys. .allTouchEvents rather than .touchUpInside is what iOS asks for here: it lets
        // a press-and-hold open the list of installed keyboards while a tap still advances to the
        // next one.
        if #available(iOS 10.0, *) {
            keyboard.nextKeyboardButton.addTarget(self,
                                                  action: #selector(handleInputModeList(from:with:)),
                                                  for: .allTouchEvents)
        } else {
            keyboard.nextKeyboardButton.addTarget(self,
                                                  action: #selector(advanceToNextInputMode),
                                                  for: .touchUpInside)
        }
    }
}
