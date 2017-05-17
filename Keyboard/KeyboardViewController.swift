//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Kari Kraam on 2016-04-20.
//  Copyright (c) 2017 Kaart Group, LLC. All rights reserved.
//

import Foundation
import UIKit

/**
    An iOS custom keyboard extension written in Swift designed to make it much, much easier to type code on an iOS device.
*/
class KeyboardViewController: UIInputViewController, CharacterButtonDelegate, SuggestionButtonDelegate, TouchForwardingViewDelegate {

    // MARK: Constants
    fileprivate let primaryCharacters = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]
    
    fileprivate var shortWord = ["Calle","Avenida","Callejón","Paseo","Jirón","Pasaje","Peatonal"]

//    func getShortWordArr() -> AnyObject {
//        let userDefaults : NSUserDefaults = NSUserDefaults.standardUserDefaults()
//
//        if ((userDefaults.objectForKey("SHORT_WORD_ARR")) != nil){
//            return userDefaults.objectForKey("SHORT_WORD_ARR")!
//        }else{
//            return ["Calle","Avenida","Callejón","Paseo","Jirón","Pasaje","Peatonal"]
//        }
//    }


    lazy var suggestionProvider: SuggestionProvider = SuggestionTrie()
    
    lazy var languageProviders = CircularArray(items: [DefaultLanguageProvider(), SwiftLanguageProvider()] as [LanguageProvider])
    
    fileprivate let spacing: CGFloat = 4.0
    fileprivate let predictiveTextBoxHeight: CGFloat = 24.0
    fileprivate var predictiveTextButtonWidth: CGFloat {
        return (view.frame.width - 4 * spacing) / 3.0
    }
    fileprivate var keyboardHeight: CGFloat {
        if(UIScreen.main.bounds.width < UIScreen.main.bounds.height ){
            return 400
        }
        else{
            return 370
        }
    }
    
    // Width of individual letter keys
    fileprivate var keyWidth: CGFloat {
        return (view.frame.width - 11 * spacing) / 10.0
    }
    
    // Width of individual short word keys
    fileprivate var wordKeyWidth: CGFloat {
        return (view.frame.width - 8 * spacing) / 7.0
    }
    
    //Height of individual keys
    fileprivate var keyHeight: CGFloat {
        return (keyboardHeight - 6.5 * spacing - predictiveTextBoxHeight) / 6.0
    }
    
    // MARK: User interface
    
    fileprivate var swipeView: SwipeView!
    fileprivate var predictiveTextScrollView: PredictiveTextScrollView!
    fileprivate var suggestionButtons = [SuggestionButton]()
    
    fileprivate lazy var characterButtons: [[CharacterButton]] = [
        [],
        [],
        []
    ]
    fileprivate var shiftButton: KeyButton!
    fileprivate var deleteButton: KeyButton!
    fileprivate var tabButton: KeyButton!
    fileprivate var nextKeyboardButton: UIButton!
    fileprivate var spaceButton: KeyButton!
    fileprivate var returnButton: KeyButton!
    fileprivate var currentLanguageLabel: UILabel!
    fileprivate var oopButton: KeyButton!
    fileprivate var nnpButton: KeyButton!
    
    // Number Buttons
    fileprivate var numpadButton: KeyButton!
    fileprivate var arrayOfNumberButton: [KeyButton] = []
    
    // Short Word Buttons
    fileprivate var shortWordButton: KeyButton!
    fileprivate var arrayOfShortWordButton: [KeyButton] = []
    
    fileprivate var dotButton: KeyButton!
    fileprivate var eepButton: KeyButton!
    fileprivate var iipButton: KeyButton!
    fileprivate var uupButton: KeyButton!
    // MARK: Timers
    
    fileprivate var deleteButtonTimer: Timer?
    fileprivate var spaceButtonTimer: Timer?
    
    // MARK: Properties
    
    fileprivate var heightConstraint: NSLayoutConstraint!
    
    fileprivate var proxy: UITextDocumentProxy {
        return textDocumentProxy
    }
    
    fileprivate var lastWordTyped: String? {
        if let documentContextBeforeInput = proxy.documentContextBeforeInput as NSString? {
            let length = documentContextBeforeInput.length
            if length > 0 && CharacterSet.letters.contains(UnicodeScalar(documentContextBeforeInput.character(at: length - 1))!) {
                let components = documentContextBeforeInput.components(separatedBy: CharacterSet.letters.inverted) 
                return components[components.endIndex - 1]
            }
        }
        return nil
    }

    fileprivate var languageProvider: LanguageProvider = DefaultLanguageProvider() {
        didSet {
            for (rowIndex, row) in characterButtons.enumerated() {
                for (characterButtonIndex, characterButton) in row.enumerated() {
                    characterButton.secondaryCharacter = languageProvider.secondaryCharacters[rowIndex][characterButtonIndex]
                    characterButton.tertiaryCharacter = languageProvider.tertiaryCharacters[rowIndex][characterButtonIndex]
                }
            }
            currentLanguageLabel.text = languageProvider.language
            suggestionProvider.clear()
            suggestionProvider.loadWeightedStrings(languageProvider.suggestionDictionary)
        }
    }

    fileprivate enum ShiftMode {
        case off, on, caps
    }
    
    fileprivate var shiftMode: ShiftMode = .on {
        didSet {
            shiftButton.isSelected = (shiftMode == .caps)
            for row in characterButtons {
                for characterButton in row {
                    switch shiftMode {
                    case .off:
                        characterButton.primaryLabel.text = characterButton.primaryCharacter.lowercased()
                        tabButton.setTitle("á", for: UIControlState())
                        eepButton.setTitle("é", for: UIControlState())
                        iipButton.setTitle("í", for: UIControlState())
                        uupButton.setTitle("ú", for: UIControlState())
                        nnpButton.setTitle("-", for: UIControlState())
                        oopButton.setTitle("'", for: UIControlState())
//                        characterButton.secondaryLabel.text = " "
//                        characterButton.tertiaryLabel.text = " "
                    case .on, .caps:
                        characterButton.primaryLabel.text = characterButton.primaryCharacter.uppercased()
                        tabButton.setTitle("Á", for: UIControlState())
                        eepButton.setTitle("É", for: UIControlState())
                        iipButton.setTitle("Í", for: UIControlState())
                        uupButton.setTitle("Ú", for: UIControlState())
                        nnpButton.setTitle("-", for: UIControlState())
                        oopButton.setTitle("'", for: UIControlState())
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
        for (rowIndex, row) in characterButtons.enumerated()
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
            
            for (buttonIndex, key) in row.enumerated()
            {
                let characterButton = key
                removeAllConstrains(characterButton);
                
                if( rowIndex == 0  )
                {
                    if(  buttonIndex == 0)
                    {
                        //First Row First Btn "Q"
                        
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .top, relatedBy: .equal, toItem: firstNumberBtn, attribute: .bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: x );
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false
                        topCons.isActive = true;
                        leftCons.isActive = true;
                        heightCons.isActive = true;
                        widthCons.isActive = true;
                        
                    }
                    else
                    {
                        let previosBtn = characterButtons[rowIndex][buttonIndex-1];
                        
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .top, relatedBy: .equal, toItem: firstNumberBtn, attribute: .bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .leading, relatedBy: .equal, toItem: previosBtn, attribute: .trailing, multiplier: 1.0, constant: spacing );
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false;
                        topCons.isActive = true;
                        leftCons.isActive = true;
                        heightCons.isActive = true;
                        widthCons.isActive = true;
                    }
                }
                else if( rowIndex == 1)
                {
                    let QCharBtn:CharacterButton = characterButtons[0][0];
                    
                    // Second Character Row "A"
                    if(  buttonIndex == 0)
                    {
                        //First Row First Btn "A"
                        
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .top, relatedBy: .equal, toItem: QCharBtn, attribute: .bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: x );
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false
                        topCons.isActive = true;
                        leftCons.isActive = true;
                        heightCons.isActive = true;
                        widthCons.isActive = true;
                        
                    }
                    else
                    {
                        let previosBtn = characterButtons[rowIndex][buttonIndex-1];
                        
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .top, relatedBy: .equal, toItem: QCharBtn, attribute: .bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .leading, relatedBy: .equal, toItem: previosBtn, attribute: .trailing, multiplier: 1.0, constant: spacing );
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false;
                        topCons.isActive = true;
                        leftCons.isActive = true;
                        heightCons.isActive = true;
                        widthCons.isActive = true;
                        
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
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .top, relatedBy: .equal, toItem: ACharBtn, attribute: .bottom, multiplier: 1.0, constant: spacing)
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: keyWidth + spacing * 2)
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false
                        topCons.isActive = true;
                        leftCons.isActive = true;
                        heightCons.isActive = true;
                        widthCons.isActive = true;
                        
                        
                        //Add Constraints for shift Button
                        removeAllConstrains(shiftButton);
                        
                        let topConsShiftBtn = NSLayoutConstraint(item: shiftButton, attribute: .top, relatedBy: .equal, toItem: ACharBtn, attribute: .bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftConsShiftBtn = NSLayoutConstraint(item: shiftButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: spacing );
                        
                        let heightConsShiftBtn = NSLayoutConstraint(item: shiftButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthConsShiftBtn = NSLayoutConstraint(item: shiftButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        shiftButton.translatesAutoresizingMaskIntoConstraints = false
                        topConsShiftBtn.isActive = true;
                        leftConsShiftBtn.isActive = true;
                        heightConsShiftBtn.isActive = true;
                        widthConsShiftBtn.isActive = true;
                        
                    }
                    else
                    {
                        let previosBtn = characterButtons[rowIndex][buttonIndex-1];
                        
                        let topCons = NSLayoutConstraint(item: characterButton, attribute: .top, relatedBy: .equal, toItem: ACharBtn, attribute: .bottom, multiplier: 1.0, constant: spacing);
                        
                        let leftCons = NSLayoutConstraint(item: characterButton, attribute: .leading, relatedBy: .equal, toItem: previosBtn, attribute: .trailing, multiplier: 1.0, constant: spacing );
                        
                        let heightCons = NSLayoutConstraint(item: characterButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                        
                        let widthCons = NSLayoutConstraint(item: characterButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
                        
                        characterButton.translatesAutoresizingMaskIntoConstraints = false;
                        topCons.isActive = true;
                        leftCons.isActive = true;
                        heightCons.isActive = true;
                        widthCons.isActive = true;
                        
                        // Constraints for Dot Button
                        if( buttonIndex == 6)
                        {
                            removeAllConstrains(dotButton);
                            // Add Dot Button Constraints
                            let topCons = NSLayoutConstraint(item: dotButton, attribute: .top, relatedBy: .equal, toItem: ACharBtn, attribute: .bottom, multiplier: 1.0, constant: spacing)
                            
//                            let rightCons = NSLayoutConstraint(item: dotButton, attribute: .Trailing, relatedBy: .Equal, toItem: deleteButton, attribute: .Trailing, multiplier: 1.0, constant: spacing)
                            
                            let widthCons = NSLayoutConstraint(item: dotButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
                            
                            let heightCons = NSLayoutConstraint(item: dotButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                            
                            let leftCons = NSLayoutConstraint(item: dotButton, attribute: .leading, relatedBy: .equal, toItem: characterButton, attribute: .trailing, multiplier: 1.0, constant: spacing)
                            
                            dotButton.translatesAutoresizingMaskIntoConstraints = false;
                            topCons.isActive = true;
                            leftCons.isActive = true;
                            heightCons.isActive = true;
                            widthCons.isActive = true;
//                            rightCons.active = true;
                        }

                        // Constraints for Delete Button
//                        if(  buttonIndex == 7 )
//                        {
                            // Add Constraint for Delete Button
                            removeAllConstrains(deleteButton);
                            
                            let topConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .top, relatedBy: .equal, toItem: ACharBtn, attribute: .bottom, multiplier: 1.0, constant: spacing);
                            
                            let leftConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .leading, relatedBy: .equal, toItem: dotButton, attribute: .trailing, multiplier: 1.0, constant: spacing );
                            
                            let heightConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                            
                            let rightConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: -spacing)
                            
                            deleteButton.translatesAutoresizingMaskIntoConstraints = false
                            topConsShiftBtn.isActive = true;
                            leftConsShiftBtn.isActive = true;
                            heightConsShiftBtn.isActive = true;
                            rightConsShiftBtn.isActive = true;
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
        
        let topConsTabButton = NSLayoutConstraint(item: tabButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsTabButton = NSLayoutConstraint(item: tabButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: spacing );
        
        let heightConsTabButton = NSLayoutConstraint(item: tabButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsTabButton = NSLayoutConstraint(item: tabButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        tabButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsTabButton.isActive = true
        leftConsTabButton.isActive = true
        heightConsTabButton.isActive = true
        widthConsTabButton.isActive = true
        
        // Add Constraints for eepButton
        removeAllConstrains(eepButton);
        
        let topConsEEPButton = NSLayoutConstraint(item: eepButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsEEPButton = NSLayoutConstraint(item: eepButton, attribute: .leading, relatedBy: .equal, toItem: tabButton, attribute: .trailing, multiplier: 1.0, constant: spacing );
        
        let heightConsEEPButton = NSLayoutConstraint(item: eepButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsEEPButton = NSLayoutConstraint(item: eepButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        eepButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsEEPButton.isActive = true
        leftConsEEPButton.isActive = true
        heightConsEEPButton.isActive = true
        widthConsEEPButton.isActive = true
        
        // Add Constraints for iipButton
        removeAllConstrains(iipButton);
        
        let topConsIIPButton = NSLayoutConstraint(item: iipButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsIIPButton = NSLayoutConstraint(item: iipButton, attribute: .leading, relatedBy: .equal, toItem: eepButton, attribute: .trailing, multiplier: 1.0, constant: spacing );
        
        let heightConsIIPButton = NSLayoutConstraint(item: iipButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsIIPButton = NSLayoutConstraint(item: iipButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        iipButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsIIPButton.isActive = true
        leftConsIIPButton.isActive = true
        heightConsIIPButton.isActive = true
        widthConsIIPButton.isActive = true
        
        // Add Constraints for iipButton
        removeAllConstrains(uupButton);
        
        let topConsUUPButton = NSLayoutConstraint(item: uupButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsUUPButton = NSLayoutConstraint(item: uupButton, attribute: .leading, relatedBy: .equal, toItem: iipButton, attribute: .trailing, multiplier: 1.0, constant: spacing );
        
        let heightConsUUPButton = NSLayoutConstraint(item: uupButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsUUPButton = NSLayoutConstraint(item: uupButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        uupButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsUUPButton.isActive = true
        leftConsUUPButton.isActive = true
        heightConsUUPButton.isActive = true
        widthConsUUPButton.isActive = true

        // Add Constraints for oopButton
        removeAllConstrains(oopButton);
        
        let topConsOOPButton = NSLayoutConstraint(item: oopButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsOOPButton = NSLayoutConstraint(item: oopButton, attribute: .leading, relatedBy: .equal, toItem: nnpButton, attribute: .trailing, multiplier: 1.0, constant: spacing);
        
        let heightConsOOPButton = NSLayoutConstraint(item: oopButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsOOPButton = NSLayoutConstraint(item: oopButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        oopButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsOOPButton.isActive = true
        leftConsOOPButton.isActive = true
        heightConsOOPButton.isActive = true
        widthConsOOPButton.isActive = true
        
        //Add Constraints for nnpButton
        removeAllConstrains(nnpButton)
        
        let topConsNNPButton = NSLayoutConstraint(item: nnpButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsNNPButton = NSLayoutConstraint(item: nnpButton, attribute: .leading, relatedBy: .equal, toItem: spaceButton, attribute: .trailing, multiplier: 1.0, constant: spacing);
        
        let heightConsNNPButton = NSLayoutConstraint(item: nnpButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsNNPButton = NSLayoutConstraint(item: nnpButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        nnpButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsNNPButton.isActive = true
        leftConsNNPButton.isActive = true
        heightConsNNPButton.isActive = true
        widthConsNNPButton.isActive = true
        
        // Add Constraints for Space Button
        removeAllConstrains(spaceButton);
        
        let topConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .leading, relatedBy: .equal, toItem: uupButton, attribute: .trailing, multiplier: 1.0, constant: spacing );
        
        let heightConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth * 2)
        
        spaceButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsSpeceButton.isActive = true
        leftConsSpeceButton.isActive = true
        heightConsSpeceButton.isActive = true
        widthConsSpeceButton.isActive = true
        
        // Add Constraints for Return Button
        removeAllConstrains(returnButton);
        
        let topConsReturnButton = NSLayoutConstraint(item: returnButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let rightConsReturnButton = NSLayoutConstraint(item: returnButton, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: -spacing );
        
        let heightConsReturnButton = NSLayoutConstraint(item: returnButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsReturnButton = NSLayoutConstraint(item: returnButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth * 1.5 )
        
        returnButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsReturnButton.isActive = true
        rightConsReturnButton.isActive = true
        heightConsReturnButton.isActive = true
        widthConsReturnButton.isActive = true
    }
    
    func removeAllConstrains(_ inputView:UIView)
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
        
        let topCons = NSLayoutConstraint(item: firstButton, attribute: .top, relatedBy: .equal, toItem: shortWordBtn, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let leftCons = NSLayoutConstraint(item: firstButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: spacing );
        
        let heightCons = NSLayoutConstraint(item: firstButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthCons = NSLayoutConstraint(item: firstButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        firstButton.translatesAutoresizingMaskIntoConstraints = false
        topCons.isActive = true;
        leftCons.isActive = true;
        heightCons.isActive = true;
        widthCons.isActive = true;
        
        for  i in 1..<arrayOfNumberButton.count
        {
            let previosBtn = arrayOfNumberButton[i-1]
            let shortWordButtonObj = arrayOfNumberButton[i];
            
            for cons in shortWordButtonObj.constraints{
                shortWordButtonObj.removeConstraint(cons);
            }
            
            let topCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .top, relatedBy: .equal, toItem: shortWordBtn, attribute: .bottom, multiplier: 1.0, constant: spacing );
            
            let leftCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .leading, relatedBy: .equal, toItem: previosBtn, attribute: .trailing, multiplier: 1.0, constant: spacing );
            
            let heightCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
            
            let widthCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
            
            shortWordButtonObj.translatesAutoresizingMaskIntoConstraints = false;
            topCons.isActive = true;
            leftCons.isActive = true;
            heightCons.isActive = true;
            widthCons.isActive = true;
        }
        
        //numpadButton = KeyButton(frame: CGRectMake(spacing * CGFloat(index) + keyWidth * CGFloat(index-1), spacing + keyHeight, keyWidth, keyHeight))
    }
    
    func updateConstraintForShortWorld()
    {
        for cons in arrayOfShortWordButton[0].constraints{
            arrayOfShortWordButton[0].removeConstraint(cons);
        }
        
        let topCons = NSLayoutConstraint(item: arrayOfShortWordButton[0], attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 40 + spacing);
        
        let leftCons = NSLayoutConstraint(item: arrayOfShortWordButton[0], attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: spacing );
        
        let heightCons = NSLayoutConstraint(item: arrayOfShortWordButton[0], attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthCons = NSLayoutConstraint(item: arrayOfShortWordButton[0], attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: wordKeyWidth)
        
        arrayOfShortWordButton[0].translatesAutoresizingMaskIntoConstraints = false
        topCons.isActive = true;
        leftCons.isActive = true;
        heightCons.isActive = true;
        widthCons.isActive = true;
        
        for  i in 1..<arrayOfShortWordButton.count
        {
            let previosBtn = arrayOfShortWordButton[i-1]
            let shortWordButtonObj = arrayOfShortWordButton[i];
            
            for cons in shortWordButtonObj.constraints{
                shortWordButtonObj.removeConstraint(cons);
            }
            
            let topCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant:  40 + spacing);
            
            let leftCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .leading, relatedBy: .equal, toItem: previosBtn, attribute: .trailing, multiplier: 1.0, constant: spacing );
            
            let heightCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
            
            let widthCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: wordKeyWidth)
            
            shortWordButtonObj.translatesAutoresizingMaskIntoConstraints = false;
            topCons.isActive = true;
            leftCons.isActive = true;
            heightCons.isActive = true;
            widthCons.isActive = true;
        }
    }
    
    func updateConstraintForPredictiveText()
    {
        
        // Add Constraints for Return Button
        removeAllConstrains(predictiveTextScrollView);
        
        let topCons = NSLayoutConstraint(item: predictiveTextScrollView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: spacing);
        
        let rightCons = NSLayoutConstraint(item: predictiveTextScrollView, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: -spacing );
        
        let heightCons = NSLayoutConstraint(item: predictiveTextScrollView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 30)
        
        let leftCons = NSLayoutConstraint(item: predictiveTextScrollView, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: spacing )
        
        predictiveTextScrollView.translatesAutoresizingMaskIntoConstraints = false;
        //predictiveTextScrollView.backgroundColor = UIColor.redColor()
        topCons.isActive = true
        rightCons.isActive = true
        heightCons.isActive = true
        leftCons.isActive = true
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

        shortWordTxtFld.isHidden = true

        self.requestSupplementaryLexicon { (lexObj) in
            self.lexicon = lexObj;
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        removeAllConstrains(nextKeyboardButton);
        
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        nextKeyboardButtonLeftSideConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .leading,
            relatedBy: .equal,
            toItem: oopButton,
            attribute: .trailing,
            multiplier: 1.0,
            constant: spacing)
        
        let nextKeyboardButtonRightSideConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .trailing,
            relatedBy: .equal,
            toItem: returnButton,
            attribute: .leading,
            multiplier: 1.0,
            constant: -spacing)
        
        let nextKeyboardButtonBottomConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .top,
            relatedBy: .equal,
            toItem: spaceButton,
            attribute: .top,
            multiplier: 1.0,
            constant: 0)
        
        let nextKeyboardButtonHeightConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
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
        
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        //shiftMode = .On
        
        addCharacterButtons()
       setUpHeightConstraint()
        updateshortWordTxtFldFrameOnRotareDevice()
    }
    
    func setUpHeightConstraint()
    {
        let iOrientation:UIInterfaceOrientation = self.interfaceOrientation;
        
        var customHeight = UIScreen.main.bounds.height / 2 ;
        if( iOrientation == .portrait || iOrientation == .portraitUpsideDown  )
        {
            customHeight = UIScreen.main.bounds.height / 2 - 90;
        }
        else if( iOrientation == .landscapeLeft || iOrientation == .landscapeRight  )
        {
            customHeight = UIScreen.main.bounds.height / 2 + 10;
        }
        else{
            return;
        }
        
        
        
        if heightConstraint == nil {
            heightConstraint = NSLayoutConstraint(item: view,
                                                  attribute: .height,
                                                  relatedBy: .equal,
                                                  toItem: nil,
                                                  attribute: .notAnAttribute,
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
    func shiftButtonPressed(_ sender: KeyButton) {
        switch shiftMode {
        case .off:
            shiftMode = .on
        case .on:
            shiftMode = .off
        case .caps:
            shiftMode = .off
        }
    }
    
    //
    func deleteButtonPressed(_ sender: KeyButton) {

        if shortWordTxtFld.isHidden == true {
            //        switch proxy.documentContextBeforeInput {
            //        case let s where s?.hasSuffix("    ") == true: // Cursor in front of tab, so delete tab.
            //            for _ in 0..<4 { // TODO: Update to use tab setting.
            //                proxy.deleteBackward()
            //            }
            //        default:
            proxy.deleteBackward()
            //        }
            updateSuggestions()

        }else{

            var tempStr : NSString = shortWordTxtFld.text! as NSString
            if shortWordTxtFld.text?.isEmpty == false  {
                tempStr = tempStr.substring(to: tempStr.length - 1) as NSString
                shortWordTxtFld.text = tempStr as String
            }
        }

    }
    
    var longPressStoped:Bool = false;
    
    func startMoreDelete(_ timer: Timer)
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
                    case let s where CharacterSet.letters.contains(UnicodeScalar(s.character(at: s.length - 1))!): // Cursor in front of letter, so delete up to first non-letter character.
                        let range = documentContextBeforeInput.rangeOfCharacter(from: CharacterSet.letters.inverted, options: .backwards)
                        if range.location != NSNotFound {
                            charactersToDelete = documentContextBeforeInput.length - range.location - 1
                        } else {
                            charactersToDelete = documentContextBeforeInput.length
                        }
                    case let s where s.hasSuffix(" "): // Cursor in front of whitespace, so delete up to first non-whitespace character.
                        let range = documentContextBeforeInput.rangeOfCharacter(from: CharacterSet.whitespaces.inverted, options: .backwards)
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
            let longPressTime = Timer(timeInterval: 0.2, target: self, selector: #selector(KeyboardViewController.startMoreDelete(_:)), userInfo: nil, repeats: false);
            
            RunLoop.main.add(longPressTime, forMode: RunLoopMode.defaultRunLoopMode)
            break
        }
        
        timer.invalidate();
        longPressStoped = false;
    }
    
    func handleDeleteButtonLongPress(_ timer: Timer) {
        
        timer.invalidate();
        //timer = nil
        
        deleteButtonTimer?.invalidate()
        deleteButtonTimer = nil
        
        let longPressTime = Timer(timeInterval: 0.3, target: self, selector: #selector(KeyboardViewController.startMoreDelete(_:)), userInfo: nil, repeats: false);
        
        RunLoop.main.add(longPressTime, forMode: RunLoopMode.defaultRunLoopMode)
    }
    
    //Delete Button long press action
    func handleLongPressForDeleteButtonWithGestureRecognizer(_ gestureRecognizer: UILongPressGestureRecognizer) {
       
        
        switch gestureRecognizer.state {
            
        case .began:
            
            longPressStoped = false;
            if deleteButtonTimer == nil {
                deleteButtonTimer = Timer(timeInterval: 0.1, target: self, selector: #selector(KeyboardViewController.handleDeleteButtonTimerTick(_:)), userInfo: nil, repeats: true)
                deleteButtonTimer!.tolerance = 0.01
                RunLoop.main.add(deleteButtonTimer!, forMode: RunLoopMode.defaultRunLoopMode)
                
                let longPressTime = Timer(timeInterval: 0.4, target: self, selector: #selector(KeyboardViewController.handleDeleteButtonLongPress(_:)), userInfo: nil, repeats: false);
                
                RunLoop.main.add(longPressTime, forMode: RunLoopMode.defaultRunLoopMode)
            }
        
        default:
            
            deleteButtonTimer?.invalidate()
            deleteButtonTimer = nil
            longPressStoped = true;
            //updateSuggestions()
        }
    }
    
    func handleSwipeLeftForDeleteButtonWithGestureRecognizer(_ gestureRecognizer: UISwipeGestureRecognizer) {
        // TODO: Figure out an implementation that doesn't use bridgeToObjectiveC, in case of funny unicode characters.
        if let documentContextBeforeInput = proxy.documentContextBeforeInput as NSString? {
            if documentContextBeforeInput.length > 0 {
                var charactersToDelete = 0
                switch documentContextBeforeInput {
                case let s where CharacterSet.letters.contains(UnicodeScalar(s.character(at: s.length - 1))!): // Cursor in front of letter, so delete up to first non-letter character.
                    let range = documentContextBeforeInput.rangeOfCharacter(from: CharacterSet.letters.inverted, options: .backwards)
                    if range.location != NSNotFound {
                        charactersToDelete = documentContextBeforeInput.length - range.location - 1
                    } else {
                        charactersToDelete = documentContextBeforeInput.length
                    }
                case let s where s.hasSuffix(" "): // Cursor in front of whitespace, so delete up to first non-whitespace character.
                    let range = documentContextBeforeInput.rangeOfCharacter(from: CharacterSet.whitespaces.inverted, options: .backwards)
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
    
    func handleDeleteButtonTimerTick(_ timer: Timer) {
        proxy.deleteBackward()
    }
    
    func spaceButtonPressed(_ sender: KeyButton) {

        let charStr : String = " "

        if updateShortField(charStr) == true{
            return
        }

        for suffix in languageProvider.autocapitalizeAfter {
            if proxy.documentContextBeforeInput!.hasSuffix(suffix) {
                shiftMode = .on
            }
        }
        shiftMode = .on
        proxy.insertText(charStr)
        updateSuggestions()
    }
    
    // Input the character "ñ" instead of tab
    func aapButtonPressed(_ sender: KeyButton) {

        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }
        proxy.insertText(sender.currentTitle!)
        shiftMode = .off
    }
    
    func eepButtonPressed(_ sender: KeyButton){

        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }

        proxy.insertText(sender.currentTitle!)
        shiftMode = .off
    }
    
    func iipButtonPressed(_ sender: KeyButton){

        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }

        proxy.insertText(sender.currentTitle!)
        shiftMode = .off
    }
    
    func uupButtonPressed(_ sender: KeyButton){

        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }

        proxy.insertText(sender.currentTitle!)
        shiftMode = .off
    }
    
    // Input the character ""
    func oopButtonPressed(_ sender: KeyButton) {

        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }

        proxy.insertText(sender.currentTitle!)
        shiftMode = .off
    }
    
    func nnpButtonPressed(_ sender: KeyButton) {

        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }

        proxy.insertText(sender.currentTitle!)
        shiftMode = .off
    }
    
    // When the numpadButton is pressed
    func numpadButtonPressed(_ sender: KeyButton){

        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }

        proxy.insertText(sender.currentTitle!)
    }
    
    // When the shortWordButton is pressed
    func shortWordButtonPressed(_ sender: KeyButton){

        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }

        proxy.insertText(sender.currentTitle!)
        proxy.insertText(" ")
    }
    
    // When the dotButton is pressed
    func dotButtonPressed(_ sender: KeyButton){

        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }

        proxy.insertText(".")
    }
    

    
    func handleLongPressForSpaceButtonWithGestureRecognizer(_ gestureRecognizer: UISwipeGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            if spaceButtonTimer == nil {
                spaceButtonTimer = Timer(timeInterval: 0.1, target: self, selector: #selector(KeyboardViewController.handleSpaceButtonTimerTick(_:)), userInfo: nil, repeats: true)
                spaceButtonTimer!.tolerance = 0.01
                RunLoop.main.add(spaceButtonTimer!, forMode: RunLoopMode.defaultRunLoopMode)
            }
        default:
            spaceButtonTimer?.invalidate()
            spaceButtonTimer = nil
            updateSuggestions()
        }
    }
    
    func handleSpaceButtonTimerTick(_ timer: Timer) {
        proxy.insertText(" ")
    }
    
    func handleSwipeLeftForSpaceButtonWithGestureRecognizer(_ gestureRecognizer: UISwipeGestureRecognizer) {
        UIView.animate(withDuration: 0.1, animations: {
            self.moveButtonLabels(-self.keyWidth)
            }, completion: {
                (success: Bool) -> Void in
                self.languageProviders.increment()
                self.languageProvider = self.languageProviders.currentItem!
                self.moveButtonLabels(self.keyWidth * 2.0)
                UIView.animate(withDuration: 0.1, animations: {
                    self.moveButtonLabels(-self.keyWidth)
                }) 
            }
        )
    }
    
    func handleSwipeRightForSpaceButtonWithGestureRecognizer(_ gestureRecognizer: UISwipeGestureRecognizer) {
        UIView.animate(withDuration: 0.1, animations: {
            self.moveButtonLabels(self.keyWidth)
            }, completion: {
                (success: Bool) -> Void in
                self.languageProviders.decrement()
                self.languageProvider = self.languageProviders.currentItem!
                self.moveButtonLabels(-self.keyWidth * 2.0)
                UIView.animate(withDuration: 0.1, animations: {
                    self.moveButtonLabels(self.keyWidth)
                }) 
            }
        )
    }
    
    func returnButtonPressed(_ sender: KeyButton) {

        let senderStr : String = "\n"

        if updateShortField(senderStr) == true{
            return
        }

        proxy.insertText(senderStr)
        shiftMode = .on
        updateSuggestions()

    }
    
    // MARK: CharacterButtonDelegate methods
    
    func handlePressForCharacterButton(_ button: CharacterButton) {

        var charStr : String = ""

        switch shiftMode {
        case .off:
            charStr = button.primaryCharacter.lowercased()
        case .on:
            charStr = button.primaryCharacter.uppercased()
            shiftMode = .off
        case .caps:
            charStr = button.primaryCharacter.uppercased()
        }

        if updateShortField(charStr) == true{
            return
        }

        proxy.insertText(charStr)
        updateSuggestions()
    }
    
    func handleSwipeUpForButton(_ button: CharacterButton) {
        proxy.insertText(button.secondaryCharacter)
        if button.secondaryCharacter.characters.count > 1 {
            proxy.insertText(" ")
        }
        updateSuggestions()
    }
    
    func handleSwipeDownForButton(_ button: CharacterButton) {
        proxy.insertText(button.tertiaryCharacter)
        if button.tertiaryCharacter.characters.count > 1 {
            proxy.insertText(" ")
        }
        updateSuggestions()
    }
    
    // MARK: SuggestionButtonDelegate methods
    
    func handlePressForSuggestionButton(_ button: SuggestionButton) {
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
    func viewForHitTestWithPoint(_ point: CGPoint, event: UIEvent?, superResult: UIView?) -> UIView? {
        for subview in view.subviews {
            let convertPoint = subview.convert(point, from: view)
            if subview is KeyButton && subview.point(inside: convertPoint, with: event) {
                return subview
            }
        }
        return swipeView
    }
    
    // MARK: Helper methods
    
    fileprivate func initializeKeyboard() {
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
    
    fileprivate func addPredictiveTextScrollView() {
        predictiveTextScrollView = PredictiveTextScrollView(frame: CGRect(x: 0.0, y: 0.0, width: self.view.frame.width, height: predictiveTextBoxHeight))
        self.view.addSubview(predictiveTextScrollView)
    }
    
    fileprivate func addShiftButton() {
        shiftButton = KeyButton(frame: CGRect(x: spacing, y: keyHeight * 4.0 + spacing * 5.0, width: keyWidth, height: keyHeight))
        shiftButton.setTitle("\u{000021E7}", for: UIControlState())
        shiftButton.addTarget(self, action: #selector(KeyboardViewController.shiftButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(shiftButton)
    }
    
    fileprivate func addDeleteButton() {
        deleteButton = KeyButton(frame: CGRect(x: keyWidth * 8.5 + spacing * 9.5, y: keyHeight * 4.0 + spacing * 5.0, width: keyWidth * 1.5 + spacing / 2, height: keyHeight))
        deleteButton.setTitle("\u{0000232B}", for: UIControlState())
        deleteButton.addTarget(self, action: #selector(KeyboardViewController.deleteButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(deleteButton)
        
        let deleteButtonLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(KeyboardViewController.handleLongPressForDeleteButtonWithGestureRecognizer(_:)))
        deleteButton.addGestureRecognizer(deleteButtonLongPressGestureRecognizer)
        
//        let deleteButtonSwipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(KeyboardViewController.handleSwipeLeftForDeleteButtonWithGestureRecognizer(_:)))
//        deleteButtonSwipeLeftGestureRecognizer.direction = .Left
//        deleteButton.addGestureRecognizer(deleteButtonSwipeLeftGestureRecognizer)
    }
    
    fileprivate func addAapButton() {
        tabButton = KeyButton(frame: CGRect(x: spacing, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth, height: keyHeight))
        tabButton.setTitle("Á", for: UIControlState())
        tabButton.addTarget(self, action: #selector(KeyboardViewController.aapButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(tabButton)
    }
    
    fileprivate func addEepButton() {
        eepButton = KeyButton(frame: CGRect(x: spacing * 2 + keyWidth, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth, height: keyHeight))
        eepButton.setTitle("É", for: UIControlState())
        eepButton.addTarget(self, action: #selector(KeyboardViewController.eepButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(eepButton)
    }
    
    fileprivate func addDotButton()
    {
        dotButton = KeyButton(frame: CGRect(x: spacing * 10.5 + keyWidth * 9.5, y: spacing * 4 + keyHeight * 3, width: keyWidth / 2 - spacing / 2, height: keyHeight))
        dotButton.setTitle(".", for: UIControlState())
        dotButton.addTarget(self, action: #selector(KeyboardViewController.dotButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(dotButton)
    }
    
    fileprivate func addIipButton() {
        iipButton = KeyButton(frame: CGRect(x: keyWidth * 2 + spacing * 3, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth, height: keyHeight))
        iipButton.setTitle("Í", for: UIControlState())
        iipButton.addTarget(self, action: #selector(KeyboardViewController.iipButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(iipButton)
    }
    
    fileprivate func addUupButton() {
        uupButton = KeyButton(frame: CGRect(x: keyWidth * 3 + spacing * 4, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth, height: keyHeight))
        uupButton.setTitle("Ú", for: UIControlState())
        uupButton.addTarget(self, action: #selector(KeyboardViewController.uupButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(uupButton)
    }
    
    fileprivate func addOopButton() {
        oopButton = KeyButton(frame: CGRect(x: keyWidth * 4 + spacing * 5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth, height: keyHeight))
        oopButton.setTitle("'", for: UIControlState())
        oopButton.addTarget(self, action: #selector(KeyboardViewController.oopButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(oopButton)
    }
 
    fileprivate func addNnpButton() {
        nnpButton = KeyButton(frame: CGRect(x: keyWidth * 4 + spacing * 5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth, height: keyHeight))
        nnpButton.setTitle("-", for: UIControlState())
        nnpButton.addTarget(self, action: #selector(KeyboardViewController.nnpButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(nnpButton)
    }
   
    fileprivate func addNextKeyboardButton() {
        nextKeyboardButton = KeyButton(frame: CGRect(x: keyWidth * 7.5 + spacing * 8.5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth / 2, height: keyHeight))
        nextKeyboardButton.setTitle("\u{0001F310}", for: UIControlState())
        nextKeyboardButton.addTarget(self, action: #selector(UIInputViewController.advanceToNextInputMode), for: .touchUpInside)
        self.view.addSubview(nextKeyboardButton)
    }
    
    fileprivate func addSpaceButton() {
        spaceButton = KeyButton(frame: CGRect(x: keyWidth * 5 + spacing * 6, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth * 2.5 + spacing * 1.5, height: keyHeight))
        spaceButton.setTitle("Space", for: UIControlState())
        spaceButton.addTarget(self, action: #selector(KeyboardViewController.spaceButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(spaceButton)

    }
    
    fileprivate func addReturnButton() {
        returnButton = KeyButton(frame: CGRect(x: keyWidth * 8.5 + spacing * 9.5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth * 1.5 + spacing / 2, height: keyHeight))
        returnButton.setTitle("\u{000023CE}", for: UIControlState())
        returnButton.addTarget(self, action: #selector(KeyboardViewController.returnButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(returnButton)
    }
    
    fileprivate func addCharacterButtons() {
        
        
        for (_, row) in characterButtons.enumerated() {
            
            for (_, key) in row.enumerated() {
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
        for (rowIndex, row) in primaryCharacters.enumerated() {
            
            var x: CGFloat
            switch rowIndex {
            case 1:
                x = spacing * 1.5 + keyWidth * 0.5
            case 2:
                x = spacing * 2.5 + keyWidth * 1.5
            default:
                x = spacing
            }
            for (_, key) in row.enumerated() {
                let characterButton = CharacterButton(frame: CGRect(x: x, y: y, width: keyWidth, height: keyHeight), primaryCharacter: key.uppercased(), secondaryCharacter: " ", tertiaryCharacter: " ", delegate: self)
                self.view.addSubview(characterButton)
                characterButtons[rowIndex].append(characterButton)
                x += keyWidth + spacing
            }
            y += keyHeight + spacing
        }
    }
    
    fileprivate func addShortWordButton(){

        let userDefaults : UserDefaults = UserDefaults.standard

        if ((userDefaults.object(forKey: "SHORT_WORD_ARR")) != nil){
            shortWord = userDefaults.object(forKey: "SHORT_WORD_ARR")! as! [String]
        }

        for index in 1...7{
            shortWordButton = KeyButton(frame: CGRect(x: spacing * CGFloat(index) + wordKeyWidth * CGFloat(index-1), y: 0.0, width: wordKeyWidth, height: keyHeight))
            shortWordButton.setTitle(shortWord[index-1], for: UIControlState())
            shortWordButton.setTitleColor(UIColor(white: 245.0/245, alpha: 1.0), for: UIControlState())
            let gradient = CAGradientLayer()
            gradient.frame = self.shortWordButton.bounds
            let gradientColors: [AnyObject] = [UIColor(red: 70.0/255, green: 70.0/255, blue: 70.0/255, alpha: 40.0).cgColor, UIColor(red: 60.0/255, green: 60.0/255, blue: 60.0/255, alpha: 1.0).cgColor]
            gradient.colors = gradientColors // Declaration broken into two lines to prevent 'unable to bridge to Objective C' error.
            
            shortWordButton.setBackgroundImage(UIImage.fromColor(UIColor(red: 122.0/255, green: 122.0/255, blue: 122.0/255, alpha: 1.0)), for: UIControlState())
            shortWordButton.setBackgroundImage(UIImage.fromColor(UIColor.black), for: .selected)
            shortWordButton.addTarget(self, action: #selector(KeyboardViewController.shortWordButtonPressed(_:)), for: .touchUpInside)

            let gesture : UILongPressGestureRecognizer = UILongPressGestureRecognizer.init(target: self, action: #selector(self.longPressShortWord(_:)))
            gesture.minimumPressDuration = 0.4
            shortWordButton.addGestureRecognizer(gesture)

            self.view.addSubview(shortWordButton)
            arrayOfShortWordButton.append(shortWordButton);
        }
    }
    var selectedShortWordBtn :UIButton = UIButton.init()
    
    var shortWordTxtFld : UITextField = UITextField.init()
    
//    var editMenu : UIMenuController = UIMenuController.init()
//    
//    let copyItem = UIMenuItem(title: "Copy", action: #selector(UIResponderStandardEditActions.copy(_:)))
    
//        func longPressShortWordTxtFld(_ gesture:UIGestureRecognizer){
//        self.editMenu = UIMenuController.init()
//        //        if let selectedRange = self.shortWordTxtFld.selectedTextRange {
//        //
//        //            let cursorPosition = self.shortWordTxtFld.offset(from: self.shortWordTxtFld.beginningOfDocument, to: selectedRange.start)
//        //
//        //            editMenu.setTargetRect(CGRect(selectedRange.end), in: self.view)
//        //        }
//        
//        //            if let pasteString = UIPasteboard.general.string{
//        //                self.shortWordTxtFld.insertText(pasteString)
//        //            }
//        
//        //        let copyItem = UIMenuItem(title: "Copy", action: #selector(UIPasteboard.copy))
//        editMenu.menuItems = [copyItem]
//        ////            editMenu.menuItems?.insert(copyItem, at: 0)
//        editMenu.update()
//        
//        editMenu.setMenuVisible(true, animated: true)
//        
//    }

    // MARK: Short Word method
    
    func addShortWordTxtFld(){
        
        var tempRct: CGRect = predictiveTextScrollView.frame
        
        tempRct.size.width = tempRct.size.width - keyWidth - 3*spacing
        
        tempRct.origin.x =  spacing
        self.shortWordTxtFld.removeFromSuperview()
        
        self.shortWordTxtFld = UITextField.init(frame: tempRct)
        
//        shortWordTxtFld.becomeFirstResponder()
        
//        let gesture : UILongPressGestureRecognizer = UILongPressGestureRecognizer.init(target: self, action: #selector(self.longPressShortWordTxtFld(_:)))
//        gesture.minimumPressDuration = 0.4
//        shortWordTxtFld.addGestureRecognizer(gesture)
        
        self.shortWordTxtFld.backgroundColor = UIColor.lightGray
        self.view.addSubview(shortWordTxtFld)
        self.view.bringSubview(toFront: self.shortWordTxtFld)
        
        tempRct.origin.x = tempRct.origin.x + tempRct.size.width + 2*spacing
        
        tempRct.size.width = keyWidth
        
        doneBtn.removeFromSuperview()
        doneBtn = KeyButton.init(frame: tempRct)
        
        doneBtn.setTitle("Done", for: UIControlState())
        doneBtn.setBackgroundImage(UIImage.fromColor(UIColor.white), for: UIControlState())
        
        doneBtn.addTarget(self, action: #selector(self.doneSelect(_:)), for: .touchUpInside)
        
        doneBtn.backgroundColor = UIColor.gray
        self.view.addSubview(doneBtn)
        
//        copyBtn.removeFromSuperview()
//        copyBtn = KeyButton.init(frame: tempRct)
//        
//        copyBtn.setTitle("Copy", for: UIControlState())
//        copyBtn.setBackgroundImage(UIImage.fromColor(UIColor.white), for: UIControlState())
//        
//        copyBtn.addTarget(self, action: #selector(self.doneSelect(_:)), for: .touchUpInside)
//        
//        copyBtn.backgroundColor = UIColor.gray
//        self.view.addSubview(copyBtn)
//
//        pasteBtn.removeFromSuperview()
//        pasteBtn = KeyButton.init(frame: tempRct)
//        
//        pasteBtn.setTitle("Paste", for: UIControlState())
//        pasteBtn.setBackgroundImage(UIImage.fromColor(UIColor.white), for: UIControlState())
//        
//        pasteBtn.addTarget(self, action: #selector(self.doneSelect(_:)), for: .touchUpInside)
//        
//        pasteBtn.backgroundColor = UIColor.gray
//        self.view.addSubview(pasteBtn)

        
    }

//    var copyBtn:KeyButton = KeyButton.init(frame: CGRect(x:0, y: 0, width: 50, height: 50))
//    
//    var pasteBtn:KeyButton = KeyButton.init(frame: CGRect(x:0, y: 0, width: 50, height: 50))
//
    var doneBtn:KeyButton = KeyButton.init(frame: CGRect(x: 0, y: 0, width: 50, height: 50))

    func doneSelect(_ btn:UIButton){

        let newStr : String = (shortWordTxtFld.text?.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
            ))!

        if newStr.isEmpty == false {

            let oldTitle : String = (selectedShortWordBtn.titleLabel?.text)!

            let tempArr : NSMutableArray = NSMutableArray.init(array:shortWord)

            if tempArr.contains(oldTitle){
                let index : NSInteger = tempArr.index(of: oldTitle)
                tempArr.replaceObject(at: index, with: newStr)

                shortWord = NSArray.init(array: tempArr) as! [String]

                let defaults : UserDefaults = UserDefaults.standard
                defaults.set(shortWord, forKey: "SHORT_WORD_ARR")
                defaults.synchronize()
            }

            selectedShortWordBtn.setTitle(newStr, for: UIControlState())
           
        }
        shortWordTxtFld.isHidden = true
        doneBtn.isHidden = true
        predictiveTextScrollView.isHidden = false
        
        //            shortWordTxtFld.resignFirstResponder()
        shortWordTxtFld.removeFromSuperview()
        
        selectedShortWordBtn.layer.borderWidth = 0.0
        selectedShortWordBtn.layer.borderColor = UIColor.clear.cgColor

    }

    func updateShortField(_ senderStr : String) -> Bool {
        if shortWordTxtFld.isHidden == false {
            var tmepStr : NSString = shortWordTxtFld.text! as NSString
            tmepStr = tmepStr.appending(senderStr) as NSString
            shortWordTxtFld.text = tmepStr as String
            return true
        }else{
            return false
        }
    }

    func longPressShortWord(_ gesture:UIGestureRecognizer)  {

        if gesture.state == .ended  {

            selectedShortWordBtn.layer.borderWidth = 0.0
            selectedShortWordBtn.layer.borderColor = UIColor.clear.cgColor

            predictiveTextScrollView.isHidden = true

            selectedShortWordBtn = gesture.view as! UIButton
            selectedShortWordBtn.layer.borderWidth = 3.0
            selectedShortWordBtn.layer.borderColor = UIColor.white.cgColor
            addShortWordTxtFld()
        }
    }

    func updateshortWordTxtFldFrameOnRotareDevice() {
        var tempRct: CGRect = predictiveTextScrollView.frame

        tempRct.size.width = tempRct.size.width - keyWidth - 3*spacing
        tempRct.origin.x =  spacing
        shortWordTxtFld.frame = tempRct

        tempRct.origin.x = tempRct.origin.x + tempRct.size.width + 2*spacing
        tempRct.size.width = keyWidth
        doneBtn.frame = tempRct

    }

    fileprivate func addNumpadButton()
    {
        for index in 1...10{
//            print("\(index) times 5 is \(index * 5)")
            numpadButton = KeyButton(frame: CGRect(x: spacing * CGFloat(index) + keyWidth * CGFloat(index-1), y: spacing + keyHeight, width: keyWidth, height: keyHeight))
            if index == 10 {
                numpadButton.setTitle("\(index - 10)", for: UIControlState())
                }
            else{
            numpadButton.setTitle("\(index)", for: UIControlState())
            }
            numpadButton.setTitleColor(UIColor(white: 245.0/255, alpha: 1.0), for: UIControlState())
            let gradient = CAGradientLayer()
            gradient.frame = self.shortWordButton.bounds
            let gradientColors: [AnyObject] = [UIColor(red: 70.0/255, green: 70.0/255, blue: 70.0/255, alpha: 40.0).cgColor, UIColor(red: 60.0/255, green: 60.0/255, blue: 60.0/255, alpha: 1.0).cgColor]
            gradient.colors = gradientColors // Declaration broken into two lines to prevent 'unable to bridge to Objective C' error.
            
            numpadButton.setBackgroundImage(UIImage.fromColor(UIColor(red: 168.0/255, green: 168.0/255, blue: 168.0/255, alpha: 1.0)), for: UIControlState())
            numpadButton.setBackgroundImage(UIImage.fromColor(UIColor.black), for: .selected)
            
            //numpadButton.setBackgroundImage(gradient.UIImageFromCALayer(), forState: .Normal)

            numpadButton.addTarget(self, action: #selector(KeyboardViewController.numpadButtonPressed(_:)), for: .touchUpInside)
            self.view.addSubview(numpadButton)
            arrayOfNumberButton.append(numpadButton);
        }
    }
    
    fileprivate func addSwipeView() {
        swipeView = SwipeView(containerView: view, topOffset: 0)
        view.addSubview(swipeView)
    }
    
    fileprivate func moveButtonLabels(_ dx: CGFloat) {
        for (_, row) in characterButtons.enumerated() {
            for (_, characterButton) in row.enumerated() {
                characterButton.secondaryLabel.frame.offsetBy(dx: dx, dy: 0.0)
                characterButton.tertiaryLabel.frame.offsetBy(dx: dx, dy: 0.0)
            }
        }
        currentLanguageLabel.frame.offsetBy(dx: dx, dy: 0.0)
    }
    
    fileprivate func updateSuggestions() {
        
        if let lastWord = lastWordTyped {
        
            let filtedArray = self.lexicon.entries.filter({ (lexiconEntry) -> Bool in
                
                if ((lexiconEntry.documentText.range(of: lastWord, options: NSString.CompareOptions.caseInsensitive, range: nil, locale: nil)) != nil)
                {
                    return true
                }
                else
                {
                    return false
                }
            })
            
            DispatchQueue.main.async(execute: {
                
                for view in self.predictiveTextScrollView.subviews {
                    view.removeFromSuperview()
                    
                }
                self.suggestionButtons = [];
                
                var x = self.spacing
                for i in 0..<filtedArray.count
                {
                    let entry:UILexiconEntry = filtedArray[i]
                    let text = entry.userInput;
                    
                    let suggestionButton = SuggestionButton(frame: CGRect(x: x, y: 0.0, width: self.predictiveTextButtonWidth, height: self.predictiveTextBoxHeight), title: text, delegate: self)
                    
                    self.predictiveTextScrollView?.addSubview(suggestionButton)
                    self.suggestionButtons.append(suggestionButton)
                    
                    x += self.predictiveTextButtonWidth + self.spacing
                }
                
                self.predictiveTextScrollView!.contentSize = CGSize(width: x, height: self.predictiveTextBoxHeight)
            })
        }
    }
}
