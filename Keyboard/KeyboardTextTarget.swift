//
//  KeyboardTextTarget.swift
//  Keyboard
//
//  Copyright (c) 2026 Kaart Group, LLC. All rights reserved.
//

import UIKit

/// Where the keys send what they type.
///
/// The keyboard used to talk to `UITextDocumentProxy` directly. Only a keyboard extension has one,
/// so that single reference is what tied the whole layout to being an extension. These are the three
/// operations the keys actually perform; an extension supplies them from its proxy and an app from
/// the text field the keyboard is attached to.
protocol KeyboardTextTarget: AnyObject {
    func insertText(_ text: String)
    func deleteBackward()

    /// The text between the start of the document and the cursor. Delete-by-word reads it to decide
    /// how much a single hold should remove.
    var documentContextBeforeInput: String? { get }
}

/// The target a keyboard with no host types into: nowhere.
///
/// A host that has not been wired up is a mistake, but it is one the keyboard should survive with
/// dead keys rather than by trapping on an unwrapped target in the middle of a touch.
final class DiscardedTextTarget: KeyboardTextTarget {
    static let shared = DiscardedTextTarget()
    private init() {}

    func insertText(_ text: String) {}
    func deleteBackward() {}
    var documentContextBeforeInput: String? { return nil }
}

/// Types into the document a keyboard extension has been raised over.
///
/// The input view controller is held weakly and the proxy read through it on each call: the
/// controller owns the keyboard, which owns this, so holding it back would be a cycle -- and the
/// proxy is only meaningful for as long as the controller is on screen anyway.
final class DocumentProxyTextTarget: KeyboardTextTarget {
    private weak var inputViewController: UIInputViewController?

    init(inputViewController: UIInputViewController) {
        self.inputViewController = inputViewController
    }

    private var proxy: UITextDocumentProxy? {
        return inputViewController?.textDocumentProxy
    }

    func insertText(_ text: String) {
        proxy?.insertText(text)
    }

    func deleteBackward() {
        proxy?.deleteBackward()
    }

    var documentContextBeforeInput: String? {
        return proxy?.documentContextBeforeInput
    }
}

/// Types into an ordinary text field or text view inside an app.
///
/// `insertText` and `deleteBackward` are `UIKeyInput`'s own methods, which every `UITextInput`
/// already implements against its own selection -- so the keys land where the cursor is, and
/// selected text is replaced, without this having to do any of that arithmetic itself.
final class TextInputTarget: KeyboardTextTarget {
    private weak var input: UITextInput?

    init(input: UITextInput) {
        self.input = input
    }

    func insertText(_ text: String) {
        input?.insertText(text)
    }

    func deleteBackward() {
        input?.deleteBackward()
    }

    /// The document context an extension gets handed, reconstructed from the field's own text.
    ///
    /// A proxy reports the text before the insertion point; here that is everything from the start
    /// of the document up to where the selection begins. `start` rather than `end` so that with a
    /// range selected this describes what precedes it, which is what delete-by-word wants to look
    /// back over.
    var documentContextBeforeInput: String? {
        guard let input = input,
              let selection = input.selectedTextRange,
              let precedingRange = input.textRange(from: input.beginningOfDocument, to: selection.start) else {
            return nil
        }
        return input.text(in: precedingRange)
    }
}
