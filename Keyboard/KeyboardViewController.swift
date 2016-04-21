	//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Kari Kraam on 2016-04-20.
//  Copyright (c) 2016 Kari Kraam. All rights reserved.
//

import Foundation
import UIKit

/**
    An iOS custom keyboard extension written in Swift designed to make it much, much easier to type code on an iOS device.
*/
class KeyboardViewController: UIInputViewController, CharacterButtonDelegate, SuggestionButtonDelegate, TouchForwardingViewDelegate {

    // MARK: Constants
    
    private let primaryCharacters = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]
    
    private let shortWord = ["Calle","Avenida","Callejón","Boulevard","Senda","Pasaje","Peatón"]
    
    lazy var suggestionProvider: SuggestionProvider = SuggestionTrie()
    
    lazy var languageProviders = CircularArray(items: [DefaultLanguageProvider(), SwiftLanguageProvider()] as [LanguageProvider])
    
    private let spacing: CGFloat = 4.0
    private let predictiveTextBoxHeight: CGFloat = 24.0
    private var predictiveTextButtonWidth: CGFloat {
        return (view.frame.width - 4 * spacing) / 3.0
    }
    private var keyboardHeight: CGFloat {
        let interfaceOrientation = UIDevice.currentDevice().orientation
        return (interfaceOrientation == .Portrait || interfaceOrientation == .PortraitUpsideDown) ? 300.0 : 260.0
    }
    private var keyWidth: CGFloat {
        return (view.frame.width - 11 * spacing) / 10.0
    }
    private var wordKeyWidth: CGFloat {
        return (view.frame.width - 8 * spacing) / 7.0
    }
    private var keyHeight: CGFloat {
        return (keyboardHeight - 7 * spacing) / 6.0
    }
    
    // MARK: User interface
    
    private var swipeView: SwipeView!
    private var predictiveTextScrollView: PredictiveTextScrollView!
    private var suggestionButtons = [SuggestionButton]()
    
    private lazy var characterButtons: [[CharacterButton]] = [
        [],
        [],
        []
    ]
    private var shiftButton: KeyButton!
    private var deleteButton: KeyButton!
    private var tabButton: KeyButton!
    private var nextKeyboardButton: KeyButton!
    private var spaceButton: KeyButton!
    private var returnButton: KeyButton!
    private var currentLanguageLabel: UILabel!
    private var oopButton: KeyButton!
    private var numpadButton: KeyButton!
    private var shortWordButton: KeyButton!

    // MARK: Timers
    
    private var deleteButtonTimer: NSTimer?
    private var spaceButtonTimer: NSTimer?
    
    // MARK: Properties
    
    private var heightConstraint: NSLayoutConstraint!
    
    private var proxy: UITextDocumentProxy {
        return textDocumentProxy 
    }
    
    private var lastWordTyped: String? {
        if let documentContextBeforeInput = proxy.documentContextBeforeInput as NSString? {
            let length = documentContextBeforeInput.length
            if length > 0 && NSCharacterSet.letterCharacterSet().characterIsMember(documentContextBeforeInput.characterAtIndex(length - 1)) {
                let components = documentContextBeforeInput.componentsSeparatedByCharactersInSet(NSCharacterSet.letterCharacterSet().invertedSet) 
                return components[components.endIndex - 1]
            }
        }
        return nil
    }

    private var languageProvider: LanguageProvider = DefaultLanguageProvider() {
        didSet {
            for (rowIndex, row) in characterButtons.enumerate() {
                for (characterButtonIndex, characterButton) in row.enumerate() {
                    characterButton.secondaryCharacter = languageProvider.secondaryCharacters[rowIndex][characterButtonIndex]
                    characterButton.tertiaryCharacter = languageProvider.tertiaryCharacters[rowIndex][characterButtonIndex]
                }
            }
            currentLanguageLabel.text = languageProvider.language
            suggestionProvider.clear()
            suggestionProvider.loadWeightedStrings(languageProvider.suggestionDictionary)
        }
    }

    private enum ShiftMode {
        case Off, On, Caps
    }
    
    private var shiftMode: ShiftMode = .Off {
        didSet {
            shiftButton.selected = (shiftMode == .Caps)
            for row in characterButtons {
                for characterButton in row {
                    switch shiftMode {
                    case .Off:
                        characterButton.primaryLabel.text = characterButton.primaryCharacter.lowercaseString
                        characterButton.secondaryLabel.text = " "
                        characterButton.tertiaryLabel.text = " "
                    case .On, .Caps:
                        characterButton.primaryLabel.text = characterButton.primaryCharacter.uppercaseString
                        characterButton.secondaryLabel.text = " "
                        characterButton.tertiaryLabel.text = " "
                    }
                
                }
            }
        }
    }
    
    // MARK: Constructors
    // FIXME: Uncomment init methods when crash bug is fixed. Also need to move languageProvider initialization to constructor to prevent unnecessary creation of two DefaultLanguageProvider instances.
//    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
//        self.shiftMode = .Off
//        self.languageProvider = languageProviders.currentItem!
//        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
//    }
//
//    required init(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
    
    // MARK: Overridden methods
    
//    override func loadView() {
//        let screenRect = UIScreen.mainScreen().bounds
//        self.view = TouchForwardingView(frame: CGRectMake(0.0, predictiveTextBoxHeight, screenRect.width, keyboardHeight - predictiveTextBoxHeight), delegate: self)
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 180.0/255, green: 180.0/255, blue: 180.0/255, alpha: 1)
        heightConstraint = NSLayoutConstraint(item: self.view, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 0.0, constant: self.keyboardHeight)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        initializeKeyboard()
    }
        
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        initializeKeyboard()
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        view.removeConstraint(heightConstraint)
        heightConstraint.constant = keyboardHeight
        view.addConstraint(heightConstraint)
    }
    
    // MARK: Event handlers
    // Shift Buttton Action(Uppercase, Lowercase disabled the Caps Mode)
    func shiftButtonPressed(sender: KeyButton) {
        switch shiftMode {
        case .Off:
            shiftMode = .On
        case .On:
            shiftMode = .Off
        case .Caps:
            shiftMode = .Off
        }
    }
    
    //
    func deleteButtonPressed(sender: KeyButton) {
        switch proxy.documentContextBeforeInput {
        case let s where s?.hasSuffix("    ") == true: // Cursor in front of tab, so delete tab.
            for i in 0..<4 { // TODO: Update to use tab setting.
                proxy.deleteBackward()
            }
        default:
            proxy.deleteBackward()
        }
        updateSuggestions()
    }
    
    //Delete Button long press action
    func handleLongPressForDeleteButtonWithGestureRecognizer(gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .Began:
            if deleteButtonTimer == nil {
                deleteButtonTimer = NSTimer(timeInterval: 0.1, target: self, selector: #selector(KeyboardViewController.handleDeleteButtonTimerTick(_:)), userInfo: nil, repeats: true)
                deleteButtonTimer!.tolerance = 0.01
                NSRunLoop.mainRunLoop().addTimer(deleteButtonTimer!, forMode: NSDefaultRunLoopMode)
            }
        default:
            deleteButtonTimer?.invalidate()
            deleteButtonTimer = nil
            updateSuggestions()
        }
    }
    
    func handleSwipeLeftForDeleteButtonWithGestureRecognizer(gestureRecognizer: UISwipeGestureRecognizer) {
        // TODO: Figure out an implementation that doesn't use bridgeToObjectiveC, in case of funny unicode characters.
        if let documentContextBeforeInput = proxy.documentContextBeforeInput as NSString? {
            if documentContextBeforeInput.length > 0 {
                var charactersToDelete = 0
                switch documentContextBeforeInput {
                case let s where NSCharacterSet.letterCharacterSet().characterIsMember(s.characterAtIndex(s.length - 1)): // Cursor in front of letter, so delete up to first non-letter character.
                    let range = documentContextBeforeInput.rangeOfCharacterFromSet(NSCharacterSet.letterCharacterSet().invertedSet, options: .BackwardsSearch)
                    if range.location != NSNotFound {
                        charactersToDelete = documentContextBeforeInput.length - range.location - 1
                    } else {
                        charactersToDelete = documentContextBeforeInput.length
                    }
                case let s where s.hasSuffix(" "): // Cursor in front of whitespace, so delete up to first non-whitespace character.
                    let range = documentContextBeforeInput.rangeOfCharacterFromSet(NSCharacterSet.whitespaceCharacterSet().invertedSet, options: .BackwardsSearch)
                    if range.location != NSNotFound {
                        charactersToDelete = documentContextBeforeInput.length - range.location - 1
                    } else {
                        charactersToDelete = documentContextBeforeInput.length
                    }
                default: // Just delete last character.
                    charactersToDelete = 1
                }
                
                for i in 0..<charactersToDelete {
                    proxy.deleteBackward()
                }
            }
        }
        updateSuggestions()
    }
    
    func handleDeleteButtonTimerTick(timer: NSTimer) {
        proxy.deleteBackward()
    }
    
    func spaceButtonPressed(sender: KeyButton) {
        for suffix in languageProvider.autocapitalizeAfter {
            if proxy.documentContextBeforeInput!.hasSuffix(suffix) {
                shiftMode = .On
            }
        }
        proxy.insertText(" ")
        updateSuggestions()
    }
    
    // Input the character "ñ" instead of tab
    func tabButtonPressed(sender: KeyButton) {
        proxy.insertText("ñ")
    }
    
    // Input the character ""
    func oopButtonPressed(sender: KeyButton) {
        proxy.insertText("ó")
    }
    
    // When the numpadButton is pressed
    func numpadButtonPressed(sender: KeyButton){
        proxy.insertText(sender.currentTitle!)
    }
    
    // When the shortWordButton is pressed
    func shortWordButtonPressed(sender: KeyButton){
        proxy.insertText(sender.currentTitle!)
        proxy.insertText(" ")
    }
    
    func handleLongPressForSpaceButtonWithGestureRecognizer(gestureRecognizer: UISwipeGestureRecognizer) {
        switch gestureRecognizer.state {
        case .Began:
            if spaceButtonTimer == nil {
                spaceButtonTimer = NSTimer(timeInterval: 0.1, target: self, selector: "handleSpaceButtonTimerTick:", userInfo: nil, repeats: true)
                spaceButtonTimer!.tolerance = 0.01
                NSRunLoop.mainRunLoop().addTimer(spaceButtonTimer!, forMode: NSDefaultRunLoopMode)
            }
        default:
            spaceButtonTimer?.invalidate()
            spaceButtonTimer = nil
            updateSuggestions()
        }
    }
    
    func handleSpaceButtonTimerTick(timer: NSTimer) {
        proxy.insertText(" ")
    }
    
    func handleSwipeLeftForSpaceButtonWithGestureRecognizer(gestureRecognizer: UISwipeGestureRecognizer) {
        UIView.animateWithDuration(0.1, animations: {
            self.moveButtonLabels(-self.keyWidth)
            }, completion: {
                (success: Bool) -> Void in
                self.languageProviders.increment()
                self.languageProvider = self.languageProviders.currentItem!
                self.moveButtonLabels(self.keyWidth * 2.0)
                UIView.animateWithDuration(0.1) {
                    self.moveButtonLabels(-self.keyWidth)
                }
            }
        )
    }
    
    func handleSwipeRightForSpaceButtonWithGestureRecognizer(gestureRecognizer: UISwipeGestureRecognizer) {
        UIView.animateWithDuration(0.1, animations: {
            self.moveButtonLabels(self.keyWidth)
            }, completion: {
                (success: Bool) -> Void in
                self.languageProviders.decrement()
                self.languageProvider = self.languageProviders.currentItem!
                self.moveButtonLabels(-self.keyWidth * 2.0)
                UIView.animateWithDuration(0.1) {
                    self.moveButtonLabels(self.keyWidth)
                }
            }
        )
    }
    
    func returnButtonPressed(sender: KeyButton) {
        proxy.insertText("\n")
        updateSuggestions()
    }
    
    // MARK: CharacterButtonDelegate methods
    
    func handlePressForCharacterButton(button: CharacterButton) {
        switch shiftMode {
        case .Off:
            proxy.insertText(button.primaryCharacter.lowercaseString)
        case .On:
            proxy.insertText(button.primaryCharacter.uppercaseString)
            shiftMode = .Off
        case .Caps:
            proxy.insertText(button.primaryCharacter.uppercaseString)
        }
        updateSuggestions()
    }
    
    func handleSwipeUpForButton(button: CharacterButton) {
        proxy.insertText(button.secondaryCharacter)
        if button.secondaryCharacter.characters.count > 1 {
            proxy.insertText(" ")
        }
        updateSuggestions()
    }
    
    func handleSwipeDownForButton(button: CharacterButton) {
        proxy.insertText(button.tertiaryCharacter)
        if button.tertiaryCharacter.characters.count > 1 {
            proxy.insertText(" ")
        }
        updateSuggestions()
    }
    
    // MARK: SuggestionButtonDelegate methods
    
    func handlePressForSuggestionButton(button: SuggestionButton) {
        if let lastWord = lastWordTyped {
            for letter in lastWord.characters {
                proxy.deleteBackward()
            }
            proxy.insertText(button.title + " ")
            for suggestionButton in suggestionButtons {
                suggestionButton.removeFromSuperview()
            }
        }
    }
    
    // MARK: TouchForwardingViewDelegate methods
    
    // TODO: Get this method to properly provide the desired behaviour.
    func viewForHitTestWithPoint(point: CGPoint, event: UIEvent?, superResult: UIView?) -> UIView? {
        for subview in view.subviews {
            let convertPoint = subview.convertPoint(point, fromView: view)
            if subview is KeyButton && subview.pointInside(convertPoint, withEvent: event) {
                return subview
            }
        }
        return swipeView
    }
    
    // MARK: Helper methods
    
    private func initializeKeyboard() {
        for subview in self.view.subviews {
            subview.removeFromSuperview() // Remove all buttons and gesture recognizers when view is recreated during orientation changes.
        }

        addPredictiveTextScrollView()
        addShiftButton()
        addDeleteButton()
        addTabButton()
        addOopButton()
        addNextKeyboardButton()
        addSpaceButton()
        addReturnButton()
        addCharacterButtons()
        addSwipeView()
        addShortWordButton()
        addNumpadButton()
    }
    
    private func addPredictiveTextScrollView() {
        predictiveTextScrollView = PredictiveTextScrollView(frame: CGRectMake(0.0, 0.0, self.view.frame.width, predictiveTextBoxHeight))
        self.view.addSubview(predictiveTextScrollView)
    }
    
    private func addShiftButton() {
        shiftButton = KeyButton(frame: CGRectMake(spacing, keyHeight * 4.0 + spacing * 5.0, keyWidth * 1.5 + spacing * 0.5, keyHeight))
        shiftButton.setTitle("\u{000021E7}", forState: .Normal)
        shiftButton.addTarget(self, action: "shiftButtonPressed:", forControlEvents: .TouchUpInside)
        self.view.addSubview(shiftButton)
    }
    
    private func addDeleteButton() {
        deleteButton = KeyButton(frame: CGRectMake(keyWidth * 8.5 + spacing * 9.5, keyHeight * 4.0 + spacing * 5.0, keyWidth * 1.5, keyHeight))
        deleteButton.setTitle("\u{0000232B}", forState: .Normal)
        deleteButton.addTarget(self, action: "deleteButtonPressed:", forControlEvents: .TouchUpInside)
        self.view.addSubview(deleteButton)
        
        let deleteButtonLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "handleLongPressForDeleteButtonWithGestureRecognizer:")
        deleteButton.addGestureRecognizer(deleteButtonLongPressGestureRecognizer)
        
        let deleteButtonSwipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: "handleSwipeLeftForDeleteButtonWithGestureRecognizer:")
        deleteButtonSwipeLeftGestureRecognizer.direction = .Left
        deleteButton.addGestureRecognizer(deleteButtonSwipeLeftGestureRecognizer)
    }
    
    private func addTabButton() {
        tabButton = KeyButton(frame: CGRectMake(spacing, keyHeight * 5.0 + spacing * 6.0, keyWidth, keyHeight))
        tabButton.setTitle("ñ", forState: .Normal)
        tabButton.addTarget(self, action: "tabButtonPressed:", forControlEvents: .TouchUpInside)
        self.view.addSubview(tabButton)
    }
    
    private func addOopButton() {
        oopButton = KeyButton(frame: CGRectMake(spacing * 2 + keyWidth, keyHeight * 5.0 + spacing * 6.0, keyWidth, keyHeight))
        oopButton.setTitle("ó", forState: .Normal)
        oopButton.addTarget(self, action: "oopButtonPressed:", forControlEvents: .TouchUpInside)
        self.view.addSubview(oopButton)
    }
    
    private func addNextKeyboardButton() {
        nextKeyboardButton = KeyButton(frame: CGRectMake(keyWidth * 2 + spacing * 3, keyHeight * 5.0 + spacing * 6.0, keyWidth, keyHeight))
        nextKeyboardButton.setTitle("\u{0001F310}", forState: .Normal)
        nextKeyboardButton.addTarget(self, action: "advanceToNextInputMode", forControlEvents: .TouchUpInside)
        self.view.addSubview(nextKeyboardButton)
    }
    
    private func addSpaceButton() {
        spaceButton = KeyButton(frame: CGRectMake(keyWidth * 3 + spacing * 4, keyHeight * 5.0 + spacing * 6.0, keyWidth * 4.5 + spacing * 3.5, keyHeight))
        spaceButton.setTitle("Space", forState: .Normal)
        spaceButton.addTarget(self, action: "spaceButtonPressed:", forControlEvents: .TouchUpInside)
        self.view.addSubview(spaceButton)
        
//        currentLanguageLabel = UILabel(frame: CGRectMake(0.0, 0.0, spaceButton.frame.width, spaceButton.frame.height * 0.33))
//        currentLanguageLabel.font = UIFont(name: "HelveticaNeue", size: 12.0)
//        currentLanguageLabel.adjustsFontSizeToFitWidth = true
//        currentLanguageLabel.textColor = UIColor(white: 187.0/255, alpha: 1)
//        currentLanguageLabel.textAlignment = .Center
//        currentLanguageLabel.text = "\(languageProvider.language)"
//        spaceButton.addSubview(currentLanguageLabel)
//        
//        let spaceButtonLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "handleLongPressForSpaceButtonWithGestureRecognizer:")
//        spaceButton.addGestureRecognizer(spaceButtonLongPressGestureRecognizer)
//        
//        let spaceButtonSwipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: "handleSwipeLeftForSpaceButtonWithGestureRecognizer:")
//        spaceButtonSwipeLeftGestureRecognizer.direction = .Left
//        spaceButton.addGestureRecognizer(spaceButtonSwipeLeftGestureRecognizer)
//        
//        let spaceButtonSwipeRightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: "handleSwipeRightForSpaceButtonWithGestureRecognizer:")
//        spaceButtonSwipeRightGestureRecognizer.direction = .Right
//        spaceButton.addGestureRecognizer(spaceButtonSwipeRightGestureRecognizer)
    }
    
    private func addReturnButton() {
        returnButton = KeyButton(frame: CGRectMake(keyWidth * 7.5 + spacing * 8.5, keyHeight * 5.0 + spacing * 6.0, keyWidth * 2.5 + spacing, keyHeight))
        returnButton.setTitle("\u{000023CE}", forState: .Normal)
        returnButton.addTarget(self, action: "returnButtonPressed:", forControlEvents: .TouchUpInside)
        self.view.addSubview(returnButton)
    }
    
    private func addCharacterButtons() {
        characterButtons = [
            [],
            [],
            []
        ] // Clear characterButtons array.
        
        var y = spacing * 3 + keyHeight * 2
        for (rowIndex, row) in primaryCharacters.enumerate() {
            var x: CGFloat
            switch rowIndex {
            case 1:
                x = spacing * 1.5 + keyWidth * 0.5
            case 2:
                x = spacing * 2.5 + keyWidth * 1.5
            default:
                x = spacing
            }
            for (keyIndex, key) in row.enumerate() {
                let characterButton = CharacterButton(frame: CGRectMake(x, y, keyWidth, keyHeight), primaryCharacter: key, secondaryCharacter: " ", tertiaryCharacter: " ", delegate: self)
                self.view.addSubview(characterButton)
                characterButtons[rowIndex].append(characterButton)
                x += keyWidth + spacing
            }
            y += keyHeight + spacing
        }
    }
    
    private func addShortWordButton(){
        for index in 1...7{
            shortWordButton = KeyButton(frame: CGRectMake(spacing * CGFloat(index) + wordKeyWidth * CGFloat(index-1), spacing, wordKeyWidth, keyHeight))
            shortWordButton.setTitle(shortWord[index-1], forState: .Normal)
            shortWordButton.addTarget(self, action: "shortWordButtonPressed:", forControlEvents: .TouchUpInside)
            self.view.addSubview(shortWordButton)
        }
    }
    private func addNumpadButton(){
        for index in 1...10{
            print("\(index) times 5 is \(index * 5)")
            numpadButton = KeyButton(frame: CGRectMake(spacing * CGFloat(index) + keyWidth * CGFloat(index-1), spacing * 2 + keyHeight, keyWidth, keyHeight))
            if index == 10 {
                numpadButton.setTitle("\(index - 10)", forState: .Normal)
                }
            else{
            numpadButton.setTitle("\(index)", forState: .Normal)
            }
            
            numpadButton.addTarget(self, action: "numpadButtonPressed:", forControlEvents: .TouchUpInside)
            self.view.addSubview(numpadButton)
        }
    }
    
    private func addSwipeView() {
        swipeView = SwipeView(containerView: view, topOffset: predictiveTextBoxHeight)
        view.addSubview(swipeView)
    }
    
    private func moveButtonLabels(dx: CGFloat) {
        for (rowIndex, row) in characterButtons.enumerate() {
            for (characterButtonIndex, characterButton) in row.enumerate() {
                characterButton.secondaryLabel.frame.offsetInPlace(dx: dx, dy: 0.0)
                characterButton.tertiaryLabel.frame.offsetInPlace(dx: dx, dy: 0.0)
            }
        }
        currentLanguageLabel.frame.offsetInPlace(dx: dx, dy: 0.0)
    }
    
    private func updateSuggestions() {
        for suggestionButton in suggestionButtons {
            suggestionButton.removeFromSuperview()
        }
        
        if let lastWord = lastWordTyped {
            var x = spacing
            for suggestion in suggestionProvider.suggestionsForPrefix(lastWord) {
                let suggestionButton = SuggestionButton(frame: CGRectMake(x, 0.0, predictiveTextButtonWidth, predictiveTextBoxHeight), title: suggestion, delegate: self)
                predictiveTextScrollView?.addSubview(suggestionButton)
                suggestionButtons.append(suggestionButton)
                x += predictiveTextButtonWidth + spacing
            }
            predictiveTextScrollView!.contentSize = CGSizeMake(x, predictiveTextBoxHeight)
        }
    }
}