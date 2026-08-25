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
    
    // Two groups of 12 presets, laid out 6 to a row. Both preset rows are still seven columns
    // wide; the seventh column of each is a control key rather than a preset -- preset-group
    // swap on the top row, numeral swap on the bottom -- which is why 6 and not 7.
    fileprivate let presetColumns = 6
    fileprivate var shortWordBanks: [[[String]]] = [
        [
            ["Press &","Hold","To","Edit","A","Preset"],
            ["Tap","Top","Right","To","Swap","Groups"]
        ],
        [
            ["This Is","Group","2","Same","Editing","Rules"],
            ["Bottom","Right","Swaps","1-9,0","And","I-X"]
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
    
    fileprivate var isSecondary:Bool = false
    
    fileprivate var secondaryTap : UIGestureRecognizer!
    
    fileprivate var secondaryChar:String = ""
    
    fileprivate var secondaryToShow : [KeyButton] = []
    
    // Optional rather than trapping on languages[0]: loadView guarantees a non-empty list
    // in every reachable case, but a nil here degrades to "draw no keys" instead of killing
    // the extension if that ever stops being true.
    fileprivate var currentLanguage: Language? {
        let currLang = UserDefaults.standard.string(forKey: "CURRENT_LANG")
        for lang in languages {
            if lang.title == currLang { return lang }
        }
        return languages.first
    }
    
    fileprivate var _showEnglish : Bool = false
    fileprivate var _showGreek: Bool = false
    fileprivate var _showSerbianCyrillic: Bool = false
    fileprivate var _showRomanian: Bool = false
    fileprivate var _showMacedonian: Bool = false
    fileprivate var _showBulgarian: Bool = false
    fileprivate var _showVietnamese: Bool = false

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
    
    // Ten number keys spanning the full width: eleven gutters, one at each end and nine between.
    // Not derived from keyWidth, which is tied to rowCount and would drift as the character rows
    // reassign it, and which the number row used to be shrunk to 0.9 of so it could line up with
    // the eleven-slot QWERTY row above the numeral toggle that used to sit at its right end.
    fileprivate var numberKeyWidth: CGFloat {
        return (view.frame.width - 11 * spacing) / 10.0
    }
    
    //Height of individual keys
    fileprivate var keyHeight: CGFloat {
        return (keyboardHeight - 7.0 * spacing - predictiveTextBoxHeight) / 6.5
    }
    
    // The height the input view actually needs, as opposed to keyboardHeight, which only feeds
    // keyHeight above and understates the total: that divisor is 6.5 while the layout places
    // seven full rows. Read off the constraints rather than re-derived -- the first preset row
    // is pinned 40 + spacing from the top (the predictive strip sits inside that band), then
    // seven rows of keyHeight separated by spacing gutters, then a spacing bottom margin.
    // Measured against the laid-out hierarchy on an iPad Pro 11-inch: the lowest key's bottom
    // edge lands at 485.5pt, and this returns 490.3.
    fileprivate var contentHeight: CGFloat {
        let rows: CGFloat = 7.0
        return 40.0 + spacing + rows * keyHeight + (rows - 1) * spacing + spacing
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
    /// Seventh column of the top preset row: swaps which preset group is on screen.
    fileprivate var presetGroupSwapButton: KeyButton!
    /// Seventh column of the bottom preset row: swaps the number row between 1-9,0 and I-X.
    fileprivate var numeralSwapButton: KeyButton!
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
        return UserDefaults.standard.string(forKey: "CURRENT_LANG")?.uppercased()
            ?? currentLanguage?.title.uppercased() ?? ""
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
    
    // Column seven of each preset row. Pinned to the row's last preset on the left and to the
    // view's trailing margin on the right, so the pair absorbs any rounding left over by the six
    // fixed-width presets rather than leaving a ragged right edge.
    func updateConstraintForPresetControls() {
        guard arrayOfShortWordButton.count == 2,
              let lastTopPreset = arrayOfShortWordButton[0].last,
              let lastBottomPreset = arrayOfShortWordButton[1].last,
              let groupSwap = presetGroupSwapButton,
              let numeralSwap = numeralSwapButton else { return }

        for (button, rowLeader) in [(groupSwap, lastTopPreset), (numeralSwap, lastBottomPreset)] {
            removeAllConstrains(button)
            button.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint(item: button, attribute: .top, relatedBy: .equal, toItem: rowLeader, attribute: .top, multiplier: 1.0, constant: 0).isActive = true
            NSLayoutConstraint(item: button, attribute: .leading, relatedBy: .equal, toItem: rowLeader, attribute: .trailing, multiplier: 1.0, constant: spacing).isActive = true
            NSLayoutConstraint(item: button, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: -spacing).isActive = true
            NSLayoutConstraint(item: button, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight).isActive = true
        }
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

        let widthCons = NSLayoutConstraint(item: firstButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: numberKeyWidth)

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

            let widthCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: numberKeyWidth)

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
        updateConstraintForPresetControls()
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
        addPresetControlButtons()
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
        // `defaults` is nil if the app group is unavailable, so read through it rather
        // than force-unwrapping: a missing suite should mean "no languages selected",
        // not a crash before the view exists.
        _showEnglish = defaults?.bool(forKey: "english") ?? false
        _showGreek = defaults?.bool(forKey: "greek") ?? false
        _showSerbianCyrillic = defaults?.bool(forKey: "serbian-cyrillic") ?? false
        _showRomanian = defaults?.bool(forKey: "romanian") ?? false
        _showMacedonian = defaults?.bool(forKey: "macedonian") ?? false
        _showBulgarian = defaults?.bool(forKey: "bulgarian") ?? false
        _showVietnamese = defaults?.bool(forKey: "vietnamese") ?? false

        languages = showLanguages.filter { $0.value }.keys.sorted().compactMap(loadLanguage)

        // A fresh install has every language switched off, and the keyboard has no UI of
        // its own for turning one on -- that lives in the container app. Rather than come
        // up with an empty language list (which used to trap on languages[0] below), fall
        // back to English so the keyboard is usable out of the box.
        if languages.isEmpty, let fallback = loadLanguage(named: "english") {
            languages = [fallback]
        }

        if let first = languages.first {
            UserDefaults.standard.set(first.title, forKey: "CURRENT_LANG")
        }
    }

    /// Decodes one bundled language definition, returning nil if it is missing or malformed
    /// rather than substituting a nil into `languages`.
    fileprivate func loadLanguage(named key: String) -> Language? {
        guard let path = Bundle.main.path(forResource: key, ofType: "json") else {
            print("language file not found: \(key).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            return try JSONDecoder().decode(Language.self, from: data)
        } catch {
            print("could not decode \(key).json: \(error)")
            return nil
        }
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
        // Ask the layout how tall it is instead of guessing from the screen.
        //
        // This used to switch on UIDevice.current.orientation, which is normally .unknown in
        // an extension (the process gets no device-orientation notifications), and fell
        // through to an early return that never installed the constraint at all, clipping the
        // bottom rows off the screen. Replacing that with UIScreen.main.bounds.height / 2 was
        // unrelated to what the layout needs and left the view taller than its content --
        // 115pt of dead space below the return key in portrait. keyboardHeight is not the
        // answer either: it feeds a 6.5 divisor while seven rows are laid out, so it is ~45pt
        // short and clips the bottom row. contentHeight is the constraints' own arithmetic.
        let customHeight = contentHeight

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
        
        // Capitalise the first letter of every word. Deliberate since 877a1c7 (2017): what
        // gets typed here are OSM name values -- "Main Street", "Piata Unirii" -- where every
        // word is capitalised. This supersedes the active LanguageProvider's
        // autocapitalizeAfter sentence-ender list rather than consulting it, so there is no
        // condition to evaluate and no documentContextBeforeInput to unwrap.
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
    
    // Swaps the number row between Arabic and Roman numerals.
    @objc func numeralSwapPressed(_ sender: KeyButton){
        isRomanNumerals = !isRomanNumerals
        updateNumeralTitles()
    }
    
    // Swaps which preset group fills the twelve preset keys.
    @objc func presetGroupSwapPressed(_ sender: KeyButton){
        // Not while a preset is being edited: the pending edit is addressed by position within the
        // active group, so swapping groups would land it on the group that just arrived.
        guard shortWordTxtFld.isHidden else { return }
        activeBank = (activeBank + 1) % shortWordBanks.count
        updateShortWordTitles()
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
            if lang.title == currentLanguage?.title {
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
        addPresetControlButtons()
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
        // U+2B06 is the filled counterpart of the hollow U+21E7 this used to use. U+FE0E is
        // VARIATION SELECTOR-15, which asks for text presentation -- without it iOS renders
        // U+2B06 as a colour emoji rather than a monochrome glyph.
        shiftButton.setTitle("\u{2B06}\u{FE0E}", for: .normal)
        // 15% smaller than the other glyph keys, and proportionally so -- a smaller font
        // rather than a vertical scale, which squashed the arrow out of its proportions.
        shiftButton.useGlyphTitleFont(size: KeyButton.shiftTitleFontSize)
        shiftButton.setTitleColor(UIColor.white, for: .normal)
        shiftButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: .normal)
        shiftButton.addTarget(self, action: #selector(KeyboardViewController.shiftButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(shiftButton)
    }
    
    fileprivate func addDeleteButton() {
        deleteButton = KeyButton(frame: CGRect(x: view.frame.width - keyWidth - spacing, y: spacing * 3 + keyHeight * 2, width: keyWidth, height: keyHeight))
        deleteButton.setTitle("\u{232B}", for: .normal)
        deleteButton.useGlyphTitleFont(size: KeyButton.backspaceTitleFontSize)
        deleteButton.setTitleColor(UIColor.white, for: .normal)
        deleteButton.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: .normal)
        deleteButton.addTarget(self, action: #selector(KeyboardViewController.deleteButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(deleteButton)
        
        let deleteButtonLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(KeyboardViewController.handleLongPressForDeleteButtonWithGestureRecognizer(_:)))
        deleteButton.addGestureRecognizer(deleteButtonLongPressGestureRecognizer)
        
    }
    
    fileprivate func addNextKeyboardButton() {
        nextKeyboardButton = KeyButton(frame: CGRect(x: keyWidth * 4 + spacing * 5, y: keyHeight * 5.0 + spacing * 6.0, width: keyWidth / 2, height: keyHeight))
        nextKeyboardButton.setTitle("\u{1F310}", for: .normal)
        nextKeyboardButton.useGlyphTitleFont(size: KeyButton.globeTitleFontSize)
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
        returnButton.useGlyphTitleFont(size: KeyButton.returnTitleFontSize)
        returnButton.setTitleColor(UIColor.white, for: .normal)
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
        
        guard let language = currentLanguage else { return }
        for (rowIndex, row) in language.rows.enumerated() {
            
            
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
        
        // Presets saved by an earlier version have seven to a row, because the seventh column was
        // a preset before it became a control key. Keep the first six of each row rather than
        // throwing the lot away; a row too short to fill the grid falls back to that row's
        // defaults, as a malformed value always has.
        for (bank, key) in shortWordKeys.enumerated() {
            guard let saved = userDefaults.object(forKey: key) as? [[String]],
                  saved.count == shortWordBanks[bank].count else { continue }
            var migrated = shortWordBanks[bank]
            for (rowIndex, row) in saved.enumerated() where row.count >= presetColumns {
                migrated[rowIndex] = Array(row.prefix(presetColumns))
            }
            shortWordBanks[bank] = migrated
        }
        
        for (rowIndex, row) in shortWord.enumerated(){
            var y: CGFloat = 0.0
            for index in 1...row.count{
                shortWordButton = KeyButton(frame: CGRect(x: spacing * CGFloat(index) + wordKeyWidth * CGFloat(index-1), y: y, width: wordKeyWidth, height: keyHeight))
                shortWordButton.setTitle(shortWord[rowIndex][index - 1], for: .normal)
                shortWordButton.setTitleColor(UIColor(white: 245.0/255, alpha: 1.0), for: .normal)
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
            
            // 148 sits between the 122 of the preset keys and the 168 this used to be, so the
            // number row still reads as the lighter of the two rows.
            numpadButton.setBackgroundImage(UIImage.fromColor(UIColor(red: 148.0/255, green: 148.0/255, blue: 148.0/255, alpha: 1.0)), for: .normal)
            numpadButton.setBackgroundImage(UIImage.fromColor(UIColor.black), for: .selected)
            
            //numpadButton.setBackgroundImage(gradient.UIImageFromCALayer(), forState: .Normal)
            
            numpadButton.addTarget(self, action: #selector(KeyboardViewController.numpadButtonPressed(_:)), for: .touchUpInside)
            self.view.addSubview(numpadButton)
            arrayOfNumberButton.append(numpadButton);
        }
        updateNumeralTitles()
    }
    
    // The two control keys that occupy the seventh column of the preset rows. They replace the
    // single two-line toggle that used to sit at the right end of the number row and carry both
    // jobs -- tap for numerals, long press for preset groups. One key per job means the
    // long-press popup that disambiguated them is gone too, along with NumeralToggleButton.
    fileprivate func addPresetControlButtons() {
        presetGroupSwapButton?.removeFromSuperview()
        numeralSwapButton?.removeFromSuperview()

        presetGroupSwapButton = makePresetControlButton(
            title: "P1/2",
            action: #selector(KeyboardViewController.presetGroupSwapPressed(_:)))
        numeralSwapButton = makePresetControlButton(
            title: "Numerals",
            action: #selector(KeyboardViewController.numeralSwapPressed(_:)))
    }

    fileprivate func makePresetControlButton(title: String, action: Selector) -> KeyButton {
        let button = KeyButton(frame: CGRect(x: view.frame.width - wordKeyWidth - spacing,
                                            y: 40 + spacing,
                                            width: wordKeyWidth,
                                            height: keyHeight))
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor.black, for: .normal)
        button.setBackgroundImage(UIImage.fromColor(UIColor.gray), for: .normal)
        button.setBackgroundImage(UIImage.fromColor(UIColor.black), for: .selected)
        button.addTarget(self, action: action, for: .touchUpInside)
        self.view.addSubview(button)
        return button
    }
    
    /// Repaints the 12 visible presets from the active group. No views or constraints change.
    fileprivate func updateShortWordTitles() {
        let bank = shortWord
        for (rowIndex, row) in arrayOfShortWordButton.enumerated() where rowIndex < bank.count {
            for (index, button) in row.enumerated() where index < bank[rowIndex].count {
                button.setTitle(bank[rowIndex][index], for: .normal)
            }
        }
    }
    
    // Swaps the number row between 1-9,0 and I-X. The control key is labelled "Numerals" rather
    // than with either plane, so the active plane is read off the number row itself.
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
