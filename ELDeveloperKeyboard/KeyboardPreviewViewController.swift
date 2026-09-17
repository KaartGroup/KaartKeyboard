//
//  KeyboardPreviewViewController.swift
//  KaartKeyboard
//
//  Copyright (c) 2026 Kaart Group, LLC. All rights reserved.
//

import UIKit

/// Shows the keyboard the way an app hosts it: attached to a text field, in this process.
///
/// It exists to be run in the simulator while the layout is worked on. Reaching the keyboard the
/// other way -- installing the extension and enabling it in Settings -- costs several minutes per
/// change and cannot be reached from a fresh simulator at all, which is no way to iterate on a
/// layout. This is also the exact arrangement the keyboard will have once it moves into Maprizon,
/// so what looks right here is what will look right there.
class KeyboardPreviewViewController: UIViewController {
    private let field = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Keyboard Preview"
        view.backgroundColor = .white

        field.borderStyle = .roundedRect
        field.placeholder = "Type here"
        field.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(field)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            field.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16)
        ])

        // The globe key hands the field back to the system keyboard, which is the whole point of it
        // in an app -- but then there is no key left that brings the Kaart keys back, so the way
        // back lives up here.
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Kaart Keys",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(attachKaartKeyboard))

        attachKaartKeyboard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        field.becomeFirstResponder()
    }

    @objc private func attachKaartKeyboard() {
        KaartKeyboardInputView.attach(to: field, hostedBy: self)
    }
}
