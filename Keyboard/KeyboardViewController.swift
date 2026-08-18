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
    
    // Two groups of 14 presets. The layout still shows 14 at a time; long-pressing the numeral
    // toggle opens a popup that swaps which group is on screen.
    fileprivate var shortWordBanks: [[[String]]] = [
        [
            ["Press &","Hold","To","Edit","These","Presets","!"],
            ["Press", "The", "Kaart", "Keyboard", "Logo", "To Switch", "Languages"]
        ],
        [
            ["This Is","Group","2","Long","Press","IV","To Swap"],
            ["Edit", "These", "The", "Same", "Way", "As", "Group 1"]
        ]
    ]
    
    /// Group 1 keeps the original key so presets saved by earlier versions survive the upgrade.
    fileprivate let shortWordKeys = ["SHORT_WORD_ARR", "SHORT_WORD_ARR_GROUP_2"]
    
    fileprivate var activeBank = 0
    
    /// The group currently on screen. Reads and writes pass through to shortWordBanks, so every
    /// existing use of shortWord keeps working and edits land in the group being displayed.
    fileprivate var shortWord: [[String]] {
        get { return shortWordBanks[activeBank] }
        set { shortWordBanks[activeBank] = newValue }
    }
    
    // Capitalise the first letter of every word. Set to false to capitalise only after the
    // contexts listed in the active LanguageProvider's autocapitalizeAfter (sentence enders).
    fileprivate let capitalizeAfterEverySpace = true
    
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
    
    fileprivate let spacing: CGFloat = KeyButton.gutter
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
    fileprivate var numeralToggleButton: KeyButton!
    fileprivate var numeralPopupButtons: [KeyButton] = []
    fileprivate var isRomanNumerals: Bool = false
    fileprivate let arabicNumerals = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    fileprivate let romanNumerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
    
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
    
    // Delete now sits at the end of the first character row, immediately right of "P".
    func updateConstraintForDelete() {
        guard let deleteButton = deleteButton, let lastTopRowKey = characterButtons[0].last else { return }
        removeAllConstrains(deleteButton)
        
        let topCons = NSLayoutConstraint(item: deleteButton, attribute: .top, relatedBy: .equal, toItem: lastTopRowKey, attribute: .top, multiplier: 1.0, constant: 0)
        
        let leftCons = NSLayoutConstraint(item: deleteButton, attribute: .leading, relatedBy: .equal, toItem: lastTopRowKey, attribute: .trailing, multiplier: 1.0, constant: spacing)
        
        let rightCons = NSLayoutConstraint(item: deleteButton, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: -spacing)
        
        let heightCons = NSLayoutConstraint(item: deleteButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        topCons.isActive = true
        leftCons.isActive = true
        rightCons.isActive = true
        heightCons.isActive = true
    }
    
    // The numeral toggle takes the number-row slot that delete used to occupy.
    func updateConstraintForNumeralToggle() {
        guard let toggle = numeralToggleButton,
              let lastNumberButton = arrayOfNumberButton.last,
              let shortWordAbove = arrayOfShortWordButton[1].last else { return }
        removeAllConstrains(toggle)
        
        let topCons = NSLayoutConstraint(item: toggle, attribute: .top, relatedBy: .equal, toItem: shortWordAbove, attribute: .bottom, multiplier: 1.0, constant: spacing)
        
        let leftCons = NSLayoutConstraint(item: toggle, attribute: .leading, relatedBy: .equal, toItem: lastNumberButton, attribute: .trailing, multiplier: 1.0, constant: spacing)
        
        let rightCons = NSLayoutConstraint(item: toggle, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: -spacing)
        
        let heightCons = NSLayoutConstraint(item: toggle, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        toggle.translatesAutoresizingMaskIntoConstraints = false
        
        topCons.isActive = true
        leftCons.isActive = true
        rightCons.isActive = true
        heightCons.isActive = true
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
        // bottomConsSpeceButton stays inactive: top + height + bottom cannot all hold, so
        // activating it guarantees Auto Layout breaks one of them at runtime.
//        bottomConsSpeceButton.isActive = true
        
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
        updateConstraintForNumeralToggle()
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
        addNumeralToggleButton()
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
        
        // Capitalise the next letter. capitalizeAfterEverySpace does it for every word;
        // autocapitalizeAfter adds the contexts that should capitalise regardless of that flag.
        var capitalizeNext = capitalizeAfterEverySpace
        if let contextBeforeSpace = proxy.documentContextBeforeInput {
            for suffix in languageProvider.autocapitalizeAfter where contextBeforeSpace.hasSuffix(suffix) {
                capitalizeNext = true
            }
        }
        if capitalizeNext {
            shiftMode = .on
        }
        
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
    
    // Toggles the number row between Arabic and Roman numerals.
    @objc func numeralToggleButtonPressed(_ sender: KeyButton){
        if !numeralPopupButtons.isEmpty {   // the popup has no close key, so a tap here dismisses it
            dismissNumeralPopup()
            return
        }
        isRomanNumerals = !isRomanNumerals
        updateNumeralTitles()
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
        // The first popup row holds 5 accents and every row after it holds 6, with the close key
        // able to follow a full row. Worst case is therefore 7 key widths.
        let slotsNeeded = button.tertiaryCharacters.count <= 5 ? button.tertiaryCharacters.count + 1 : 7
        let popupWidth = CGFloat(slotsNeeded) * keyWidth
        if x + popupWidth > self.view.bounds.size.width {
            x = max(spacing, self.view.bounds.size.width - popupWidth)
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
            key.touchOutset = 0
            key.setBackgroundImage(UIImage.fromColor(UIColor.lightGray), for: .normal)
            switch shiftMode {
            case .off:
                key.setTitle(tert.lowercased(), for: .normal)
            case .on, .caps:
                key.setTitle(tert.uppercased(), for: .normal)
            }
            key.addTarget(self, action: #selector(handleTertiaryPress(_:)), for: .touchUpInside)
            self.view.addSubview(key)
            tertiaryButtons.append(key)
            x += keyWidth
        }
        let close = KeyButton(frame: CGRect(x: x, y: y, width: keyWidth, height: keyHeight))
        close.touchOutset = 0
        close.setTitle("X", for: .normal)
        close.setBackgroundImage(UIImage.fromColor(UIColor.red), for: .normal)
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
        addNumeralToggleButton()
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
        shiftButton.setTitle("\u{000021E7}", for: .normal)
        shiftButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: .normal)
        shiftButton.addTarget(self, action: #selector(KeyboardViewController.shiftButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(shiftButton)
    }
    
    fileprivate func addDeleteButton() {
        deleteButton = KeyButton(frame: CGRect(x: view.frame.width - keyWidth - spacing, y: spacing * 3 + keyHeight * 2, width: keyWidth, height: keyHeight))
        deleteButton.setTitle("\u{232B}", for: .normal)
        deleteButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: .normal)
        deleteButton.addTarget(self, action: #selector(KeyboardViewController.deleteButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(deleteButton)
        
        let deleteButtonLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(KeyboardViewController.handleLongPressForDeleteButtonWithGestureRecognizer(_:)))
        deleteButton.addGestureRecognizer(deleteButtonLongPressGestureRecognizer)
        
    }
    
    fileprivate func addNextKeyboardButton() {
        nextKeyboardButton = KeyButton(frame: CGRect(x: keyWidth * 4 + spacing * 5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth / 2, height: keyHeight))
        nextKeyboardButton.setTitle("\u{1F310}", for: .normal)
        nextKeyboardButton.setTitleColor(UIColor.black, for: .normal)
        nextKeyboardButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: .normal)
        if #available(iOS 10.0, *) {
            nextKeyboardButton.addTarget(self, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        } else {
            nextKeyboardButton.addTarget(self, action: #selector(UIInputViewController.advanceToNextInputMode), for: .touchUpInside)
        }
        self.view.addSubview(nextKeyboardButton)
    }
    
    fileprivate func addKaartKeyboardButton() {
        kaartKeyboardButton = KeyButton(frame: CGRect(x: keyWidth * 3 + spacing * 5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth / 2, height: keyHeight))
        kaartKeyboardButton.setImage(UIImage(named: "Kaart_Keyboard.png"), for: .normal)
//        kaartKeyboardButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: UIControlState())
        kaartKeyboardButton.imageView?.contentMode = .scaleAspectFit
        kaartKeyboardButton.addTarget(self, action: #selector(handleKaartKeyboardPress(_:)), for: .touchUpInside)
        self.view.addSubview(kaartKeyboardButton)
    }
    
    fileprivate func addSpaceButton() {
        spaceButton?.removeFromSuperview()
        spaceButton = KeyButton(frame: CGRect(x: keyWidth * 5 + spacing * 8.5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth * 5 + spacing * 1.5, height: keyHeight))
        spaceButton.setTitle(spaceTitle, for: .normal)
        spaceButton.addTarget(self, action: #selector(KeyboardViewController.spaceButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(spaceButton)
        
    }
    
    fileprivate func addReturnButton() {
        returnButton = KeyButton(frame: CGRect(x: keyWidth * 8.5 + spacing * 9.5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth * 1.5 + spacing / 2, height: keyHeight))
        returnButton.setTitle("\u{000023CE}", for: .normal)
        returnButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: .normal)
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
        
        for row in arrayOfShortWordButton {
            for button in row { button.removeFromSuperview() }
        }
        arrayOfShortWordButton = [[],[]]
        
        let userDefaults : UserDefaults = UserDefaults.standard
        
        for (bank, key) in shortWordKeys.enumerated() {
            guard let saved = userDefaults.object(forKey: key) as? [[String]],
                  saved.count == shortWordBanks[bank].count else { continue }
            shortWordBanks[bank] = saved
        }
        
        for (rowIndex, row) in shortWord.enumerated(){
            var y: CGFloat = 0.0
            for index in 1...row.count{
                shortWordButton = KeyButton(frame: CGRect(x: spacing * CGFloat(index) + wordKeyWidth * CGFloat(index-1), y: y, width: wordKeyWidth, height: keyHeight))
                shortWordButton.setTitle(shortWord[rowIndex][index - 1], for: .normal)
                shortWordButton.setTitleColor(UIColor(white: 245.0/245, alpha: 1.0), for: .normal)
                let gradient = CAGradientLayer()
                gradient.frame = self.shortWordButton.bounds
                let gradientColors: [AnyObject] = [UIColor(red: 70.0/255, green: 70.0/255, blue: 70.0/255, alpha: 40.0).cgColor, UIColor(red: 60.0/255, green: 60.0/255, blue: 60.0/255, alpha: 1.0).cgColor]
                gradient.colors = gradientColors // Declaration broken into two lines to prevent 'unable to bridge to Objective C' error.
                
                shortWordButton.setBackgroundImage(UIImage.fromColor(UIColor(red: 122.0/255, green: 122.0/255, blue: 122.0/255, alpha: 1.0)), for: .normal)
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
        
        // Remember where the pressed key sits, not what it says. Titles are user-editable and can
        // repeat, so they cannot identify a preset.
        selectedShortWordIndex = nil
        for (rowIndex, row) in arrayOfShortWordButton.enumerated() {
            if let column = row.firstIndex(where: { $0 === selectedShortWordBtn }) {
                selectedShortWordIndex = (rowIndex, column)
                break
            }
        }
        
        addShortWordTxtFld()
    }
    
    var selectedShortWordBtn :UIButton = UIButton.init()
    
    /// Row and column of the preset being edited, within the active group.
    fileprivate var selectedShortWordIndex: (row: Int, column: Int)?
    
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
        
        doneBtn.setTitle("Done", for: .normal)
        doneBtn.setBackgroundImage(UIImage.fromColor(UIColor.white), for: .normal)
        
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
        
        let newStr = shortWordTxtFld.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        
        if let target = selectedShortWordIndex, newStr.isEmpty == false,
           target.row < shortWord.count, target.column < shortWord[target.row].count {
            
            shortWord[target.row][target.column] = newStr
            
            let defaults : UserDefaults = UserDefaults.standard
            defaults.set(shortWord, forKey: shortWordKeys[activeBank])
            defaults.synchronize()
            
            arrayOfShortWordButton[target.row][target.column].setTitle(newStr, for: .normal)
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
        selectedShortWordIndex = nil
        
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
        for button in arrayOfNumberButton { button.removeFromSuperview() }
        arrayOfNumberButton = []
        
        for index in 1...10{
            rowCount = 9.0
            numpadButton = KeyButton(frame: CGRect(x: spacing * CGFloat(index) + keyWidth * CGFloat(index-1), y: spacing + keyHeight, width: keyWidth/12, height: keyHeight))
            numpadButton.setTitle(arabicNumerals[index - 1], for: .normal)
            numpadButton.setTitleColor(UIColor(white: 245.0/255, alpha: 1.0), for: .normal)
            let gradient = CAGradientLayer()
            gradient.frame = self.shortWordButton.bounds
            let gradientColors: [AnyObject] = [UIColor(red: 70.0/255, green: 70.0/255, blue: 70.0/255, alpha: 40.0).cgColor, UIColor(red: 60.0/255, green: 60.0/255, blue: 60.0/255, alpha: 1.0).cgColor]
            gradient.colors = gradientColors // Declaration broken into two lines to prevent 'unable to bridge to Objective C' error.
            
            numpadButton.setBackgroundImage(UIImage.fromColor(UIColor(red: 168.0/255, green: 168.0/255, blue: 168.0/255, alpha: 1.0)), for: .normal)
            numpadButton.setBackgroundImage(UIImage.fromColor(UIColor.black), for: .selected)
            
            //numpadButton.setBackgroundImage(gradient.UIImageFromCALayer(), forState: .Normal)
            
            numpadButton.addTarget(self, action: #selector(KeyboardViewController.numpadButtonPressed(_:)), for: .touchUpInside)
            self.view.addSubview(numpadButton)
            arrayOfNumberButton.append(numpadButton);
        }
        updateNumeralTitles()
    }
    
    fileprivate func addNumeralToggleButton() {
        numeralToggleButton?.removeFromSuperview()
        numeralToggleButton = NumeralToggleButton(frame: CGRect(x: view.frame.width - keyWidth - spacing, y: spacing + keyHeight, width: keyWidth, height: keyHeight))
        numeralToggleButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: .normal)
        numeralToggleButton.addTarget(self, action: #selector(KeyboardViewController.numeralToggleButtonPressed(_:)), for: .touchUpInside)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(KeyboardViewController.handleLongPressForNumeralToggle(_:)))
        longPress.minimumPressDuration = 0.3
        numeralToggleButton.addGestureRecognizer(longPress)
        
        self.view.addSubview(numeralToggleButton)
        updateNumeralTitles()
    }
    
    // MARK: Preset group popup
    
    /// Opens above the numeral toggle, one key wide. Its only job for now is swapping preset groups.
    @objc func handleLongPressForNumeralToggle(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began, let toggle = numeralToggleButton else { return }
        
        if !numeralPopupButtons.isEmpty {
            dismissNumeralPopup()
            return
        }
        
        // Not while a preset is being edited: the pending edit is addressed by position within the
        // active group, so swapping groups would land it on the group that just arrived.
        guard shortWordTxtFld.isHidden else { return }
        
        let frame = CGRect(x: toggle.frame.minX,
                           y: toggle.frame.minY - (keyHeight + spacing),
                           width: toggle.frame.width,
                           height: keyHeight)
        let groupButton = KeyButton(frame: frame)
        groupButton.touchOutset = 0
        groupButton.setTitle(presetGroupTitle, for: .normal)
        groupButton.setBackgroundImage(UIImage.fromColor(UIColor.lightGray), for: .normal)
        groupButton.layer.borderWidth = 1
        groupButton.layer.borderColor = UIColor.darkGray.cgColor
        groupButton.addTarget(self, action: #selector(KeyboardViewController.presetGroupButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(groupButton)
        numeralPopupButtons.append(groupButton)
    }
    
    @objc func presetGroupButtonPressed(_ sender: KeyButton) {
        activeBank = (activeBank + 1) % shortWordBanks.count
        updateShortWordTitles()
        dismissNumeralPopup()
    }
    
    fileprivate func dismissNumeralPopup() {
        for button in numeralPopupButtons {
            button.removeFromSuperview()
        }
        numeralPopupButtons = []
    }
    
    /// Titled with the group it will switch to, like the numeral toggle itself.
    fileprivate var presetGroupTitle: String {
        return "P\((activeBank + 2 > shortWordBanks.count) ? 1 : activeBank + 2)"
    }
    
    /// Repaints the 14 visible presets from the active group. No views or constraints change.
    fileprivate func updateShortWordTitles() {
        let bank = shortWord
        for (rowIndex, row) in arrayOfShortWordButton.enumerated() where rowIndex < bank.count {
            for (index, button) in row.enumerated() where index < bank[rowIndex].count {
                button.setTitle(bank[rowIndex][index], for: .normal)
            }
        }
    }
    
    // Swaps the number row between 1-9,0 and I-X. The toggle itself carries a fixed two-line
    // legend, so the active plane is read off the number row rather than off the key.
    fileprivate func updateNumeralTitles() {
        let titles = isRomanNumerals ? romanNumerals : arabicNumerals
        for (index, button) in arrayOfNumberButton.enumerated() where index < titles.count {
            button.setTitle(titles[index], for: .normal)
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
