//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Kari Kraam on 2016-04-20.
//  Copyright (c) 2016 Kaart Group, LLC. All rights reserved.
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
    
    private let shortWord = ["Calle","Avenida","Callejón","Paseo","Jirón","Pasaje","Peatonal"]
    
    lazy var suggestionProvider: SuggestionProvider = SuggestionTrie()
    
    lazy var languageProviders = CircularArray(items: [DefaultLanguageProvider(), SwiftLanguageProvider()] as [LanguageProvider])
    
    private let spacing: CGFloat = 4.0
    private let predictiveTextBoxHeight: CGFloat = 24.0
    private var predictiveTextButtonWidth: CGFloat {
        return (view.frame.width - 4 * spacing) / 3.0
    }
    private var keyboardHeight: CGFloat {
        if(UIScreen.mainScreen().bounds.width < UIScreen.mainScreen().bounds.height ){
            return 400
        }
        else{
            return 370
        }
    }
    
    // Width of individual letter keys
    private var keyWidth: CGFloat {
        return (view.frame.width - 11 * spacing) / 10.0
    }
    
    // Width of individual short word keys
    private var wordKeyWidth: CGFloat {
        return (view.frame.width - 8 * spacing) / 7.0
    }
    
    //Height of individual keys
    private var keyHeight: CGFloat {
        return (keyboardHeight - 6.5 * spacing - predictiveTextBoxHeight) / 6.0
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
    private var nextKeyboardButton: UIButton!
    private var spaceButton: KeyButton!
    private var returnButton: KeyButton!
    private var currentLanguageLabel: UILabel!
    private var oopButton: KeyButton!
    private var nnpButton: KeyButton!
    
    // Number Buttons
    private var numpadButton: KeyButton!
    private var arrayOfNumberButton: [KeyButton] = []
    
    // Short Word Buttons
    private var shortWordButton: KeyButton!
    private var arrayOfShortWordButton: [KeyButton] = []
    
    private var dotButton: KeyButton!
    private var eepButton: KeyButton!
    private var iipButton: KeyButton!
    private var uupButton: KeyButton!
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
    
    private var shiftMode: ShiftMode = .On {
        didSet {
            shiftButton.selected = (shiftMode == .Caps)
            for row in characterButtons {
                for characterButton in row {
                    switch shiftMode {
                    case .Off:
                        characterButton.primaryLabel.text = characterButton.primaryCharacter.lowercaseString
                        tabButton.setTitle("á", forState: .Normal)
                        eepButton.setTitle("é", forState: .Normal)
                        iipButton.setTitle("í", forState: .Normal)
                        uupButton.setTitle("ú", forState: .Normal)
                        nnpButton.setTitle("ń", forState: .Normal)
                        oopButton.setTitle("ó", forState: .Normal)
//                        characterButton.secondaryLabel.text = " "
//                        characterButton.tertiaryLabel.text = " "
                    case .On, .Caps:
                        characterButton.primaryLabel.text = characterButton.primaryCharacter.uppercaseString
                        tabButton.setTitle("Á", forState: .Normal)
                        eepButton.setTitle("É", forState: .Normal)
                        iipButton.setTitle("Í", forState: .Normal)
                        uupButton.setTitle("Ú", forState: .Normal)
                        nnpButton.setTitle("Ń", forState: .Normal)
                        oopButton.setTitle("Ó", forState: .Normal)
//                        characterButton.secondaryLabel.text = " "
//                        characterButton.tertiaryLabel.text = " "
                    }
                
                }
            }
        }
    }
    
    //@IBOutlet var nextKeyboardButton: UIButton!
    //var heightConstraint: NSLayoutConstraint!
    var nextKeyboardButtonLeftSideConstraint: NSLayoutConstraint!
    
    func updateConstraintForCharacter()
    {
        let firstNumberBtn:KeyButton = arrayOfNumberButton[0];
        
        var y = spacing * 3 + keyHeight * 2
        for (rowIndex, row) in characterButtons.enumerate()
        {
            var x: CGFloat
            switch rowIndex {
            case 1:
                x = spacing * 1.5 + keyWidth * 0.5
            case 2:
                x = spacing * 2.5 + keyWidth * 1.5
            default:
                x = spacing
            }
            
            for (buttonIndex, key) in row.enumerate()
            {
                let characterButton = key
                removeAllConstrains(characterButton);
                
                if( rowIndex == 0  )
                {
                    if(  buttonIndex == 0)
                    {
                        //First Row First Btn "Q"
                        
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .Top, relatedBy: .Equal, toItem: firstNumberBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1.0, constant: x );
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false
                        topCons.active = true;
                        leftCons.active = true;
                        heightCons.active = true;
                        widthCons.active = true;
                        
                    }
                    else
                    {
                        let previosBtn = characterButtons[rowIndex][buttonIndex-1];
                        
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .Top, relatedBy: .Equal, toItem: firstNumberBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .Leading, relatedBy: .Equal, toItem: previosBtn, attribute: .Trailing, multiplier: 1.0, constant: spacing );
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false;
                        topCons.active = true;
                        leftCons.active = true;
                        heightCons.active = true;
                        widthCons.active = true;
                    }
                }
                else if( rowIndex == 1)
                {
                    let QCharBtn:CharacterButton = characterButtons[0][0];
                    
                    // Second Character Row "A"
                    if(  buttonIndex == 0)
                    {
                        //First Row First Btn "A"
                        
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .Top, relatedBy: .Equal, toItem: QCharBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1.0, constant: x );
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false
                        topCons.active = true;
                        leftCons.active = true;
                        heightCons.active = true;
                        widthCons.active = true;
                        
                    }
                    else
                    {
                        let previosBtn = characterButtons[rowIndex][buttonIndex-1];
                        
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .Top, relatedBy: .Equal, toItem: QCharBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .Leading, relatedBy: .Equal, toItem: previosBtn, attribute: .Trailing, multiplier: 1.0, constant: spacing );
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false;
                        topCons.active = true;
                        leftCons.active = true;
                        heightCons.active = true;
                        widthCons.active = true;
                        
//                        if( buttonIndex == 8)
//                        {
//                            removeAllConstrains(dotButton);
//                            // Add . BUtton Constraints
//                            let topCons = NSLayoutConstraint(item: dotButton, attribute: .Top, relatedBy: .Equal, toItem: QCharBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing);
//                            
//                            let rightCons = NSLayoutConstraint(item: dotButton, attribute: .Trailing, relatedBy: .Equal, toItem: view, attribute: .Trailing, multiplier: 1.0, constant: -spacing );
//                            
//                            let heightCons = NSLayoutConstraint(item: dotButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
//                            
//                            let leftCons = NSLayoutConstraint(item: dotButton, attribute: .Leading, relatedBy: .Equal, toItem: characterButton, attribute: .Trailing, multiplier: 1.0, constant: spacing)
//                            
//                            dotButton.translatesAutoresizingMaskIntoConstraints = false;
//                            topCons.active = true;
//                            leftCons.active = true;
//                            heightCons.active = true;
//                            rightCons.active = true;
//                        }
                        
                        //dotButton = KeyButton(frame: CGRectMake(spacing * 10.5 + keyWidth * 9.5, spacing * 4 + keyHeight * 3, keyWidth / 2 - spacing / 2, keyHeight))
                    }
                    
                }
                else
                {
                    let ACharBtn:CharacterButton = characterButtons[1][0];
                    
                    // Last Chracter Row "Z"
                    if(  buttonIndex == 0)
                    {
                        //First Row First Btn "A"
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .Top, relatedBy: .Equal, toItem: ACharBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing)
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1.0, constant: keyWidth + spacing * 2)
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false
                        topCons.active = true;
                        leftCons.active = true;
                        heightCons.active = true;
                        widthCons.active = true;
                        
                        
                        //Add Constraints for shift Button
                        removeAllConstrains(shiftButton);
                        
                        let topConsShiftBtn = NSLayoutConstraint(item: shiftButton, attribute: .Top, relatedBy: .Equal, toItem: ACharBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftConsShiftBtn = NSLayoutConstraint(item: shiftButton, attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1.0, constant: spacing );
                        
                        let heightConsShiftBtn = NSLayoutConstraint(item: shiftButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthConsShiftBtn = NSLayoutConstraint(item: shiftButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        shiftButton.translatesAutoresizingMaskIntoConstraints = false
                        topConsShiftBtn.active = true;
                        leftConsShiftBtn.active = true;
                        heightConsShiftBtn.active = true;
                        widthConsShiftBtn.active = true;
                        
                    }
                    else
                    {
                        let previosBtn = characterButtons[rowIndex][buttonIndex-1];
                        
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .Top, relatedBy: .Equal, toItem: ACharBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .Leading, relatedBy: .Equal, toItem: previosBtn, attribute: .Trailing, multiplier: 1.0, constant: spacing );
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false;
                        topCons.active = true;
                        leftCons.active = true;
                        heightCons.active = true;
                        widthCons.active = true;
                        
                        // Constraints for Dot Button
                        if( buttonIndex == 6)
                        {
                            removeAllConstrains(dotButton);
                            // Add Dot Button Constraints
                            let topCons = NSLayoutConstraint(item: dotButton, attribute: .Top, relatedBy: .Equal, toItem: ACharBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing)
                            
//                            let rightCons = NSLayoutConstraint(item: dotButton, attribute: .Trailing, relatedBy: .Equal, toItem: deleteButton, attribute: .Trailing, multiplier: 1.0, constant: spacing)
                            
                            let widthCons = NSLayoutConstraint(item: dotButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
                            
                            let heightCons = NSLayoutConstraint(item: dotButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
                            
                            let leftCons = NSLayoutConstraint(item: dotButton, attribute: .Leading, relatedBy: .Equal, toItem: characterButton, attribute: .Trailing, multiplier: 1.0, constant: spacing)
                            
                            dotButton.translatesAutoresizingMaskIntoConstraints = false;
                            topCons.active = true;
                            leftCons.active = true;
                            heightCons.active = true;
                            widthCons.active = true;
//                            rightCons.active = true;
                        }

                        // Constraints for Delete Button
//                        if(  buttonIndex == 7 )
//                        {
                            // Add Constraint for Delete Button
                            removeAllConstrains(deleteButton);
                            
                            let topConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .Top, relatedBy: .Equal, toItem: ACharBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing);
                            
                            let leftConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .Leading, relatedBy: .Equal, toItem: dotButton, attribute: .Trailing, multiplier: 1.0, constant: spacing );
                            
                            let heightConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
                            
                            let rightConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .Trailing, relatedBy: .Equal, toItem: view, attribute: .Trailing, multiplier: 1.0, constant: -spacing)
                            
                            deleteButton.translatesAutoresizingMaskIntoConstraints = false
                            topConsShiftBtn.active = true;
                            leftConsShiftBtn.active = true;
                            heightConsShiftBtn.active = true;
                            rightConsShiftBtn.active = true;
//                        }
                    }
                    
                }
                //self.view.addSubview(characterButton)
                //characterButtons[rowIndex].append(characterButton)
                x += keyWidth + spacing
            }
            y += keyHeight + spacing
        }
    }
    
    func updateConstraintForSpeceRow()
    {
        // Add Constraints for tabButton
        removeAllConstrains(tabButton);
        
        let topConsTabButton = NSLayoutConstraint(item: tabButton, attribute: .Top, relatedBy: .Equal, toItem: shiftButton, attribute: .Bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsTabButton = NSLayoutConstraint(item: tabButton, attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1.0, constant: spacing );
        
        let heightConsTabButton = NSLayoutConstraint(item: tabButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsTabButton = NSLayoutConstraint(item: tabButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        tabButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsTabButton.active = true
        leftConsTabButton.active = true
        heightConsTabButton.active = true
        widthConsTabButton.active = true
        
        // Add Constraints for eepButton
        removeAllConstrains(eepButton);
        
        let topConsEEPButton = NSLayoutConstraint(item: eepButton, attribute: .Top, relatedBy: .Equal, toItem: shiftButton, attribute: .Bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsEEPButton = NSLayoutConstraint(item: eepButton, attribute: .Leading, relatedBy: .Equal, toItem: tabButton, attribute: .Trailing, multiplier: 1.0, constant: spacing );
        
        let heightConsEEPButton = NSLayoutConstraint(item: eepButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsEEPButton = NSLayoutConstraint(item: eepButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        eepButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsEEPButton.active = true
        leftConsEEPButton.active = true
        heightConsEEPButton.active = true
        widthConsEEPButton.active = true
        
        // Add Constraints for iipButton
        removeAllConstrains(iipButton);
        
        let topConsIIPButton = NSLayoutConstraint(item: iipButton, attribute: .Top, relatedBy: .Equal, toItem: shiftButton, attribute: .Bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsIIPButton = NSLayoutConstraint(item: iipButton, attribute: .Leading, relatedBy: .Equal, toItem: eepButton, attribute: .Trailing, multiplier: 1.0, constant: spacing );
        
        let heightConsIIPButton = NSLayoutConstraint(item: iipButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsIIPButton = NSLayoutConstraint(item: iipButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        iipButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsIIPButton.active = true
        leftConsIIPButton.active = true
        heightConsIIPButton.active = true
        widthConsIIPButton.active = true
        
        // Add Constraints for iipButton
        removeAllConstrains(uupButton);
        
        let topConsUUPButton = NSLayoutConstraint(item: uupButton, attribute: .Top, relatedBy: .Equal, toItem: shiftButton, attribute: .Bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsUUPButton = NSLayoutConstraint(item: uupButton, attribute: .Leading, relatedBy: .Equal, toItem: iipButton, attribute: .Trailing, multiplier: 1.0, constant: spacing );
        
        let heightConsUUPButton = NSLayoutConstraint(item: uupButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsUUPButton = NSLayoutConstraint(item: uupButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        uupButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsUUPButton.active = true
        leftConsUUPButton.active = true
        heightConsUUPButton.active = true
        widthConsUUPButton.active = true

        // Add Constraints for oopButton
        removeAllConstrains(oopButton);
        
        let topConsOOPButton = NSLayoutConstraint(item: oopButton, attribute: .Top, relatedBy: .Equal, toItem: shiftButton, attribute: .Bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsOOPButton = NSLayoutConstraint(item: oopButton, attribute: .Leading, relatedBy: .Equal, toItem: nnpButton, attribute: .Trailing, multiplier: 1.0, constant: spacing);
        
        let heightConsOOPButton = NSLayoutConstraint(item: oopButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsOOPButton = NSLayoutConstraint(item: oopButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        oopButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsOOPButton.active = true
        leftConsOOPButton.active = true
        heightConsOOPButton.active = true
        widthConsOOPButton.active = true
        
        //Add Constraints for nnpButton
        removeAllConstrains(nnpButton)
        
        let topConsNNPButton = NSLayoutConstraint(item: nnpButton, attribute: .Top, relatedBy: .Equal, toItem: shiftButton, attribute: .Bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsNNPButton = NSLayoutConstraint(item: nnpButton, attribute: .Leading, relatedBy: .Equal, toItem: spaceButton, attribute: .Trailing, multiplier: 1.0, constant: spacing);
        
        let heightConsNNPButton = NSLayoutConstraint(item: nnpButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsNNPButton = NSLayoutConstraint(item: nnpButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        nnpButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsNNPButton.active = true
        leftConsNNPButton.active = true
        heightConsNNPButton.active = true
        widthConsNNPButton.active = true
        
        // Add Constraints for Space Button
        removeAllConstrains(spaceButton);
        
        let topConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .Top, relatedBy: .Equal, toItem: shiftButton, attribute: .Bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .Leading, relatedBy: .Equal, toItem: uupButton, attribute: .Trailing, multiplier: 1.0, constant: spacing );
        
        let heightConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth * 2)
        
        spaceButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsSpeceButton.active = true
        leftConsSpeceButton.active = true
        heightConsSpeceButton.active = true
        widthConsSpeceButton.active = true
        
        // Add Constraints for Return Button
        removeAllConstrains(returnButton);
        
        let topConsReturnButton = NSLayoutConstraint(item: returnButton, attribute: .Top, relatedBy: .Equal, toItem: shiftButton, attribute: .Bottom, multiplier: 1.0, constant: spacing);
        
        let rightConsReturnButton = NSLayoutConstraint(item: returnButton, attribute: .Trailing, relatedBy: .Equal, toItem: view, attribute: .Trailing, multiplier: 1.0, constant: -spacing );
        
        let heightConsReturnButton = NSLayoutConstraint(item: returnButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsReturnButton = NSLayoutConstraint(item: returnButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth * 1.5 )
        
        returnButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsReturnButton.active = true
        rightConsReturnButton.active = true
        heightConsReturnButton.active = true
        widthConsReturnButton.active = true
    }
    
    func removeAllConstrains(inputView:UIView)
    {
        for cons in inputView.constraints{
            inputView.removeConstraint(cons);
        }
    }
    func updateConstraintForNumberButton()
    {
        let firstButton = arrayOfNumberButton[0];
        let shortWordBtn:KeyButton = arrayOfShortWordButton[0];
        
        for cons in firstButton.constraints{
            firstButton.removeConstraint(cons);
        }
        
        let topCons = NSLayoutConstraint(item: firstButton, attribute: .Top, relatedBy: .Equal, toItem: shortWordBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing);
        
        let leftCons = NSLayoutConstraint(item: firstButton, attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1.0, constant: spacing );
        
        let heightCons = NSLayoutConstraint(item: firstButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthCons = NSLayoutConstraint(item: firstButton, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        firstButton.translatesAutoresizingMaskIntoConstraints = false
        topCons.active = true;
        leftCons.active = true;
        heightCons.active = true;
        widthCons.active = true;
        
        for  i in 1..<arrayOfNumberButton.count
        {
            let previosBtn = arrayOfNumberButton[i-1]
            let shortWordButtonObj = arrayOfNumberButton[i];
            
            for cons in shortWordButtonObj.constraints{
                shortWordButtonObj.removeConstraint(cons);
            }
            
            let topCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .Top, relatedBy: .Equal, toItem: shortWordBtn, attribute: .Bottom, multiplier: 1.0, constant: spacing );
            
            let leftCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .Leading, relatedBy: .Equal, toItem: previosBtn, attribute: .Trailing, multiplier: 1.0, constant: spacing );
            
            let heightCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
            
            let widthCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyWidth)
            
            shortWordButtonObj.translatesAutoresizingMaskIntoConstraints = false;
            topCons.active = true;
            leftCons.active = true;
            heightCons.active = true;
            widthCons.active = true;
        }
        
        //numpadButton = KeyButton(frame: CGRectMake(spacing * CGFloat(index) + keyWidth * CGFloat(index-1), spacing + keyHeight, keyWidth, keyHeight))
    }
    
    func updateConstraintForShortWorld()
    {
        for cons in arrayOfShortWordButton[0].constraints{
            arrayOfShortWordButton[0].removeConstraint(cons);
        }
        
        let topCons = NSLayoutConstraint(item: arrayOfShortWordButton[0], attribute: .Top, relatedBy: .Equal, toItem: view, attribute: .Top, multiplier: 1.0, constant: 40 + spacing);
        
        let leftCons = NSLayoutConstraint(item: arrayOfShortWordButton[0], attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1.0, constant: spacing );
        
        let heightCons = NSLayoutConstraint(item: arrayOfShortWordButton[0], attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthCons = NSLayoutConstraint(item: arrayOfShortWordButton[0], attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: wordKeyWidth)
        
        arrayOfShortWordButton[0].translatesAutoresizingMaskIntoConstraints = false
        topCons.active = true;
        leftCons.active = true;
        heightCons.active = true;
        widthCons.active = true;
        
        for  i in 1..<arrayOfShortWordButton.count
        {
            let previosBtn = arrayOfShortWordButton[i-1]
            let shortWordButtonObj = arrayOfShortWordButton[i];
            
            for cons in shortWordButtonObj.constraints{
                shortWordButtonObj.removeConstraint(cons);
            }
            
            let topCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .Top, relatedBy: .Equal, toItem: view, attribute: .Top, multiplier: 1.0, constant:  40 + spacing);
            
            let leftCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .Leading, relatedBy: .Equal, toItem: previosBtn, attribute: .Trailing, multiplier: 1.0, constant: spacing );
            
            let heightCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: keyHeight)
            
            let widthCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: wordKeyWidth)
            
            shortWordButtonObj.translatesAutoresizingMaskIntoConstraints = false;
            topCons.active = true;
            leftCons.active = true;
            heightCons.active = true;
            widthCons.active = true;
        }
    }
    
    func updateConstraintForPredictiveText()
    {
        
        // Add Constraints for Return Button
        removeAllConstrains(predictiveTextScrollView);
        
        let topCons = NSLayoutConstraint(item: predictiveTextScrollView, attribute: .Top, relatedBy: .Equal, toItem: view, attribute: .Top, multiplier: 1.0, constant: spacing);
        
        let rightCons = NSLayoutConstraint(item: predictiveTextScrollView, attribute: .Trailing, relatedBy: .Equal, toItem: view, attribute: .Trailing, multiplier: 1.0, constant: -spacing );
        
        let heightCons = NSLayoutConstraint(item: predictiveTextScrollView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: 30)
        
        let leftCons = NSLayoutConstraint(item: predictiveTextScrollView, attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1.0, constant: spacing )
        
        predictiveTextScrollView.translatesAutoresizingMaskIntoConstraints = false;
        //predictiveTextScrollView.backgroundColor = UIColor.redColor()
        topCons.active = true
        rightCons.active = true
        heightCons.active = true
        leftCons.active = true
    }
    override func updateViewConstraints()
    {
        super.updateViewConstraints()
        
        // Add custom view sizing constraints here
        if (view.frame.size.width == 0 || view.frame.size.height == 0) {
           return
        }
        
        updateConstraintForShortWorld();
        updateConstraintForNumberButton()
        updateConstraintForCharacter()
        updateConstraintForSpeceRow()
        updateConstraintForPredictiveText()
        setUpHeightConstraint()
    }
    
    var lexicon:UILexicon!;
    let currentString:NSString = "";
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        addNextKeyboardButton();
        addShortWordButton()
        addNumpadButton()
        addCharacterButtons()
        addDotButton();
        addShiftButton();
        addDeleteButton()
        addAapButton()
        addEepButton()
        addIipButton()
        addUupButton()
        addOopButton()
        addNnpButton()
        addSpaceButton()
        addReturnButton()
        addPredictiveTextScrollView()
        
        self.requestSupplementaryLexiconWithCompletion { (lexObj) in
            self.lexicon = lexObj;
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        removeAllConstrains(nextKeyboardButton);
        
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        nextKeyboardButtonLeftSideConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .Leading,
            relatedBy: .Equal,
            toItem: oopButton,
            attribute: .Trailing,
            multiplier: 1.0,
            constant: spacing)
        
        let nextKeyboardButtonRightSideConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .Trailing,
            relatedBy: .Equal,
            toItem: returnButton,
            attribute: .Leading,
            multiplier: 1.0,
            constant: -spacing)
        
        let nextKeyboardButtonBottomConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .Top,
            relatedBy: .Equal,
            toItem: spaceButton,
            attribute: .Top,
            multiplier: 1.0,
            constant: 0)
        
        let nextKeyboardButtonHeightConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .Height,
            relatedBy: .Equal,
            toItem: nil,
            attribute: .NotAnAttribute,
            multiplier: 1.0,
            constant: keyHeight)
        
        view.addConstraints([
            nextKeyboardButtonLeftSideConstraint,
            nextKeyboardButtonBottomConstraint,nextKeyboardButtonRightSideConstraint,nextKeyboardButtonHeightConstraint])
        
        // Set up constraints for next keyboard button in view did appear
//        if nextKeyboardButtonLeftSideConstraint == nil {
//            nextKeyboardButtonLeftSideConstraint = NSLayoutConstraint(
//                item: nextKeyboardButton,
//                attribute: .Leading,
//                relatedBy: .Equal,
//                toItem: spaceButton,
//                attribute: .Trailing,
//                multiplier: 1.0,
//                constant: spacing)
//            
//            let nextKeyboardButtonBottomConstraint = NSLayoutConstraint(
//                item: nextKeyboardButton,
//                attribute: .Top,
//                relatedBy: .Equal,
//                toItem: spaceButton,
//                attribute: .Bottom,
//                multiplier: 1.0,
//                constant: spacing)
//            
//            view.addConstraints([
//                nextKeyboardButtonLeftSideConstraint,
//                nextKeyboardButtonBottomConstraint])
//        }
    }
        
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        //shiftMode = .On
        
        addCharacterButtons()
       setUpHeightConstraint()
    }
    
    func setUpHeightConstraint()
    {
        let iOrientation:UIInterfaceOrientation = self.interfaceOrientation;
        
        var customHeight = UIScreen.mainScreen().bounds.height / 2 ;
        if( iOrientation == .Portrait || iOrientation == .PortraitUpsideDown  )
        {
            customHeight = UIScreen.mainScreen().bounds.height / 2 - 90;
        }
        else if( iOrientation == .LandscapeLeft || iOrientation == .LandscapeRight  )
        {
            customHeight = UIScreen.mainScreen().bounds.height / 2 + 10;
        }
        else{
            return;
        }
        
        
        
        if heightConstraint == nil {
            heightConstraint = NSLayoutConstraint(item: view,
                                                  attribute: .Height,
                                                  relatedBy: .Equal,
                                                  toItem: nil,
                                                  attribute: .NotAnAttribute,
                                                  multiplier: 1,
                                                  constant: customHeight)
            heightConstraint.priority = UILayoutPriority(UILayoutPriorityRequired)
            
            view.addConstraint(heightConstraint)
        }
        else {
            heightConstraint.constant = customHeight
        }
    }
    
//    override func updateViewConstraints() {
//        super.updateViewConstraints()
//        view.removeConstraint(heightConstraint)
//        heightConstraint.constant = keyboardHeight
//        view.addConstraint(heightConstraint)
//    }
    
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
//        switch proxy.documentContextBeforeInput {
//        case let s where s?.hasSuffix("    ") == true: // Cursor in front of tab, so delete tab.
//            for _ in 0..<4 { // TODO: Update to use tab setting.
//                proxy.deleteBackward()
//            }
//        default:
            proxy.deleteBackward()
//        }
        updateSuggestions()
    }
    
    var longPressStoped:Bool = false;
    
    func startMoreDelete(timer: NSTimer)
    {
        while true {
            
            if( longPressStoped )
            {
                break;
            }
            
            //proxy.deleteBackward();
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
                    
                    if( charactersToDelete == 0)
                    {
                        break;
                    }
                    for _ in 0..<charactersToDelete {
                        proxy.deleteBackward()
                    }
                    
                    //sleep(1)
                }
            }
            else
            {
                break;
            }
            
            timer.invalidate();
            var longPressTime = NSTimer(timeInterval: 0.2, target: self, selector: #selector(KeyboardViewController.startMoreDelete(_:)), userInfo: nil, repeats: false);
            
            NSRunLoop.mainRunLoop().addTimer(longPressTime, forMode: NSDefaultRunLoopMode)
            break
        }
        
        timer.invalidate();
        longPressStoped = false;
    }
    
    func handleDeleteButtonLongPress(timer: NSTimer) {
        
        timer.invalidate();
        //timer = nil
        
        deleteButtonTimer?.invalidate()
        deleteButtonTimer = nil
        
        var longPressTime = NSTimer(timeInterval: 0.3, target: self, selector: #selector(KeyboardViewController.startMoreDelete(_:)), userInfo: nil, repeats: false);
        
        NSRunLoop.mainRunLoop().addTimer(longPressTime, forMode: NSDefaultRunLoopMode)
    }
    
    //Delete Button long press action
    func handleLongPressForDeleteButtonWithGestureRecognizer(gestureRecognizer: UILongPressGestureRecognizer) {
       
        
        switch gestureRecognizer.state {
            
        case .Began:
            
            longPressStoped = false;
            if deleteButtonTimer == nil {
                deleteButtonTimer = NSTimer(timeInterval: 0.1, target: self, selector: #selector(KeyboardViewController.handleDeleteButtonTimerTick(_:)), userInfo: nil, repeats: true)
                deleteButtonTimer!.tolerance = 0.01
                NSRunLoop.mainRunLoop().addTimer(deleteButtonTimer!, forMode: NSDefaultRunLoopMode)
                
                var longPressTime = NSTimer(timeInterval: 0.4, target: self, selector: #selector(KeyboardViewController.handleDeleteButtonLongPress(_:)), userInfo: nil, repeats: false);
                
                NSRunLoop.mainRunLoop().addTimer(longPressTime, forMode: NSDefaultRunLoopMode)
            }
        
        default:
            
            deleteButtonTimer?.invalidate()
            deleteButtonTimer = nil
            longPressStoped = true;
            //updateSuggestions()
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
                
                for _ in 0..<charactersToDelete {
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
        shiftMode = .On
        proxy.insertText(" ")
        updateSuggestions()
    }
    
    // Input the character "ñ" instead of tab
    func aapButtonPressed(sender: KeyButton) {
        proxy.insertText(sender.currentTitle!)
        shiftMode = .Off
    }
    
    func eepButtonPressed(sender: KeyButton){
        proxy.insertText(sender.currentTitle!)
        shiftMode = .Off
        }
    
    func iipButtonPressed(sender: KeyButton){
        proxy.insertText(sender.currentTitle!)
        shiftMode = .Off
    }
    
    func uupButtonPressed(sender: KeyButton){
        proxy.insertText(sender.currentTitle!)
        shiftMode = .Off
    }
    
    // Input the character ""
    func oopButtonPressed(sender: KeyButton) {
        proxy.insertText(sender.currentTitle!)
        shiftMode = .Off
    }
    
    func nnpButtonPressed(sender: KeyButton) {
        proxy.insertText(sender.currentTitle!)
        shiftMode = .Off
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
    
    // When the dotButton is pressed
    func dotButtonPressed(sender: KeyButton){
        proxy.insertText(".")
    }
    

    
    func handleLongPressForSpaceButtonWithGestureRecognizer(gestureRecognizer: UISwipeGestureRecognizer) {
        switch gestureRecognizer.state {
        case .Began:
            if spaceButtonTimer == nil {
                spaceButtonTimer = NSTimer(timeInterval: 0.1, target: self, selector: #selector(KeyboardViewController.handleSpaceButtonTimerTick(_:)), userInfo: nil, repeats: true)
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
        shiftMode = .On
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
            for _ in lastWord.characters {
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
        addAapButton()
        addUupButton()
        addOopButton()
        addNextKeyboardButton()
        addSpaceButton()
        addReturnButton()
        addCharacterButtons()
        addSwipeView()
        addShortWordButton()
        addNumpadButton()
        addDotButton()
        addEepButton()
        addIipButton()
        addNnpButton()
    }
    
    private func addPredictiveTextScrollView() {
        predictiveTextScrollView = PredictiveTextScrollView(frame: CGRectMake(0.0, 0.0, self.view.frame.width, predictiveTextBoxHeight))
        self.view.addSubview(predictiveTextScrollView)
    }
    
    private func addShiftButton() {
        shiftButton = KeyButton(frame: CGRectMake(spacing, keyHeight * 4.0 + spacing * 5.0, keyWidth, keyHeight))
        shiftButton.setTitle("\u{000021E7}", forState: .Normal)
        shiftButton.addTarget(self, action: #selector(KeyboardViewController.shiftButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(shiftButton)
    }
    
    private func addDeleteButton() {
        deleteButton = KeyButton(frame: CGRectMake(keyWidth * 8.5 + spacing * 9.5, keyHeight * 4.0 + spacing * 5.0, keyWidth * 1.5 + spacing / 2, keyHeight))
        deleteButton.setTitle("\u{0000232B}", forState: .Normal)
        deleteButton.addTarget(self, action: #selector(KeyboardViewController.deleteButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(deleteButton)
        
        let deleteButtonLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(KeyboardViewController.handleLongPressForDeleteButtonWithGestureRecognizer(_:)))
        deleteButton.addGestureRecognizer(deleteButtonLongPressGestureRecognizer)
        
//        let deleteButtonSwipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(KeyboardViewController.handleSwipeLeftForDeleteButtonWithGestureRecognizer(_:)))
//        deleteButtonSwipeLeftGestureRecognizer.direction = .Left
//        deleteButton.addGestureRecognizer(deleteButtonSwipeLeftGestureRecognizer)
    }
    
    private func addAapButton() {
        tabButton = KeyButton(frame: CGRectMake(spacing, keyHeight * 5.0 + spacing * 6.0, keyWidth, keyHeight))
        tabButton.setTitle("Á", forState: .Normal)
        tabButton.addTarget(self, action: #selector(KeyboardViewController.aapButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(tabButton)
    }
    
    private func addEepButton() {
        eepButton = KeyButton(frame: CGRectMake(spacing * 2 + keyWidth, keyHeight * 5.0 + spacing * 6.0, keyWidth, keyHeight))
        eepButton.setTitle("É", forState: .Normal)
        eepButton.addTarget(self, action: #selector(KeyboardViewController.eepButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(eepButton)
    }
    
    private func addDotButton()
    {
        dotButton = KeyButton(frame: CGRectMake(spacing * 10.5 + keyWidth * 9.5, spacing * 4 + keyHeight * 3, keyWidth / 2 - spacing / 2, keyHeight))
        dotButton.setTitle(".", forState: .Normal)
        dotButton.addTarget(self, action: #selector(KeyboardViewController.dotButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(dotButton)
    }
    
    private func addIipButton() {
        iipButton = KeyButton(frame: CGRectMake(keyWidth * 2 + spacing * 3, keyHeight * 5.0 + spacing * 6.0, keyWidth, keyHeight))
        iipButton.setTitle("Í", forState: .Normal)
        iipButton.addTarget(self, action: #selector(KeyboardViewController.iipButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(iipButton)
    }
    
    private func addUupButton() {
        uupButton = KeyButton(frame: CGRectMake(keyWidth * 3 + spacing * 4, keyHeight * 5.0 + spacing * 6.0, keyWidth, keyHeight))
        uupButton.setTitle("Ú", forState: .Normal)
        uupButton.addTarget(self, action: #selector(KeyboardViewController.uupButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(uupButton)
    }
    
    private func addOopButton() {
        oopButton = KeyButton(frame: CGRectMake(keyWidth * 4 + spacing * 5, keyHeight * 5.0 + spacing * 6.0, keyWidth, keyHeight))
        oopButton.setTitle("Ó", forState: .Normal)
        oopButton.addTarget(self, action: #selector(KeyboardViewController.oopButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(oopButton)
    }
 
    private func addNnpButton() {
        nnpButton = KeyButton(frame: CGRectMake(keyWidth * 4 + spacing * 5, keyHeight * 5.0 + spacing * 6.0, keyWidth, keyHeight))
        nnpButton.setTitle("Ń", forState: .Normal)
        nnpButton.addTarget(self, action: #selector(KeyboardViewController.nnpButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(nnpButton)
    }
   
    private func addNextKeyboardButton() {
        nextKeyboardButton = KeyButton(frame: CGRectMake(keyWidth * 7.5 + spacing * 8.5, keyHeight * 5.0 + spacing * 6.0, keyWidth / 2, keyHeight))
        nextKeyboardButton.setTitle("\u{0001F310}", forState: .Normal)
        nextKeyboardButton.addTarget(self, action: #selector(UIInputViewController.advanceToNextInputMode), forControlEvents: .TouchUpInside)
        self.view.addSubview(nextKeyboardButton)
    }
    
    private func addSpaceButton() {
        spaceButton = KeyButton(frame: CGRectMake(keyWidth * 5 + spacing * 6, keyHeight * 5.0 + spacing * 6.0, keyWidth * 2.5 + spacing * 1.5, keyHeight))
        spaceButton.setTitle("Space", forState: .Normal)
        spaceButton.addTarget(self, action: #selector(KeyboardViewController.spaceButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(spaceButton)

    }
    
    private func addReturnButton() {
        returnButton = KeyButton(frame: CGRectMake(keyWidth * 8.5 + spacing * 9.5, keyHeight * 5.0 + spacing * 6.0, keyWidth * 1.5 + spacing / 2, keyHeight))
        returnButton.setTitle("\u{000023CE}", forState: .Normal)
        returnButton.addTarget(self, action: #selector(KeyboardViewController.returnButtonPressed(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(returnButton)
    }
    
    private func addCharacterButtons() {
        
        
        for (rowIndex, row) in characterButtons.enumerate() {
            
            for (_, key) in row.enumerate() {
                let characterBtn:CharacterButton = key
                characterBtn.removeFromSuperview()
            }
        }
        
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
            for (_, key) in row.enumerate() {
                let characterButton = CharacterButton(frame: CGRectMake(x, y, keyWidth, keyHeight), primaryCharacter: key.uppercaseString, secondaryCharacter: " ", tertiaryCharacter: " ", delegate: self)
                self.view.addSubview(characterButton)
                characterButtons[rowIndex].append(characterButton)
                x += keyWidth + spacing
            }
            y += keyHeight + spacing
        }
    }
    
    private func addShortWordButton(){
        for index in 1...7{
            shortWordButton = KeyButton(frame: CGRectMake(spacing * CGFloat(index) + wordKeyWidth * CGFloat(index-1), 0.0, wordKeyWidth, keyHeight))
            shortWordButton.setTitle(shortWord[index-1], forState: .Normal)
            shortWordButton.setTitleColor(UIColor(white: 245.0/245, alpha: 1.0), forState: UIControlState.Normal)
            let gradient = CAGradientLayer()
            gradient.frame = self.shortWordButton.bounds
            let gradientColors: [AnyObject] = [UIColor(red: 70.0/255, green: 70.0/255, blue: 70.0/255, alpha: 40.0).CGColor, UIColor(red: 60.0/255, green: 60.0/255, blue: 60.0/255, alpha: 1.0).CGColor]
            gradient.colors = gradientColors // Declaration broken into two lines to prevent 'unable to bridge to Objective C' error.
            
            shortWordButton.setBackgroundImage(UIImage.fromColor(UIColor(red: 122.0/255, green: 122.0/255, blue: 122.0/255, alpha: 1.0)), forState: .Normal)
            shortWordButton.setBackgroundImage(UIImage.fromColor(UIColor.blackColor()), forState: .Selected)
            shortWordButton.addTarget(self, action: #selector(KeyboardViewController.shortWordButtonPressed(_:)), forControlEvents: .TouchUpInside)
            self.view.addSubview(shortWordButton)
            arrayOfShortWordButton.append(shortWordButton);
        }
    }
    private func addNumpadButton()
    {
        for index in 1...10{
//            print("\(index) times 5 is \(index * 5)")
            numpadButton = KeyButton(frame: CGRectMake(spacing * CGFloat(index) + keyWidth * CGFloat(index-1), spacing + keyHeight, keyWidth, keyHeight))
            if index == 10 {
                numpadButton.setTitle("\(index - 10)", forState: .Normal)
                }
            else{
            numpadButton.setTitle("\(index)", forState: .Normal)
            }
            numpadButton.setTitleColor(UIColor(white: 245.0/255, alpha: 1.0), forState: UIControlState.Normal)
            let gradient = CAGradientLayer()
            gradient.frame = self.shortWordButton.bounds
            let gradientColors: [AnyObject] = [UIColor(red: 70.0/255, green: 70.0/255, blue: 70.0/255, alpha: 40.0).CGColor, UIColor(red: 60.0/255, green: 60.0/255, blue: 60.0/255, alpha: 1.0).CGColor]
            gradient.colors = gradientColors // Declaration broken into two lines to prevent 'unable to bridge to Objective C' error.
            
            numpadButton.setBackgroundImage(UIImage.fromColor(UIColor(red: 168.0/255, green: 168.0/255, blue: 168.0/255, alpha: 1.0)), forState: .Normal)
            numpadButton.setBackgroundImage(UIImage.fromColor(UIColor.blackColor()), forState: .Selected)
            
            //numpadButton.setBackgroundImage(gradient.UIImageFromCALayer(), forState: .Normal)

            numpadButton.addTarget(self, action: #selector(KeyboardViewController.numpadButtonPressed(_:)), forControlEvents: .TouchUpInside)
            self.view.addSubview(numpadButton)
            arrayOfNumberButton.append(numpadButton);
        }
    }
    
    private func addSwipeView() {
        swipeView = SwipeView(containerView: view, topOffset: 0)
        view.addSubview(swipeView)
    }
    
    private func moveButtonLabels(dx: CGFloat) {
        for (_, row) in characterButtons.enumerate() {
            for (_, characterButton) in row.enumerate() {
                characterButton.secondaryLabel.frame.offsetInPlace(dx: dx, dy: 0.0)
                characterButton.tertiaryLabel.frame.offsetInPlace(dx: dx, dy: 0.0)
            }
        }
        currentLanguageLabel.frame.offsetInPlace(dx: dx, dy: 0.0)
    }
    
    private func updateSuggestions() {
        
        if let lastWord = lastWordTyped {
        
            let filtedArray = self.lexicon.entries.filter({ (lexiconEntry) -> Bool in
                
                if ((lexiconEntry.documentText.rangeOfString(lastWord, options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil, locale: nil)) != nil)
                {
                    return true
                }
                else
                {
                    return false
                }
            })
            
            dispatch_async(dispatch_get_main_queue(), {
                
                for view in self.predictiveTextScrollView.subviews {
                    view.removeFromSuperview()
                    
                }
                self.suggestionButtons = [];
                
                var x = self.spacing
                for i in 0..<filtedArray.count
                {
                    let entry:UILexiconEntry = filtedArray[i]
                    let text = entry.userInput;
                    
                    let suggestionButton = SuggestionButton(frame: CGRectMake(x, 0.0, self.predictiveTextButtonWidth, self.predictiveTextBoxHeight), title: text, delegate: self)
                    
                    self.predictiveTextScrollView?.addSubview(suggestionButton)
                    self.suggestionButtons.append(suggestionButton)
                    
                    x += self.predictiveTextButtonWidth + self.spacing
                }
                
                self.predictiveTextScrollView!.contentSize = CGSizeMake(x, self.predictiveTextBoxHeight)
            })
        }
    }
}