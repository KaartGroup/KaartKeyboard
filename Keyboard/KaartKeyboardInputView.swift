//
//  KaartKeyboardInputView.swift
//  Keyboard
//
//  Copyright (c) 2026 Kaart Group, LLC. All rights reserved.
//

import UIKit

/// Raises the Kaart keyboard inside an app, as a text field's `inputView`.
///
/// This is the counterpart to `KeyboardInputViewController`: the same `KeyboardViewController`, the
/// same keys, hosted by an app rather than by the keyboard-extension point. A field with one of
/// these attached gets the Kaart keys instead of the system keyboard, for that field only, with no
/// extension to install in Settings and no Full Access to grant.
final class KaartKeyboardInputView: UIInputView {
    let keyboardController = KeyboardViewController()

    /// The field being typed into. Weak because the field owns this as its `inputView`.
    private weak var field: UITextField?

    /// Attaches a Kaart keyboard to `field` and returns it, in case the caller wants to reach the
    /// controller inside.
    ///
    /// `reloadInputViews()` is what makes the swap visible when the field is already first
    /// responder; without it the system keyboard stays up until the field is dismissed and tapped
    /// again.
    @discardableResult
    static func attach(to field: UITextField, hostedBy parent: UIViewController) -> KaartKeyboardInputView {
        let keyboard = KaartKeyboardInputView(hostedBy: parent, typingInto: field)
        field.inputView = keyboard
        field.reloadInputViews()
        return keyboard
    }

    private init(hostedBy parent: UIViewController, typingInto field: UITextField) {
        // .keyboard rather than .default so the host draws on the system's keyboard background,
        // which is what shows through in the gutters between keys.
        super.init(frame: .zero, inputViewStyle: .keyboard)

        self.field = field

        // An input view is sized by its autoresizing mask unless it is told otherwise, and the
        // keyboard states its height in a constraint on its own view. Without both of these the
        // constraint is ignored and the keyboard comes up at UIKit's default height, clipped.
        allowsSelfSizing = true
        translatesAutoresizingMaskIntoConstraints = false

        keyboardController.textTarget = TextInputTarget(input: field)

        parent.addChild(keyboardController)
        addSubview(keyboardController.view)
        keyboardController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyboardController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            keyboardController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            keyboardController.view.topAnchor.constraint(equalTo: topAnchor),
            keyboardController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        keyboardController.didMove(toParent: parent)

        // In an extension this key offers the other keyboards the user has installed. There are
        // none to offer here -- the app is not an input mode -- so it does the one equivalent thing
        // an app can: gives the field back to the system keyboard.
        keyboardController.nextKeyboardButton.addTarget(self,
                                                        action: #selector(handleSystemKeyboard),
                                                        for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Hands the field back to the system keyboard.
    ///
    /// Clearing `inputView` and calling `reloadInputViews()` is sufficient on its own. The resign
    /// and re-take below is belt and braces, and is kept only because it is what this has always
    /// done here.
    ///
    /// It was added to fix a field that appeared to come back with no keyboard at all. That was
    /// measured on a simulator with a hardware keyboard attached, which suppresses every software
    /// keyboard while still drawing custom `inputView`s -- so the symptom belonged to the
    /// simulator, not to this code. The comment that used to sit here stated the opposite as fact.
    /// Confirmed on 2026-09-18 by disconnecting the hardware keyboard and watching the system
    /// keyboard come up without the cycle.
    ///
    /// Note this leaves no key on screen that brings the Kaart keys back -- the system keyboard is
    /// the system's, and nothing on it can call into an app. Here that is survivable because
    /// `KeyboardPreviewViewController` puts a "Kaart Keys" button in the navigation bar. An app
    /// without such a button needs one before wiring the globe key to this, or the switch only goes
    /// one way. Maprizon left its globe key inert for exactly that reason.
    @objc private func handleSystemKeyboard() {
        guard let field = field else { return }
        field.inputView = nil
        if field.isFirstResponder {
            field.resignFirstResponder()
            field.becomeFirstResponder()
        }
    }
}
