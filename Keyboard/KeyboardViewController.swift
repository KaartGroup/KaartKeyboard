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
    
    fileprivate var shortWord = [
        ["Press &","Hold","To","Edit","These","Presets","!"],
        ["Press", "The", "Kaart", "Keyboard", "Logo", "To Switch", "Languages"]
    ]
    
    fileprivate var isSecondary:Bool = false
    
    fileprivate var secondaryTap : UIGestureRecognizer!
    
    fileprivate var secondaryChar:String = ""
    
    fileprivate var secondaryToShow : [KeyButton] = []
    
    fileprivate var currentLanguage: Language {
        let currLang = UserDefaults.standard.string(forKey: "CURRENT_LANG")
        for lang in languages {
            if lang.title == currLang { return lang }
        }
        return languages[0]
    }
    
    fileprivate var _showEnglish : Bool = false
    fileprivate var _showGreek: Bool = false
    fileprivate var _showSerbianCyrillic: Bool = false
    fileprivate var _showRomanian: Bool = false
    fileprivate var _showMacedonian: Bool = false
    fileprivate var _showBulgarian: Bool = false
    fileprivate var _showVietnamese: Bool = false

    fileprivate var english: Language!
    fileprivate var greek: Language!
    fileprivate var serbian_cyrillic: Language!
    fileprivate var romanian: Language!
    fileprivate var macedonian: Language!
    fileprivate var bulgarian: Language!
    fileprivate var vietnamese: Language!

    fileprivate var languages: [Language] = []
    
    fileprivate var defaults = UserDefaults(suiteName: "group.com.kaartgroup.KaartKeyboard")
    
    fileprivate var showLanguages: [String:Bool] {
        return [
            "english": _showEnglish,
            "greek": _showGreek,
            "serbian-cyrillic": _showSerbianCyrillic,
            "romanian": _showRomanian,
            "macedonian": _showMacedonian,
            "bulgarian": _showBulgarian,
            "vietnamese": _showVietnamese
        ]
    }
    
    lazy var suggestionProvider: SuggestionProvider = SuggestionTrie()
    
    lazy var languageProviders = CircularArray(items: [DefaultLanguageProvider(), SwiftLanguageProvider()] as [LanguageProvider])
    
    fileprivate let spacing: CGFloat = 5.0
    fileprivate let predictiveTextBoxHeight: CGFloat = 24.0
    fileprivate var predictiveTextButtonWidth: CGFloat {
        return (view.frame.width - 4 * spacing) / 3.0
    }
    fileprivate var keyboardHeight: CGFloat {
        if(UIScreen.main.bounds.width < UIScreen.main.bounds.height ){
            return 440
        }
        else{
            return 410
        }
    }
    
    fileprivate var rowCount: CGFloat = 9.0
    
    // Width of individual letter keys
    fileprivate var keyWidth: CGFloat {
        return (view.frame.width - (rowCount + 2) * spacing) / (rowCount + 1)
    }
    
    // Width of individual short word keys
    fileprivate var wordKeyWidth: CGFloat {
        return (view.frame.width - 8 * spacing) / 7.0
    }
    
    //Height of individual keys
    fileprivate var keyHeight: CGFloat {
        return (keyboardHeight - 7.0 * spacing - predictiveTextBoxHeight) / 6.5
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
    fileprivate var tertiaryButtons: [KeyButton] = []
    fileprivate var shiftButton: KeyButton!
//    fileprivate var shiftButton: KeyButton!
    fileprivate var deleteButton: KeyButton!
    //    fileprivate var tabButton: KeyButton!
    fileprivate var nextKeyboardButton: KeyButton!
    fileprivate var spaceButton: KeyButton!
    fileprivate var returnButton: KeyButton!
    fileprivate var currentLanguageLabel: UILabel!
    fileprivate var kaartKeyboardButton: KeyButton!
    //    fileprivate var oopButton: KeyButton!
    //    fileprivate var nnpButton: KeyButton!
    
    // Number Buttons
    fileprivate var numpadButton: KeyButton!
    fileprivate var arrayOfNumberButton: [KeyButton] = []
    
    // Short Word Buttons
    fileprivate var shortWordButton: KeyButton!
    fileprivate var arrayOfShortWordButton: [[KeyButton]] = [[],[]]
    
    //    fileprivate var dotButton: KeyButton!
    //    fileprivate var eepButton: KeyButton!
    //    fileprivate var iipButton: KeyButton!
    //    fileprivate var uupButton: KeyButton!
    // MARK: Timers
    
    fileprivate var deleteButtonTimer: Timer?
    fileprivate var spaceButtonTimer: Timer?
    
    fileprivate var spaceTitle: String {
        return (UserDefaults.standard.string(forKey: "CURRENT_LANG")?.uppercased())!
    }
    
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
                    //                    characterButton.tertiaryCharacters = languageProvider.tertiaryCharacters[rowIndex][characterButtonIndex]
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
                        //                        tabButton.setTitle("'", for: UIControlState())
                        //                        eepButton.setTitle("-", for: UIControlState())
                        //                        iipButton.setTitle(":", for: UIControlState())
                        //                        uupButton.setTitle("_", for: UIControlState())
                        //                        nnpButton.setTitle("-", for: UIControlState())
                        //                        oopButton.setTitle("'", for: UIControlState())
                        //                        characterButton.secondaryLabel.text = " "
                    //                        characterButton.tertiaryLabel.text = " "
                    case .on, .caps:
                        characterButton.primaryLabel.text = characterButton.primaryCharacter.uppercased()
                        //                        tabButton.setTitle("'", for: UIControlState())
                        //                        eepButton.setTitle("-", for: UIControlState())
                        //                        iipButton.setTitle(":", for: UIControlState())
                        //                        uupButton.setTitle("_", for: UIControlState())
                        //                        nnpButton.setTitle("-", for: UIControlState())
                        //                        oopButton.setTitle("'", for: UIControlState())
                        //                        characterButton.secondaryLabel.text = " "
                        //                        characterButton.tertiaryLabel.text = " "
                    }
                    
                }
            }
            if isSecondary{
                for secondary in secondaryToShow{
                    switch shiftMode {
                    case .off:
                        secondary.titleLabel?.text = secondary.titleLabel?.text?.lowercased()
                    case .on, .caps:
                        secondary.titleLabel?.text = secondary.titleLabel?.text?.uppercased()
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
//        let shortWord: KeyButton = arrayOfShortWordButton[1][0]
        let firstNumberBtn:KeyButton = arrayOfNumberButton[0]
        
        var y = spacing * 3 + keyHeight * 2
        for (rowIndex, row) in characterButtons.enumerated()
        {
            

            var x: CGFloat
            switch rowIndex {
            case 1:
                rowCount = CGFloat(row.count)
                x = spacing * 1.5 + keyWidth * 0.5
            case 2:
                rowCount = CGFloat(row.count)
                x = spacing * 2.5 + keyWidth * 1.5
            default:
                rowCount = CGFloat(row.count)
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
                        //                        if( buttonIndex == 6)
                        //                        {
                        //                            removeAllConstrains(dotButton);
                        //                            // Add Dot Button Constraints
                        //                            let topCons = NSLayoutConstraint(item: dotButton, attribute: .top, relatedBy: .equal, toItem: ACharBtn, attribute: .bottom, multiplier: 1.0, constant: spacing)
                        //
                        //                            //                            let rightCons = NSLayoutConstraint(item: dotButton, attribute: .Trailing, relatedBy: .Equal, toItem: deleteButton, attribute: .Trailing, multiplier: 1.0, constant: spacing)
                        //
                        //                            let widthCons = NSLayoutConstraint(item: dotButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
                        //
                        //                            let heightCons = NSLayoutConstraint(item: dotButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                        //
                        //                            let leftCons = NSLayoutConstraint(item: dotButton, attribute: .leading, relatedBy: .equal, toItem: characterButton, attribute: .trailing, multiplier: 1.0, constant: spacing)
                        //
                        //                            dotButton.translatesAutoresizingMaskIntoConstraints = false;
                        //                            topCons.isActive = true;
                        //                            leftCons.isActive = true;
                        //                            heightCons.isActive = true;
                        //                            widthCons.isActive = true;
                        //                            //                            rightCons.active = true;
                        //                        }
                        
                        // Constraints for Delete Button
                        //                        if(  buttonIndex == 7 )
                        //                        {
                        // Add Constraint for Delete Button
//                        removeAllConstrains(deleteButton);
//
//                        let topConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .top, relatedBy: .equal, toItem: ACharBtn, attribute: .bottom, multiplier: 1.0, constant: spacing);
//
//                        let leftConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: spacing );
//
//                        let heightConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
//
//                        let rightConsShiftBtn = NSLayoutConstraint(item: deleteButton, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: -spacing)
//
//                        let widthConsShiftButton = NSLayoutConstraint(item: deleteButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth )
//
//                        deleteButton.translatesAutoresizingMaskIntoConstraints = false
//                        topConsShiftBtn.isActive = true;
//                        //                        leftConsShiftBtn.isActive = true;
//                        heightConsShiftBtn.isActive = true;
//                        rightConsShiftBtn.isActive = true;
//                        widthConsShiftButton.isActive = true
                        //                        }
                    }
                    
                }
                //self.view.addSubview(characterButton)
                //characterButtons[rowIndex].append(characterButton)
                x += keyWidth + spacing
            }
            y += keyHeight + spacing
        }
//        rowCount = 11.0
    }
    
    func updateConstraintForDelete() {
        removeAllConstrains(deleteButton)
        
        let topConsDeleteButton = NSLayoutConstraint(item: deleteButton, attribute: .top, relatedBy: .equal, toItem: arrayOfShortWordButton[1].last, attribute: .bottom, multiplier: 1.0, constant: spacing)
        
        let leftConsDeleteButton = NSLayoutConstraint(item: deleteButton, attribute: .leading, relatedBy: .equal, toItem: arrayOfNumberButton.last, attribute: .trailing, multiplier: 1.0, constant: spacing)
        
        let rightConsDeleteButton = NSLayoutConstraint(item: deleteButton, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: -spacing)
        
        let heightConsDeleteButton = NSLayoutConstraint(item: deleteButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsDeleteButton = NSLayoutConstraint(item: deleteButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)
        
        deleteButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsDeleteButton.isActive = true
        leftConsDeleteButton.isActive = true
        rightConsDeleteButton.isActive = true
//        widthConsDeleteButton.isActive = true
        heightConsDeleteButton.isActive = true
    }
    
    func updateConstraintForSpeceRow()
    {
        rowCount = 9.0
        // Add Constraints for Kaart Button
        removeAllConstrains(kaartKeyboardButton)

        let topConsKaartButton = NSLayoutConstraint(item: kaartKeyboardButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);

        let leftConsKaartButton = NSLayoutConstraint(item: kaartKeyboardButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: spacing );

        let heightConsKaartButton = NSLayoutConstraint(item: kaartKeyboardButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)

        let widthConsKaartButton = NSLayoutConstraint(item: kaartKeyboardButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)

        let rightConsKaartButton = NSLayoutConstraint(item: kaartKeyboardButton, attribute: .trailing, relatedBy: .equal, toItem: nextKeyboardButton, attribute: .leading, multiplier: 1.0, constant: -spacing)

        kaartKeyboardButton.translatesAutoresizingMaskIntoConstraints = false;

        topConsKaartButton.isActive = true
        leftConsKaartButton.isActive = true
        heightConsKaartButton.isActive = true
        widthConsKaartButton.isActive = true
        rightConsKaartButton.isActive = true
        
        // Add Constraints for Space Button
        removeAllConstrains(spaceButton);
        
        let topConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .leading, relatedBy: .equal, toItem: nextKeyboardButton, attribute: .trailing, multiplier: 1.0, constant: spacing );
        
        let heightConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let widthConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth * 5)
        
        let rightConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .trailing, relatedBy: .equal, toItem: returnButton, attribute: .leading, multiplier: 1.0, constant: -spacing)
        
        let bottomConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: -spacing)
        
        spaceButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsSpeceButton.isActive = true
        leftConsSpeceButton.isActive = true
        heightConsSpeceButton.isActive = true
//        widthConsSpeceButton.isActive = true
        rightConsSpeceButton.isActive = true
        bottomConsSpeceButton.isActive = true
        
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
        rowCount = 9.0
        let firstButton = arrayOfNumberButton[0];
        let shortWordBtn:KeyButton = arrayOfShortWordButton[1][0];

        for cons in firstButton.constraints{
            firstButton.removeConstraint(cons);
        }

        let topCons = NSLayoutConstraint(item: firstButton, attribute: .top, relatedBy: .equal, toItem: shortWordBtn, attribute: .bottom, multiplier: 1.0, constant: spacing);

        let leftCons = NSLayoutConstraint(item: firstButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: spacing );

        let heightCons = NSLayoutConstraint(item: firstButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)

        let widthCons = NSLayoutConstraint(item: firstButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth * 0.9)

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

            let widthCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth * 0.9)

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
        for (rowIndex, row) in arrayOfShortWordButton.enumerated() {
            for (i, button) in row.enumerated()
            {
                let shortWordButtonObj = button;
                removeAllConstrains(shortWordButtonObj)
                
                for cons in shortWordButtonObj.constraints{
                    shortWordButtonObj.removeConstraint(cons);
                }
                
                let topCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .top, relatedBy: .equal, toItem: rowIndex == 0 ? view : arrayOfShortWordButton[0][0], attribute: rowIndex == 0 ? .top : .bottom, multiplier: 1.0, constant: rowIndex == 0 ? 40 + spacing : spacing);
                
                let leftCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .leading, relatedBy: .equal, toItem: i == 0 ? view : row[i-1], attribute: i == 0 ? .leading : .trailing, multiplier: 1.0, constant: spacing );
                
                let heightCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                
                let widthCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: wordKeyWidth)
                
                shortWordButtonObj.translatesAutoresizingMaskIntoConstraints = false;
                topCons.isActive = true;
                leftCons.isActive = true;
                heightCons.isActive = true;
                widthCons.isActive = true;
                }
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
        updateConstraintForDelete()
        updateConstraintForPredictiveText()
        setUpHeightConstraint()
    }
    
    var lexicon:UILexicon!;
    let currentString:NSString = "";
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addNextKeyboardButton();
        addKaartKeyboardButton()
        addShortWordButton()
        addNumpadButton()
        addCharacterButtons()
        addShiftButton();
        addDeleteButton()
        addSpaceButton()
        addReturnButton()
        addPredictiveTextScrollView()
        
        shortWordTxtFld.isHidden = true
        shiftMode = .on
        
        self.requestSupplementaryLexicon { (lexObj) in
            self.lexicon = lexObj;
        }
    }
    
    override func loadView() {
        super.loadView()
        _showEnglish = (defaults?.bool(forKey: "english"))!
        _showGreek = (defaults?.bool(forKey: "greek"))!
        _showSerbianCyrillic = (defaults?.bool(forKey: "serbian-cyrillic"))!
        _showRomanian = (defaults?.bool(forKey: "romanian"))!
        _showMacedonian = (defaults?.bool(forKey: "macedonian"))!
        _showBulgarian = (defaults?.bool(forKey: "bulgarian"))!
        _showVietnamese = (defaults?.bool(forKey: "vietnamese"))!

        languages = []
    
        for (key, value) in showLanguages {
            if !value { continue }
            print(key, value)
            if let path = Bundle.main.path(forResource: key, ofType: "json") {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                    switch key {
                    case "english":
                        english = try? JSONDecoder().decode(Language.self, from: data)
                        languages.append(english)
                    case "greek":
                        greek = try? JSONDecoder().decode(Language.self, from: data)
                        languages.append(greek)
                    case "serbian-cyrillic":
                        serbian_cyrillic = try? JSONDecoder().decode(Language.self, from: data)
                        languages.append(serbian_cyrillic)
                    case "romanian":
                        romanian = try? JSONDecoder().decode(Language.self, from: data)
                        languages.append(romanian)
                    case "macedonian":
                        macedonian = try? JSONDecoder().decode(Language.self, from: data)
                        languages.append(macedonian)
                    case "bulgarian":
                        bulgarian = try? JSONDecoder().decode(Language.self, from: data)
                        languages.append(bulgarian)
                    case "vietnamese":
                        vietnamese = try? JSONDecoder().decode(Language.self, from: data)
                        languages.append(vietnamese)
                    default:
                        print("not a recognized language")
                    }
                } catch {

                }
            } else {
                print("FILE NOT FOUND")
            }
        }
        UserDefaults.standard.set(languages[0].title, forKey: "CURRENT_LANG")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        for (key, value) in showLanguages {
            if value != defaults?.bool(forKey: key) {
                print("YES")
                self.loadView()
                break
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        removeAllConstrains(nextKeyboardButton);
        
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        let nextKeyboardButtonLeftSideConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .leading,
            relatedBy: .equal,
            toItem: kaartKeyboardButton,
            attribute: .trailing,
            multiplier: 1.0,
            constant: spacing)
        
        let nextKeyboardButtonRightSideConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .trailing,
            relatedBy: .equal,
            toItem: spaceButton,
            attribute: .leading,
            multiplier: 1.0,
            constant: -spacing)
        
        let nextKeyboardButtonTopConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .top,
            relatedBy: .equal,
            toItem: shiftButton,
            attribute: .bottom,
            multiplier: 1.0,
            constant: spacing)
        
        let nextKeyboardButtonHeightConstraint = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: keyHeight)
        
        let widthConsNextKeyboardButton = NSLayoutConstraint(
            item: nextKeyboardButton,
            attribute: .width,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: keyWidth )
        
        view.addConstraints([
            nextKeyboardButtonLeftSideConstraint,
            nextKeyboardButtonTopConstraint,
            nextKeyboardButtonRightSideConstraint,
            nextKeyboardButtonHeightConstraint,
            widthConsNextKeyboardButton])
        
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        //shiftMode = .On
        self.setUpHeightConstraint()
        self.updateViewConstraints()
    }
    
    func setUpHeightConstraint() {
        let customHeight: CGFloat

        switch UIDevice.current.orientation {
        case .portrait, .portraitUpsideDown:
            customHeight = UIScreen.main.bounds.height / 2
        case .landscapeLeft, .landscapeRight:
            customHeight = UIScreen.main.bounds.height / 2 + 90
        default:
            return
        }
        
        
        
        if heightConstraint == nil {
            heightConstraint = NSLayoutConstraint(item: view,
                                                  attribute: .height,
                                                  relatedBy: .equal,
                                                  toItem: nil,
                                                  attribute: .notAnAttribute,
                                                  multiplier: 1,
                                                  constant: customHeight)
            heightConstraint.priority = UILayoutPriority.required
            
            view.addConstraint(heightConstraint)
        }
        else {
            heightConstraint.constant = customHeight
        }
    }
    
    // MARK: Event handlers
    // Shift Buttton Action(Uppercase, Lowercase disabled the Caps Mode)
    @objc func shiftButtonPressed(_ sender: KeyButton) {
        switch shiftMode {
        case .off:
            shiftMode = .on
        case .on:
            shiftMode = .off
        case .caps:
            shiftMode = .caps
        }
    }
    
    //
    @objc func deleteButtonPressed(_ sender: KeyButton) {
        
        if shortWordTxtFld.isHidden == true {
            //        switch proxy.documentContextBeforeInput {
            //        case let s where s?.hasSuffix("    ") == true: // Cursor in front of tab, so delete tab.
            //            for _ in 0..<4 { // TODO: Update to use tab setting.
            //                proxy.deleteBackward()
            //            }
            //        default:
            proxy.deleteBackward()
            //        }
//            updateSuggestions()
            
        }else{
            
            var tempStr : NSString = shortWordTxtFld.text! as NSString
            if shortWordTxtFld.text?.isEmpty == false  {
                tempStr = tempStr.substring(to: tempStr.length - 1) as NSString
                shortWordTxtFld.text = tempStr as String
            }
        }
        
    }
    
    var longPressStoped:Bool = false;
    
    @objc func startMoreDelete(_ timer: Timer)
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
    
    @objc func handleDeleteButtonLongPress(_ timer: Timer) {
        
        timer.invalidate();
        //timer = nil
        
        deleteButtonTimer?.invalidate()
        deleteButtonTimer = nil
        
        let longPressTime = Timer(timeInterval: 0.3, target: self, selector: #selector(KeyboardViewController.startMoreDelete(_:)), userInfo: nil, repeats: false);
        
        RunLoop.main.add(longPressTime, forMode: RunLoopMode.defaultRunLoopMode)
    }
    
    //Delete Button long press action
    @objc func handleLongPressForDeleteButtonWithGestureRecognizer(_ gestureRecognizer: UILongPressGestureRecognizer) {
        
        
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
//        updateSuggestions()
    }
    
    @objc func handleDeleteButtonTimerTick(_ timer: Timer) {
        proxy.deleteBackward()
    }
    
    @objc func spaceButtonPressed(_ sender: KeyButton) {
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
//        updateSuggestions()
    }
    
    // Input the character "ñ" instead of tab
    @objc func aapButtonPressed(_ sender: KeyButton) {
        
        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }
        proxy.insertText(sender.currentTitle!)
        shiftMode = .off
    }
    
    @objc func eepButtonPressed(_ sender: KeyButton){
        
        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }
        
        proxy.insertText(sender.currentTitle!)
        shiftMode = .off
    }
    
    @objc func iipButtonPressed(_ sender: KeyButton){
        
        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }
        
        proxy.insertText(sender.currentTitle!)
        shiftMode = .off
    }
    
    @objc func uupButtonPressed(_ sender: KeyButton){
        
        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }
        
        proxy.insertText(sender.currentTitle!)
        shiftMode = .off
    }
    
    // When the numpadButton is pressed
    @objc func numpadButtonPressed(_ sender: KeyButton){
        
        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }
        
        proxy.insertText(sender.currentTitle!)
    }
    
    // When the shortWordButton is pressed
    @objc func shortWordButtonPressed(_ sender: KeyButton){
            if updateShortField((sender.titleLabel?.text)!) == true{
                return
            }
            proxy.insertText(sender.currentTitle! + " ")
            shiftMode = .on
    }
    
    
    // When the dotButton is pressed
    @objc func dotButtonPressed(_ sender: KeyButton){
        
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
//            updateSuggestions()
        }
    }
    
    @objc func handleSpaceButtonTimerTick(_ timer: Timer) {
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
    
    @objc func returnButtonPressed(_ sender: KeyButton) {
        
        let senderStr : String = "\n"
        
        if updateShortField(senderStr) == true{
            return
        }
        
        proxy.insertText(senderStr)
        shiftMode = .on
//        updateSuggestions()
        
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
//        updateSuggestions()
    }
    
    func handleLongPressForButton(_ button: CharacterButton) {
        if button.tertiaryCharacters.isEmpty { return }
        
        var y = button.frame.minY - (keyHeight + spacing)
        var x: CGFloat = button.frame.minX
        if CGFloat(button.tertiaryCharacters.count/3 + 1 ) * keyWidth + x > self.view.bounds.size.width {
            x = button.frame.minX - (CGFloat(button.tertiaryCharacters.count/3) * keyWidth )
        }
        let xO = x
        var i = 0
        for tert in button.tertiaryCharacters.reversed() {
            if i > 4 {
                y+=keyHeight
                x = xO
                i = 0
            }
            else {
                i += 1
            }
            let key = KeyButton(frame: CGRect(x: x, y: y, width: keyWidth, height: keyHeight))
            key.setBackgroundImage(UIImage.fromColor(UIColor.lightGray), for: UIControlState())
            switch shiftMode {
            case .off:
                key.setTitle(tert.lowercased(), for: UIControlState())
            case .on, .caps:
                key.setTitle(tert.uppercased(), for: UIControlState())
            }
            key.addTarget(self, action: #selector(handleTertiaryPress(_:)), for: .touchUpInside)
            self.view.addSubview(key)
            tertiaryButtons.append(key)
            x += keyWidth
        }
        let close = KeyButton(frame: CGRect(x: x, y: y, width: keyWidth, height: keyHeight))
        close.setTitle("X", for: UIControlState())
        close.setBackgroundImage(UIImage.fromColor(UIColor.red), for:UIControlState())
        close.layer.borderWidth = 2
        close.layer.borderColor = UIColor.black.cgColor
        close.addTarget(self, action: #selector(handleClosePress(_:)), for: .touchUpInside)
        self.view.addSubview(close)
        tertiaryButtons.append(close)
    }
    
    @objc func handleTertiaryPress(_ sender: KeyButton) {
        let charStr = sender.titleLabel?.text
        if updateShortField(charStr!) == true{
            shiftMode = .off
            for btn in tertiaryButtons {
                btn.removeFromSuperview()
            }
            tertiaryButtons = []
            return
        }
        proxy.insertText(charStr!)
        shiftMode = .off
        for btn in tertiaryButtons {
            btn.removeFromSuperview()
        }
        tertiaryButtons = []
    }
    
    @objc func handleKaartKeyboardPress(_ sender: KeyButton) {
        if languages.count < 2 { print("NO"); return}
        for (i, lang) in languages.enumerated() {
            if lang.title == currentLanguage.title {
                UserDefaults.standard.set(languages[ (i + 1) <= languages.count - 1 ? i + 1 : 0 ].title, forKey: "CURRENT_LANG")
                break
            }
        }
        addCharacterButtons()
        addSpaceButton()
        shiftMode = .on
        self.updateViewConstraints()
    }
    
    @objc func handleClosePress(_ sender: KeyButton) {
        for btn in tertiaryButtons {
            btn.removeFromSuperview()
        }
        tertiaryButtons = []
    }
    
    func handleSwipeUpForButton(_ button: CharacterButton) {
//        updateSuggestions()
    }
    
    func handleSwipeDownForButton(_ button: CharacterButton) {
        let charStr = button.secondaryCharacter
        if updateShortField(charStr) == true{
            return
        }
        proxy.insertText(charStr)
        if button.secondaryCharacter.characters.count > 1 {
            proxy.insertText(" ")
        }
//        updateSuggestions()
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
        
        addNextKeyboardButton();
        addKaartKeyboardButton()
        addShortWordButton()
        addCharacterButtons()
        addShiftButton();
        addDeleteButton()
        addSpaceButton()
        addNumpadButton()
        addReturnButton()
        addPredictiveTextScrollView()
        
        shortWordTxtFld.isHidden = true
        shiftMode = .on

        
        self.requestSupplementaryLexicon { (lexObj) in
            self.lexicon = lexObj;
        }
        
    }
    
    fileprivate func addPredictiveTextScrollView() {
        predictiveTextScrollView = PredictiveTextScrollView(frame: CGRect(x: 0.0, y: 0.0, width: self.view.frame.width, height: predictiveTextBoxHeight))
        self.view.addSubview(predictiveTextScrollView)
    }
    
    fileprivate func addShiftButton() {
        shiftButton = KeyButton(frame: CGRect(x: spacing, y: keyHeight * 4.0 + spacing * 5.0, width: keyWidth, height: keyHeight))
        shiftButton.setTitle("\u{000021E7}", for: UIControlState())
        shiftButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: UIControlState())
        shiftButton.addTarget(self, action: #selector(KeyboardViewController.shiftButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(shiftButton)
    }
    
    fileprivate func addDeleteButton() {
        deleteButton = KeyButton(frame: CGRect(x: keyWidth * 8.5 + spacing * 9.5, y: keyHeight * 2.0 + spacing * 5.0, width: keyWidth * 1.5 + spacing / 2, height: keyHeight))
        deleteButton.setTitle("\u{232B}", for: UIControlState())
        deleteButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: UIControlState())
        deleteButton.addTarget(self, action: #selector(KeyboardViewController.deleteButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(deleteButton)
        
        let deleteButtonLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(KeyboardViewController.handleLongPressForDeleteButtonWithGestureRecognizer(_:)))
        deleteButton.addGestureRecognizer(deleteButtonLongPressGestureRecognizer)
        
    }
    
    fileprivate func addNextKeyboardButton() {
        nextKeyboardButton = KeyButton(frame: CGRect(x: keyWidth * 4 + spacing * 5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth / 2, height: keyHeight))
        nextKeyboardButton.setTitle("\u{1F310}", for: UIControlState())
        nextKeyboardButton.setTitleColor(UIColor.black, for: UIControlState())
        nextKeyboardButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: UIControlState())
        if #available(iOS 10.0, *) {
            nextKeyboardButton.addTarget(self, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        } else {
            nextKeyboardButton.addTarget(self, action: #selector(UIInputViewController.advanceToNextInputMode), for: .touchUpInside)
        }
        self.view.addSubview(nextKeyboardButton)
    }
    
    fileprivate func addKaartKeyboardButton() {
        kaartKeyboardButton = KeyButton(frame: CGRect(x: keyWidth * 3 + spacing * 5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth / 2, height: keyHeight))
        kaartKeyboardButton.setImage(UIImage(named: "Kaart_Keyboard.png"), for: UIControlState())
//        kaartKeyboardButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: UIControlState())
        kaartKeyboardButton.imageView?.contentMode = .scaleAspectFit
        kaartKeyboardButton.addTarget(self, action: #selector(handleKaartKeyboardPress(_:)), for: .touchUpInside)
        self.view.addSubview(kaartKeyboardButton)
    }
    
    fileprivate func addSpaceButton() {
        spaceButton = KeyButton(frame: CGRect(x: keyWidth * 5 + spacing * 8.5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth * 5 + spacing * 1.5, height: keyHeight))
        spaceButton.setTitle(spaceTitle, for: UIControlState())
        spaceButton.addTarget(self, action: #selector(KeyboardViewController.spaceButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(spaceButton)
        
    }
    
    fileprivate func addReturnButton() {
        returnButton = KeyButton(frame: CGRect(x: keyWidth * 8.5 + spacing * 9.5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth * 1.5 + spacing / 2, height: keyHeight))
        returnButton.setTitle("\u{000023CE}", for: UIControlState())
        returnButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: UIControlState())
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
        
        for (rowIndex, row) in currentLanguage.rows.enumerated() {
            
            
            var x: CGFloat = 0
            switch rowIndex {
            case 1:
                rowCount = CGFloat(row.row.count)
                x = spacing * 1.5 + keyWidth * 0.5
            case 2:
                rowCount = CGFloat(row.row.count + 1)
                x = spacing * 2.5 + keyWidth * 1.5
            default:
                rowCount = CGFloat(row.row.count)
                x = spacing
            }
            for char in row.row {
                let characterButton = CharacterButton(frame: CGRect(x: x, y: y, width: keyWidth, height: keyHeight), primaryCharacter: char.primary.lowercased(), secondaryCharacter: char.secondary, tertiaryCharacters: char.tertiary, delegate: self)
                self.view.addSubview(characterButton)
                characterButtons[rowIndex].append(characterButton)
                x += keyWidth + spacing
            }
            y += keyHeight + spacing
        }
//        rowCount = 11.0
    }
    
    @objc func doubleTapCharacterButton(_ gesture:UIGestureRecognizer){
        if(isSecondary){
            isSecondary=false
            
            //            let button = gesture.view as? CharacterButton
            //            let press : UILongPressGestureRecognizer = UILongPressGestureRecognizer.init(target: self, action: #selector(self.longPressCharacterButton(_:)))
            //            press.minimumPressDuration = 0.3
            //            button?.addGestureRecognizer(press)
            //            button?.removeGestureRecognizer(gesture)
            
            //            let button = gesture.view as? CharacterButton
            //            button?.removeGestureRecognizer(gesture)
            
            //            secondaryIsActive.removeGestureRecognizer(gesture)
            
            for item in secondaryToShow{
                item.isHidden = true
            }
            //            for item in arrayOfShortWordButton{
            //                item.isHidden = false
            //            }
            self.addShortWordButton()
        }
    }
    
    
    fileprivate func addShortWordButton(){
        
        let userDefaults : UserDefaults = UserDefaults.standard
        
        if ((userDefaults.object(forKey: "SHORT_WORD_ARR")) != nil){
            shortWord = userDefaults.object(forKey: "SHORT_WORD_ARR")! as! [[String]]
        }
        
        for (rowIndex, row) in shortWord.enumerated(){
            var y: CGFloat = 0.0
            for index in 1...row.count{
                shortWordButton = KeyButton(frame: CGRect(x: spacing * CGFloat(index) + wordKeyWidth * CGFloat(index-1), y: y, width: wordKeyWidth, height: keyHeight))
                shortWordButton.setTitle(shortWord[rowIndex][index - 1], for: UIControlState())
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
                arrayOfShortWordButton[rowIndex].append(shortWordButton)
            }
            y += keyHeight + spacing
        }
    }
    
    @objc func longPressShortWord(_ gesture:UILongPressGestureRecognizer)  {
        
        selectedShortWordBtn.layer.borderWidth = 0.0
        selectedShortWordBtn.layer.borderColor = UIColor.clear.cgColor
        
        predictiveTextScrollView.isHidden = true
        
        selectedShortWordBtn = gesture.view as! UIButton
        selectedShortWordBtn.layer.borderWidth = 3.0
        selectedShortWordBtn.layer.borderColor = UIColor.white.cgColor
        addShortWordTxtFld()
    }
    
    var selectedShortWordBtn :UIButton = UIButton.init()
    
    var shortWordTxtFld : UITextField = UITextField.init()
    
    //    let inputAccessory: UIView = {
    //        let inputAccessoryView = UIView(frame: )
    //        inputAccessoryView.backgroundColor = UIColor.lightGray
    //        inputAccessoryView.alpha = 0.6
    //        return inputAccessoryView
    //    }()
    
    // MARK: Short Word method
    
    func addShortWordTxtFld(){
        
        var tempRct: CGRect = predictiveTextScrollView.frame
        
        tempRct.size.width = tempRct.size.width - keyWidth - 3*spacing
        
        tempRct.origin.x =  spacing
        
        self.shortWordTxtFld.removeFromSuperview()
        
        self.shortWordTxtFld = UITextField.init(frame: tempRct)
        
        self.shortWordTxtFld.backgroundColor = UIColor.lightGray
        
        let gesture : UILongPressGestureRecognizer = UILongPressGestureRecognizer.init(target: self, action: #selector(self.pasteShortWord(_:)))
        gesture.minimumPressDuration = 0.4
        self.shortWordTxtFld.addGestureRecognizer(gesture)
        
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
        
        shiftMode = .on
    }
    
    @objc func pasteShortWord(_ gesture:UILongPressGestureRecognizer){
        if gesture.state == .began{
            self.shortWordTxtFld.text?.append(UIPasteboard.general.string!)
        }
    }
    
    var doneBtn:KeyButton = KeyButton.init(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    
    @objc func doneSelect(_ btn:UIButton){
        
        let newStr : String = (shortWordTxtFld.text?.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
            ))!
        
        if newStr.isEmpty == false {
            
            let oldTitle : String = (selectedShortWordBtn.titleLabel?.text)!
            
            for (rowIndex, row) in shortWord.enumerated() {
            
            if row.contains(oldTitle){
                let index : NSInteger = row.firstIndex(of: oldTitle)!
                shortWord[rowIndex][index] = newStr
                
                let defaults : UserDefaults = UserDefaults.standard
                defaults.set(shortWord, forKey: "SHORT_WORD_ARR")
                defaults.synchronize()
            }
            }
            selectedShortWordBtn.setTitle(newStr, for: UIControlState())
        }
        shortWordTxtFld.isHidden = true
        doneBtn.isHidden = true
        predictiveTextScrollView.isHidden = false
        
        
        shortWordTxtFld.removeFromSuperview()
        
        self.removeFromParentViewController()
//        self.viewDidLoad()
//        self.initializeKeyboard()
//        self.updateViewConstraints()
        
        selectedShortWordBtn.layer.borderWidth = 0.0
        selectedShortWordBtn.layer.borderColor = UIColor.clear.cgColor
        
    }
    
    //    let doneButton: UIButton = {
    //        let doneButton = UIButton(type: .custom)
    //        doneButton.setTitle("Done", for: UIControlState())
    //        doneButton.setTitleColor(UIColor.green, for: UIControlState.normal)
    //        doneButton.addTarget(self, action: #selector(self.doneSelect(_:)), for: .touchUpInside)
    //        doneButton.showsTouchWhenHighlighted = true
    //        return doneButton
    //    }()
    
    func updateShortField(_ senderStr : String) -> Bool {
        if shortWordTxtFld.isHidden == false {
            var tmepStr : NSString = shortWordTxtFld.text! as NSString
            tmepStr = tmepStr.appending(senderStr) as NSString
            shortWordTxtFld.text = tmepStr as String
            if isSecondary{
                isSecondary=false
                for item in secondaryToShow{
                    item.isHidden=true
                }
                for row in arrayOfShortWordButton{
                    for item in row {
                        item.isHidden=false
                    }
                }
            }
            return true
        }else{
            return false
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
            rowCount = 9.0
            numpadButton = KeyButton(frame: CGRect(x: spacing * CGFloat(index) + keyWidth * CGFloat(index-1), y: spacing + keyHeight, width: keyWidth/12, height: keyHeight))
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
