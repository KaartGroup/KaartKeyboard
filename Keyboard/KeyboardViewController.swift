//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Kari Kraam on 2016-04-20.
//  Copyright (c) 2017 Kaart Group, LLC. All rights reserved.
//

import Foundation
import UIKit
import os.log

/// Where the keyboard's own diagnostics go.
///
/// `print()` writes to stdout, and an extension has no stdout unless a debugger is attached, so
/// every message below was invisible in the field: a language file the layout could not use
/// degraded silently. os_log reaches Console.app and `log stream` on a device with nothing
/// attached. OSLog rather than the newer Logger, which needs iOS 14 -- the deployment target is 12.
///
/// The subsystem is the shared prefix rather than the extension's own bundle identifier, so one
/// predicate follows the keyboard and the container app together.
private let keyboardLog = OSLog(subsystem: "com.kaartgroup.KaartKeyboard", category: "keyboard")


/**
 An iOS custom keyboard extension written in Swift designed to make it much, much easier to type code on an iOS device.
 */
class KeyboardViewController: UIInputViewController, CharacterButtonDelegate, SuggestionButtonDelegate {
    
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

    /// The enabled languages in the order the keyboard offers them: English first, then the rest
    /// alphabetically.
    ///
    /// The order is not cosmetic. The globe key cycles through `languages` in this order, and
    /// `languages.first` is the language a keyboard opens in, so putting English at the head is
    /// what makes English the default. A plain sort put Bulgarian there.
    ///
    /// Derived from showLanguages rather than written out as a second list of its own, so a
    /// language added above lands in alphabetical position without anyone having to remember to
    /// add it here too. Sorting the tail separately, instead of with a comparator that special
    /// cases English, keeps this free of the strict-weak-ordering rules a custom comparator has
    /// to obey.
    fileprivate var orderedLanguageKeys: [String] {
        let enabled = showLanguages.filter { $0.value }.keys
        return enabled.filter { $0 == "english" } + enabled.filter { $0 != "english" }.sorted()
    }
    
    lazy var suggestionProvider: SuggestionProvider = SuggestionTrie()
    
    lazy var languageProviders = CircularArray(items: [DefaultLanguageProvider(), SwiftLanguageProvider()] as [LanguageProvider])
    
    fileprivate let spacing: CGFloat = KeyButton.gutter
    fileprivate let predictiveTextBoxHeight: CGFloat = 24.0

    /// Never negative, whatever the view's width happens to be.
    ///
    /// Every width below divides the view's width, and `view.frame` is (0, 0, 0, 0) throughout
    /// viewDidLoad -- the input view has not been sized yet -- which made each of them negative:
    /// keyWidth came out at -5.5. The keys are built at these sizes and then positioned by
    /// constraints, so the placeholder never showed, but UIKit spent the whole launch laying out
    /// and drawing buttons whose size had a negative component, which is where the thirty
    /// "CGAffineTransformInvert: singular matrix" errors per launch came from.
    ///
    /// Note this is not visible through CGRect.width, which standardises and reports the absolute
    /// value; it is CGRect.size.width that goes negative.
    fileprivate static func nonNegative(_ width: CGFloat) -> CGFloat {
        return max(0, width)
    }

    fileprivate var predictiveTextButtonWidth: CGFloat {
        return KeyboardViewController.nonNegative((view.frame.width - 4 * spacing) / 3.0)
    }
    fileprivate var keyboardHeight: CGFloat {
        if(UIScreen.main.bounds.width < UIScreen.main.bounds.height ){
            return 440
        }
        else{
            return 410
        }
    }
    
    /// Width of a letter key in a character row holding `keyCount` of them.
    ///
    /// A character row is laid out on a grid of one more slot than it has keys: the spare slot is
    /// delete at the end of the top row and shift at the start of the bottom one. Rows differ --
    /// English is 10/9/9 and Macedonian 11/11/9 -- so this width is a property of the row rather
    /// than of the keyboard.
    ///
    /// It used to read a stored `rowCount` that each row overwrote with its own key count as it was
    /// laid out. Every reader outside that loop -- the space row, the number row, the accent popup,
    /// the buttons built in viewDidLoad -- therefore got whichever row happened to be laid out
    /// last, and three functions had to assign 9.0 back before they could trust their own widths.
    /// Passing the count in leaves nothing to reset and nothing to leak.
    fileprivate func keyWidth(inRowOf keyCount: Int) -> CGFloat {
        let keys = CGFloat(keyCount)
        return KeyboardViewController.nonNegative((view.frame.width - (keys + 2) * spacing) / (keys + 1))
    }

    /// The grid everything that is not a character row is sized against: the space row, the number
    /// row, the accent popup, and the keys built before a language has been laid out. Nine is what
    /// the old stored default and all three of those resets amounted to, so the widths are
    /// unchanged.
    fileprivate static let standardRowKeyCount = 9

    // Width of individual letter keys, on the standard grid.
    fileprivate var keyWidth: CGFloat {
        return keyWidth(inRowOf: KeyboardViewController.standardRowKeyCount)
    }
    
    // The width a preset row's seven columns would each get if they were all equal.
    fileprivate var wordKeyWidth: CGFloat {
        return KeyboardViewController.nonNegative((view.frame.width - 8 * spacing) / 7.0)
    }

    // The two control keys carry a short label and do not need a preset's width. They match the
    // number keys instead, which lines them up exactly with the 0 key: both end at the view's
    // trailing margin, so equal widths put them in the same column.
    fileprivate var controlKeyWidth: CGFloat {
        return numberKeyWidth
    }

    // What the six presets in a row each get once the control key has taken its number-key column.
    // The controls are constrained between the last preset and the view's trailing margin rather
    // than given a width, so this is the number that actually sizes them: widening the presets is
    // what squeezes the controls.
    fileprivate var presetKeyWidth: CGFloat {
        return KeyboardViewController.nonNegative((view.frame.width - 8 * spacing - controlKeyWidth) / 6.0)
    }
    
    // Ten number keys spanning the full width: eleven gutters, one at each end and nine between.
    // Not derived from keyWidth, which is tied to a character row's key count, and which the
    // number row used to be shrunk to 0.9 of so it could line up with
    // the eleven-slot QWERTY row above the numeral toggle that used to sit at its right end.
    fileprivate var numberKeyWidth: CGFloat {
        return KeyboardViewController.nonNegative((view.frame.width - 11 * spacing) / 10.0)
    }
    
    /// The number of key rows the keyboard lays out: two of presets, the numbers, three of
    /// characters, and the space row.
    fileprivate let rowCountVertical: CGFloat = 7.0

    /// Height of individual keys. The same whether or not a preset is being renamed: the band
    /// takes its room from the keyboard's height, not from the rows.
    fileprivate var keyHeight: CGFloat {
        return (keyboardHeight - 7.0 * spacing - predictiveTextBoxHeight) / 6.5
    }

    /// The height the input view asks for: seven rows at their full height, plus the rename band
    /// when it is open. The keyboard grows at the top to make room for the editor and gives the
    /// height straight back on Done.
    fileprivate var contentHeight: CGFloat {
        return predictiveTextBandHeight + 8 * spacing + rowCountVertical * keyHeight
    }

    // True only while a preset is being renamed. Drives the band below, so the keyboard gives the
    // editor room for exactly as long as it is on screen.
    fileprivate var isRenamingPreset: Bool = false

    /// Height of the rename editor itself. A text field and a Done key do not need a full key row,
    /// and every point here is one the seven rows give up, so it is kept to what the editor reads
    /// comfortably at -- close to the 30pt the predictive strip used to be.
    fileprivate let presetEditFieldHeight: CGFloat = 36.0

    // The band between the system bar and the first preset row.
    //
    // Nothing lives there at rest: the predictive / recent text strip it used to hold never had
    // anything to show, every updateSuggestions() call site being commented out, so the band is 0
    // and the presets sit straight below the system bar. Renaming a preset opens it, and the seven
    // rows below give up the height for it, so the editor gets a line of its own without the
    // keyboard having to grow, without covering the presets and without pushing the bottom row off
    // the screen.
    fileprivate var predictiveTextBandHeight: CGFloat {
        return isRenamingPreset ? presetEditFieldHeight + spacing : 0.0
    }

    // Where the preset editor's text field and Done button go: the band the rename just opened,
    // with the gutter below it separating the editor from the first preset row.
    fileprivate var shortWordEditRect: CGRect {
        return CGRect(x: spacing,
                      y: spacing,
                      width: view.frame.width - 2 * spacing,
                      height: presetEditFieldHeight)
    }
    
    // MARK: User interface
    
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
    
    /// Slate-and-cream palette, matched against a reference mockup. Each constant names the
    /// element it fills rather than a point on a grey scale, since the mockup uses distinct hues
    /// rather than one shade lightened or darkened.
    fileprivate static let keyboardBackground = UIColor(red: 44.0/255, green: 58.0/255, blue: 70.0/255, alpha: 1.0)
    fileprivate static let shiftKeyFill = UIColor(red: 207.0/255, green: 162.0/255, blue: 76.0/255, alpha: 1.0)
    /// A rust red-orange for delete, in the same warm register as the shift key's gold.
    fileprivate static let deleteKeyFill = UIColor(red: 181.0/255, green: 79.0/255, blue: 56.0/255, alpha: 1.0)

    /// The number row's slate blue, and the fill shift, delete and return used to share before
    /// each took its own colour from the mockup.
    fileprivate let midKeyFill = UIColor(red: 112.0/255, green: 132.0/255, blue: 154.0/255, alpha: 1.0)

    /// The two fills the control keys alternate between, so the key's shade shows its state.
    fileprivate let controlKeyFillPrimary = UIColor(red: 124.0/255, green: 140.0/255, blue: 140.0/255, alpha: 1.0)
    /// Darker and cooler than the primary so the active state reads as a toggle, not a highlight.
    fileprivate let controlKeyFillAlternate = UIColor(red: 53.0/255, green: 80.0/255, blue: 90.0/255, alpha: 1.0)

    fileprivate let presetKeyFill = UIColor(red: 76.0/255, green: 104.0/255, blue: 112.0/255, alpha: 1.0)
    
    /// The Arabic digits are single glyphs and carry 4pt more than the 20 every other titled key
    /// uses. The Roman numerals stay at 20: VIII is four glyphs wide and gains nothing from it.
    fileprivate let arabicNumeralFontSize: CGFloat = 24.0
    
    /// Shift shows a hollow arrow when it is off and a filled one when it is armed, so the key
    /// reports whether the next letter will be capitalised. SF Symbols' arrowshape.up /
    /// arrowshape.up.fill are an outline/fill pair sharing one silhouette, unlike the Unicode
    /// glyphs U+21E7 and U+2B06 below -- which are drawn as different arrow shapes -- so on
    /// iOS 13+ (the deployment target is 12.0) the outline state traces the same shape the
    /// filled state fills in. iOS 12 keeps the old mismatched pair as a fallback.
    fileprivate let shiftGlyphOutlineSymbolName = "arrowshape.up"
    fileprivate let shiftGlyphFilledSymbolName = "arrowshape.up.fill"
    fileprivate let shiftGlyphOutlineFallback = "\u{21E7}"
    fileprivate let shiftGlyphFilledFallback = "\u{2B06}\u{FE0E}"
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
    
    /// Repeats a single backspace while delete is held.
    fileprivate var deleteButtonTimer: Timer?

    /// The one pending one-shot in the delete key's chain: first the hand-over from character
    /// repeat to word deletion, then each word delete scheduling the next. Only ever one at a time,
    /// and held rather than dropped so releasing the key can cancel it.
    fileprivate var deleteFollowUpTimer: Timer?


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
        guard let context = proxy.documentContextBeforeInput,
              let last = context.last, KeyboardViewController.isLetter(last) else { return nil }
        return String(context.reversed().prefix(while: KeyboardViewController.isLetter).reversed())
    }

    /// Whether a character is a letter / whitespace, judged by its first Unicode scalar.
    ///
    /// The keyboard used to ask these questions of a UTF-16 code unit, via
    /// `UnicodeScalar(_: UInt16)` on the last unit of the text before the cursor. That
    /// initialiser is failable and returns nil for a surrogate, and the call sites force
    /// unwrapped it -- so the trailing surrogate of any non-BMP character (every emoji) trapped.
    /// Asking a Character instead means the question is always answerable.
    ///
    /// Swift 4 has no Character.isLetter, hence the scalar lookup rather than the one-liner.
    fileprivate static func isLetter(_ character: Character) -> Bool {
        guard let scalar = String(character).unicodeScalars.first else { return false }
        return CharacterSet.letters.contains(scalar)
    }

    fileprivate static func isWhitespace(_ character: Character) -> Bool {
        guard let scalar = String(character).unicodeScalars.first else { return false }
        return CharacterSet.whitespaces.contains(scalar)
    }

    /// How many characters a backwards delete should remove to take out the run before the
    /// cursor: a whole word when the cursor sits after a letter, the whole run of spaces when it
    /// sits after whitespace, and a single character otherwise.
    ///
    /// Counted in Characters, not UTF-16 units, because that is what deleteBackward() removes per
    /// call. The old count was in UTF-16 units, so a word containing an emoji or any other
    /// non-BMP character deleted more than the word.
    fileprivate func charactersToDeleteBackward(from context: String) -> Int {
        guard let last = context.last else { return 0 }
        if KeyboardViewController.isLetter(last) {
            return context.reversed().prefix(while: KeyboardViewController.isLetter).count
        }
        if KeyboardViewController.isWhitespace(last) {
            return context.reversed().prefix(while: KeyboardViewController.isWhitespace).count
        }
        return 1
    }

    fileprivate var languageProvider: LanguageProvider = DefaultLanguageProvider() {
        didSet {
            for (rowIndex, row) in characterButtons.enumerated() {
                for (characterButtonIndex, characterButton) in row.enumerated() {
                    characterButton.secondaryCharacter = languageProvider.secondaryCharacters[rowIndex][characterButtonIndex]
                    //                    characterButton.tertiaryCharacters = languageProvider.tertiaryCharacters[rowIndex][characterButtonIndex]
                }
            }
            // Optional. currentLanguageLabel is declared but never built -- the space bar carries
            // the language name instead -- so this was a nil unwrap waiting for the first
            // assignment to languageProvider, which nothing makes today.
            currentLanguageLabel?.text = languageProvider.language
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
            updateShiftGlyph()
            for row in characterButtons {
                for characterButton in row {
                    switch shiftMode {
                    case .off:
                        characterButton.primaryLabel.text = characterButton.primaryCharacter.lowercased()
                        characterButton.refreshCornerGlyph(uppercase: false)
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
                        characterButton.refreshCornerGlyph(uppercase: true)
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
        }
    }
    
    
    /// Places the three character rows, and the shift key that fills the slot the bottom row
    /// leaves free at the margin.
    ///
    /// Every key in every row takes the same four constraints -- pinned under the row above, a
    /// leading, its row's key width, and the shared key height -- and rows differ only in what
    /// they hang off and how far in the first key starts. That was written out four times, once
    /// per (row, first-key-or-not) case at about fifty lines each, with the two commented-out
    /// blocks for a dot key and a delete key that no longer live here folded in among them. The
    /// differences are now the six lines of the switch below.
    func updateConstraintForCharacter()
    {
        // Nothing to hang the character rows off yet. Reached before the number row exists, or
        // after a language with no usable rows left the grid empty; either way this used to be an
        // index-out-of-range rather than a layout pass that does nothing.
        guard let firstNumberBtn = arrayOfNumberButton.first,
              let shiftButton = shiftButton,
              characterButtons.contains(where: { $0.isEmpty == false }) else { return }

        for (rowIndex, row) in characterButtons.enumerated() {
            let rowKeyWidth = keyWidth(inRowOf: row.count)

            // What this row hangs off, and where its first key starts.
            //
            // Row 0 sits under the number row and begins at the margin; row 1 is inset by half a
            // key; row 2 by a whole key and two gutters, which is the slot shift fills. Each row
            // is anchored to the first key of the row above rather than to a running y, so the
            // rows stay stacked whatever height they are given.
            //
            // Row 2's inset is not the `spacing * 2.5 + rowKeyWidth * 1.5` that the old local `x`
            // computed here -- that value was dead for this row, which read the expression below
            // instead, and the two are 41pt apart at a real key width. The frames built in
            // addCharacterButtons() still use the dead one; the constraint is what positions the
            // key, so this is the value that has always applied.
            let rowTopAnchor: UIView
            let rowLeadingInset: CGFloat
            switch rowIndex {
            case 0:
                rowTopAnchor = firstNumberBtn
                rowLeadingInset = spacing
            case 1:
                // Guarded rather than indexed: a language whose first row is empty would trap.
                guard let qKey = characterButtons[0].first else { continue }
                rowTopAnchor = qKey
                rowLeadingInset = spacing * 1.5 + rowKeyWidth * 0.5
            default:
                guard let aKey = characterButtons[1].first else { continue }
                rowTopAnchor = aKey
                rowLeadingInset = rowKeyWidth + spacing * 2
            }

            for (buttonIndex, characterButton) in row.enumerated() {
                constrainKey(characterButton,
                             under: rowTopAnchor,
                             after: buttonIndex == 0 ? nil : row[buttonIndex - 1],
                             leadingInset: rowLeadingInset,
                             width: rowKeyWidth)

                // Shift takes the slot at the start of the bottom row, on that row's grid. Built
                // with the row it belongs to, and -- as before -- only when the row has a key,
                // since it is that key's anchor shift shares.
                if rowIndex == 2 && buttonIndex == 0 {
                    constrainKey(shiftButton,
                                 under: rowTopAnchor,
                                 after: nil,
                                 leadingInset: spacing,
                                 width: rowKeyWidth)
                }
            }
        }
    }

    /// One key of a character row: pinned a gutter under the row above, placed either at the row's
    /// leading inset or a gutter after its neighbour, at the row's key width and the shared height.
    fileprivate func constrainKey(_ key: UIView, under topAnchor: UIView, after previous: UIView?, leadingInset: CGFloat, width: CGFloat) {
        removeAllConstrains(key)
        key.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint(item: key, attribute: .top, relatedBy: .equal, toItem: topAnchor, attribute: .bottom, multiplier: 1.0, constant: spacing).isActive = true

        if let previous = previous {
            NSLayoutConstraint(item: key, attribute: .leading, relatedBy: .equal, toItem: previous, attribute: .trailing, multiplier: 1.0, constant: spacing).isActive = true
        } else {
            NSLayoutConstraint(item: key, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: leadingInset).isActive = true
        }

        NSLayoutConstraint(item: key, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight).isActive = true

        NSLayoutConstraint(item: key, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: width).isActive = true
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
        // Bound to non-optional locals that shadow the properties. These are `KeyButton!`, and
        // NSLayoutConstraint takes its items as `Any` -- so passing one straight through hands Auto
        // Layout a boxed Optional instead of the view when it happens to be nil, rather than
        // failing. Swift 5 warns about exactly that; a guard answers the warning and the underlying
        // hazard at once.
        guard let kaartKeyboardButton = kaartKeyboardButton,
              let nextKeyboardButton = nextKeyboardButton,
              let spaceButton = spaceButton,
              let returnButton = returnButton,
              let shiftButton = shiftButton else { return }

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

        // Add Constraints for the globe (next keyboard) button.
        //
        // These used to be built in viewDidAppear instead, which runs once per appearance and
        // never again -- so the globe was the one key in the row updateViewConstraints() did not
        // reach. Its width is a constant computed from keyWidth, and rotating the device changes
        // keyWidth (77.9pt to 115.5pt on an 11" iPad), so the globe kept its portrait width in
        // landscape while every key around it took its new one. The row still filled the width,
        // because the space bar has no width of its own and absorbs whatever is left, so the
        // error showed up as a narrow globe and an over-wide space bar rather than as a gap.
        //
        // It belongs here: this function already owns the rest of the bottom row, and already
        // hangs the kaart key and the space bar off this button.
        removeAllConstrains(nextKeyboardButton)

        let topConsNextKeyboardButton = NSLayoutConstraint(item: nextKeyboardButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing)

        let leftConsNextKeyboardButton = NSLayoutConstraint(item: nextKeyboardButton, attribute: .leading, relatedBy: .equal, toItem: kaartKeyboardButton, attribute: .trailing, multiplier: 1.0, constant: spacing)

        let rightConsNextKeyboardButton = NSLayoutConstraint(item: nextKeyboardButton, attribute: .trailing, relatedBy: .equal, toItem: spaceButton, attribute: .leading, multiplier: 1.0, constant: -spacing)

        let heightConsNextKeyboardButton = NSLayoutConstraint(item: nextKeyboardButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)

        let widthConsNextKeyboardButton = NSLayoutConstraint(item: nextKeyboardButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyWidth)

        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false

        topConsNextKeyboardButton.isActive = true
        leftConsNextKeyboardButton.isActive = true
        rightConsNextKeyboardButton.isActive = true
        heightConsNextKeyboardButton.isActive = true
        widthConsNextKeyboardButton.isActive = true

        // Add Constraints for Space Button
        removeAllConstrains(spaceButton);
        
        let topConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .top, relatedBy: .equal, toItem: shiftButton, attribute: .bottom, multiplier: 1.0, constant: spacing);
        
        let leftConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .leading, relatedBy: .equal, toItem: nextKeyboardButton, attribute: .trailing, multiplier: 1.0, constant: spacing );
        
        let heightConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
        
        let rightConsSpeceButton = NSLayoutConstraint(item: spaceButton, attribute: .trailing, relatedBy: .equal, toItem: returnButton, attribute: .leading, multiplier: 1.0, constant: -spacing)
        
        spaceButton.translatesAutoresizingMaskIntoConstraints = false;
        
        topConsSpeceButton.isActive = true
        leftConsSpeceButton.isActive = true
        heightConsSpeceButton.isActive = true
        rightConsSpeceButton.isActive = true
        // No bottom constraint on the space row, and no explicit width. Top + height + bottom
        // cannot all hold at once, so pinning the bottom guarantees Auto Layout breaks one of them
        // at runtime. It was briefly pinned, paired with a first-preset-row top constraint relaxed
        // to 999 to make room for it -- but that relaxation is what let the system skip the rename
        // band's height, so the pair went back out. The rows keep their full height and the
        // keyboard grows instead. The width comes from the leading and trailing constraints.
        
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
    
    /// Clears the constraints that place `inputView`, so the caller can rebuild them at the
    /// current size.
    ///
    /// A constraint between two views is owned by their nearest common ancestor, not by either
    /// view, so `inputView.constraints` holds only the width and height it pins on itself --
    /// never the leading and top that position it in the keyboard. Removing just those left every
    /// relayout stacking a second leading constraint on the superview, and Auto Layout was free to
    /// satisfy the stale one: after a rotation the shift key took its new, wider width while Z
    /// kept its portrait leading, and the two overlapped.
    func removeAllConstrains(_ inputView:UIView)
    {
        if let parent = inputView.superview {
            // Only the constraints that position this view. Ones where it is the second item
            // position some other view against it, and that view clears its own before it is
            // rebuilt.
            parent.removeConstraints(parent.constraints.filter { ($0.firstItem as? UIView) === inputView })
        }
        inputView.removeConstraints(inputView.constraints)
    }
    func updateConstraintForNumberButton()
    {
        // The number row hangs off the second preset row. Both are built in viewDidLoad before this
        // runs, but reading them positionally is what turns a build-order change into a crash.
        guard let firstButton = arrayOfNumberButton.first,
              arrayOfShortWordButton.count > 1,
              let shortWordBtn = arrayOfShortWordButton[1].first else { return }

        removeAllConstrains(firstButton)

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

            removeAllConstrains(shortWordButtonObj)

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

                let topCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .top, relatedBy: .equal, toItem: rowIndex == 0 ? view : arrayOfShortWordButton[0][0], attribute: rowIndex == 0 ? .top : .bottom, multiplier: 1.0, constant: rowIndex == 0 ? predictiveTextBandHeight + spacing : spacing);

                // Left required. This is the constraint that makes the rename band real: every
                // other row chains off it, so it is what tells the system the keyboard needs the
                // extra height. Dropping it below required made the band optional, and the system
                // duly sized the input view without it -- the keyboard stayed short and the editor
                // came down on top of the presets.
                
                let leftCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .leading, relatedBy: .equal, toItem: i == 0 ? view : row[i-1], attribute: i == 0 ? .leading : .trailing, multiplier: 1.0, constant: spacing );
                
                let heightCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: keyHeight)
                
                let widthCons = NSLayoutConstraint(item: shortWordButtonObj, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: presetKeyWidth)
                
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
        guard let predictiveTextScrollView = predictiveTextScrollView else { return }

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

        view.backgroundColor = KeyboardViewController.keyboardBackground

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
        reloadLanguages()
    }

    /// Re-reads which languages are switched on and decodes them, returning whether the set
    /// changed. Safe to call at any point in the lifecycle.
    ///
    /// This used to be the body of loadView(), and viewWillAppear called loadView() directly to
    /// pick up a change made in the container app. loadView()'s job is to create the view:
    /// calling it a second time runs super.loadView(), which hands back a fresh empty view and
    /// leaves every button property pointing at an orphan with no superview. The next
    /// updateViewConstraints() then activates constraints between views with no common ancestor,
    /// which throws.
    @discardableResult
    fileprivate func reloadLanguages() -> Bool {
        let previous = languages.map { $0.title }

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

        languages = orderedLanguageKeys.compactMap(loadLanguage)

        // A fresh install has every language switched off, and the keyboard has no UI of
        // its own for turning one on -- that lives in the container app. Rather than come
        // up with an empty language list (which used to trap on languages[0] below), fall
        // back to English so the keyboard is usable out of the box.
        if languages.isEmpty, let fallback = loadLanguage(named: "english") {
            languages = [fallback]
        }

        // Seed the current language only when there is not one already, or when the one stored is
        // no longer switched on. This was an unconditional write of languages.first, and since the
        // extension is torn down and relaunched constantly, the language chosen with the Kaart key
        // never survived: the keyboard always came back in the first enabled language.
        let stored = UserDefaults.standard.string(forKey: "CURRENT_LANG")
        if stored == nil || languages.contains(where: { $0.title == stored }) == false {
            if let first = languages.first {
                UserDefaults.standard.set(first.title, forKey: "CURRENT_LANG")
            }
        }

        return languages.map { $0.title } != previous
    }

    /// Decodes one bundled language definition, returning nil if it is missing or malformed
    /// rather than substituting a nil into `languages`.
    fileprivate func loadLanguage(named key: String) -> Language? {
        guard let path = Bundle.main.path(forResource: key, ofType: "json") else {
            os_log("language file not found: %{public}@.json", log: keyboardLog, type: .error, key)
            return nil
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            let language = try JSONDecoder().decode(Language.self, from: data)

            // A file can decode cleanly and still be unusable. No rows, or a row with no keys,
            // leaves the character grid with a hole in it that the layout then reaches into --
            // `characterButtons[1][0]` and friends are read positionally. Rejecting it here means
            // the language drops out of the list and the caller falls back, rather than the
            // keyboard coming up half-built.
            guard language.rows.isEmpty == false,
                  language.rows.allSatisfy({ $0.row.isEmpty == false }) else {
                os_log("ignoring %{public}@.json: it has no character rows, or a row with no keys",
                       log: keyboardLog, type: .error, key)
                return nil
            }
            return language
        } catch {
            os_log("could not decode %{public}@.json: %{public}@",
                   log: keyboardLog, type: .error, key, String(describing: error))
            return nil
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Pick up a language switched on or off in the container app since this keyboard was
        // built. Same rebuild the Kaart key does, which is all a changed language list needs:
        // the character rows, the space bar's label and the number row's symbols.
        if reloadLanguages() {
            addCharacterButtons()
            addSpaceButton()
            updateNumberRowSymbols()
            shiftMode = .on
            updateViewConstraints()
        }
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        //shiftMode = .On
        self.setUpHeightConstraint()
        self.updateViewConstraints()
    }
    
    /// Re-lays out after isRenamingPreset changes. Both directions are handled the same way,
    /// and that symmetry is the point: the band opens and closes over and over, so anything that
    /// depends on which way it is going, or on what happened the time before, is a bug waiting for
    /// the second rename.
    ///
    /// This is only the constraint update and a layout pass. It is enough because the keyboard is
    /// still attached to the view controller that sizes it -- see the note in the Done handler,
    /// which used to detach it here and is what actually broke the second rename.
    fileprivate func applyPresetBandChange() {
        updateViewConstraints()
        view.setNeedsLayout()
        view.layoutIfNeeded()
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

        // Same reason as the key guards above: `view` is `UIView!` and the item parameter is `Any`.
        let view: UIView = self.view

        if heightConstraint == nil {
            heightConstraint = NSLayoutConstraint(item: view,
                                                  attribute: .height,
                                                  relatedBy: .equal,
                                                  toItem: nil,
                                                  attribute: .notAnAttribute,
                                                  multiplier: 1,
                                                  constant: customHeight)
            // Just below required, so this never contradicts UIView-Encapsulated-Layout-Height --
            // the required constraint UIKit uses to hold an input view at the height it last handed
            // out. Two required constraints disagreeing about the height would leave the winner up
            // to Auto Layout rather than to us. This is precaution, not the fix for the band: what
            // broke repeated renames was the keyboard detaching itself from its parent controller
            // on Done, and that is fixed in the Done handler.
            heightConstraint.priority = UILayoutPriority(999)

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
    // A tap and a hold are mutually exclusive on this key, so this only ever runs for a tap.
    // Measured on an iPad simulator: a short press logs touchUpInside and no gesture states, while a
    // hold logs .began/.ended and no touchUpInside at all -- the long-press recogniser's default
    // cancelsTouchesInView cancels the button's tracking when it recognises. So there is no trailing
    // delete to suppress here, and a flag that tried to suppress one would only leak state from a
    // hold into the next tap and swallow it.
    @objc func deleteButtonPressed(_ sender: KeyButton) {
        deleteOneBackward()
    }

    /// One backspace, aimed at whatever holds the text the user can see: the preset name while it is
    /// being renamed, otherwise the document.
    ///
    /// Both the tap and the hold go through here. They used to disagree -- the tap branched on
    /// shortWordTxtFld while the hold's timer called proxy.deleteBackward() directly -- so holding
    /// delete with the rename editor open ate the document behind it instead of the name being
    /// edited.
    fileprivate func deleteOneBackward() {
        guard shortWordTxtFld.isHidden else {
            // dropLast() on the String drops one Character. The NSString substring this replaces cut
            // one UTF-16 unit, which halves a non-BMP character and leaves a lone surrogate behind.
            guard let text = shortWordTxtFld.text, text.isEmpty == false else { return }
            shortWordTxtFld.text = String(text.dropLast())
            return
        }
        proxy.deleteBackward()
    }

    /// Deletes the run of text before the cursor -- a word, or a run of whitespace -- and schedules
    /// itself again, so a sustained hold accelerates from characters to words.
    @objc func startMoreDelete(_ timer: Timer)
    {
        deleteFollowUpTimer = nil

        guard shortWordTxtFld.isHidden,
              let documentContextBeforeInput = proxy.documentContextBeforeInput else { return }

        let charactersToDelete = charactersToDeleteBackward(from: documentContextBeforeInput)
        guard charactersToDelete > 0 else { return }

        for _ in 0..<charactersToDelete {
            proxy.deleteBackward()
        }

        scheduleDeleteFollowUp(after: 0.2, selector: #selector(KeyboardViewController.startMoreDelete(_:)))
    }

    @objc func handleDeleteButtonLongPress(_ timer: Timer) {
        deleteFollowUpTimer = nil

        // Word-at-a-time deletion is for the document. With the rename editor open the hold stays on
        // single characters, which is all a one-line name field has to give.
        guard shortWordTxtFld.isHidden else { return }

        // Character repeat hands over to word deletion.
        deleteButtonTimer?.invalidate()
        deleteButtonTimer = nil

        scheduleDeleteFollowUp(after: 0.3, selector: #selector(KeyboardViewController.startMoreDelete(_:)))
    }

    /// Holds the single pending one-shot in `deleteFollowUpTimer` so releasing the key can cancel it.
    ///
    /// These timers used to be created and dropped on the floor -- added to the run loop and never
    /// stored -- so nothing could invalidate them. Lifting a finger before one fired left it to go
    /// off afterwards, and the only thing standing between it and more deletion was a
    /// `longPressStoped` flag that `startMoreDelete` then reset to false on its way out, clearing
    /// the very stop it had just obeyed.
    fileprivate func scheduleDeleteFollowUp(after delay: TimeInterval, selector: Selector) {
        deleteFollowUpTimer?.invalidate()
        let timer = Timer(timeInterval: delay, target: self, selector: selector, userInfo: nil, repeats: false)
        deleteFollowUpTimer = timer
        RunLoop.main.add(timer, forMode: RunLoop.Mode.default)
    }

    /// Stops every timer the delete key owns. One call for the whole machine, so a new press cannot
    /// inherit a chain left running by the last one.
    fileprivate func cancelDeleteTimers() {
        deleteButtonTimer?.invalidate()
        deleteButtonTimer = nil
        deleteFollowUpTimer?.invalidate()
        deleteFollowUpTimer = nil
    }

    //Delete Button long press action
    @objc func handleLongPressForDeleteButtonWithGestureRecognizer(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            guard deleteButtonTimer == nil else { break }

            let repeatTimer = Timer(timeInterval: 0.1, target: self, selector: #selector(KeyboardViewController.handleDeleteButtonTimerTick(_:)), userInfo: nil, repeats: true)
            repeatTimer.tolerance = 0.01
            deleteButtonTimer = repeatTimer
            RunLoop.main.add(repeatTimer, forMode: RunLoop.Mode.default)

            scheduleDeleteFollowUp(after: 0.4, selector: #selector(KeyboardViewController.handleDeleteButtonLongPress(_:)))

        case .ended, .cancelled, .failed:
            cancelDeleteTimers()

        default:
            break
        }
    }
    
    @objc func handleDeleteButtonTimerTick(_ timer: Timer) {
        deleteOneBackward()
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
    
    // When the numpadButton is pressed
    @objc func numpadButtonPressed(_ sender: KeyButton){
        
        if updateShortField((sender.titleLabel?.text)!) == true{
            return
        }
        
        proxy.insertText(sender.currentTitle!)
    }

    // Types the symbol in a number key's corner. The punctuation that used to be swiped off the
    // letter keys lives here now, so the gesture moved with it.
    @objc func numpadButtonSwipedDown(_ gesture: UISwipeGestureRecognizer){
        guard let key = gesture.view as? SymbolKeyButton, key.symbol.isEmpty == false else { return }

        if updateShortField(key.symbol) == true{
            return
        }

        proxy.insertText(key.symbol)
    }

    // Swaps the number row between Arabic and Roman numerals.
    @objc func numeralSwapPressed(_ sender: KeyButton){
        isRomanNumerals = !isRomanNumerals
        updateNumeralTitles()
        updatePresetControlFills()
    }
    
    // Swaps which preset group fills the twelve preset keys.
    @objc func presetGroupSwapPressed(_ sender: KeyButton){
        // Not while a preset is being edited: the pending edit is addressed by position within the
        // active group, so swapping groups would land it on the group that just arrived.
        guard shortWordTxtFld.isHidden else { return }
        activeBank = (activeBank + 1) % shortWordBanks.count
        updateShortWordTitles()
        updatePresetControlFills()
    }
    
    // When the shortWordButton is pressed
    @objc func shortWordButtonPressed(_ sender: KeyButton){
            if updateShortField((sender.titleLabel?.text)!) == true{
                return
            }
            proxy.insertText(sender.currentTitle! + " ")
            shiftMode = .on
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

        // Whatever popup was open belongs to another key. Take it down rather than leaving its
        // buttons stacked underneath the new one.
        dismissTertiaryButtons()

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
    
    /// Takes down the accent popup, if one is open.
    fileprivate func dismissTertiaryButtons() {
        for btn in tertiaryButtons {
            btn.removeFromSuperview()
        }
        tertiaryButtons = []
    }

    @objc func handleTertiaryPress(_ sender: KeyButton) {
        guard let charStr = sender.titleLabel?.text else {
            dismissTertiaryButtons()
            return
        }
        if updateShortField(charStr) == false {
            proxy.insertText(charStr)
        }
        shiftMode = .off
        dismissTertiaryButtons()
    }
    
    @objc func handleKaartKeyboardPress(_ sender: KeyButton) {
        if languages.count < 2 { return }
        for (i, lang) in languages.enumerated() {
            if lang.title == currentLanguage?.title {
                UserDefaults.standard.set(languages[ (i + 1) <= languages.count - 1 ? i + 1 : 0 ].title, forKey: "CURRENT_LANG")
                break
            }
        }
        addCharacterButtons()
        addSpaceButton()
        updateNumberRowSymbols()
        shiftMode = .on
        self.updateViewConstraints()
    }
    
    @objc func handleClosePress(_ sender: KeyButton) {
        dismissTertiaryButtons()
    }
    
    func handleSwipeUpForButton(_ button: CharacterButton) {
//        updateSuggestions()
    }
    
    // Types whatever the key shows in its corner, so the glyph and the gesture always agree.
    // On a letter key that is the first of its accents, cased with the shift mode like an
    // ordinary keypress; a letter with no accents shows nothing and swipes to nothing. The
    // punctuation keys keep typing their symbol.
    func handleSwipeDownForButton(_ button: CharacterButton) {
        var charStr: String

        if button.isLetterKey {
            guard let accent = button.tertiaryCharacters.first else { return }
            switch shiftMode {
            case .off:
                charStr = CharacterButton.cased(accent, uppercase: false)
            case .on:
                charStr = CharacterButton.cased(accent, uppercase: true)
                shiftMode = .off
            case .caps:
                charStr = CharacterButton.cased(accent, uppercase: true)
            }
            if updateShortField(charStr) == true{
                return
            }
            proxy.insertText(charStr)
            return
        }

        charStr = button.secondaryCharacter
        if updateShortField(charStr) == true{
            return
        }
        proxy.insertText(charStr)
        if charStr.count > 1 {
            proxy.insertText(" ")
        }
//        updateSuggestions()
    }
    
    // MARK: SuggestionButtonDelegate methods
    
    func handlePressForSuggestionButton(_ button: SuggestionButton) {
        if let lastWord = lastWordTyped {
            for _ in lastWord {
                proxy.deleteBackward()
            }
            proxy.insertText(button.title + " ")
            for suggestionButton in suggestionButtons {
                suggestionButton.removeFromSuperview()
            }
        }
    }
    
    // MARK: Helper methods
    
    fileprivate func addPredictiveTextScrollView() {
        predictiveTextScrollView = PredictiveTextScrollView(frame: CGRect(x: 0.0, y: 0.0, width: self.view.frame.width, height: predictiveTextBoxHeight))
        // Built and constrained as before, but kept hidden while the predictive feature is
        // parked. At rest the band is 0 and the strip would sit on top of the first preset row,
        // where a visible scroll view would swallow that row's taps. Drop this line to bring the
        // strip back once it has something to show.
        predictiveTextScrollView.isHidden = true
        self.view.addSubview(predictiveTextScrollView)
    }
    
    fileprivate func addShiftButton() {
        shiftButton = KeyButton(frame: CGRect(x: spacing, y: keyHeight * 4.0 + spacing * 5.0, width: keyWidth, height: keyHeight))
        // 15% smaller than the other glyph keys, and proportionally so -- a smaller font
        // rather than a vertical scale, which squashed the arrow out of its proportions.
        // Only exercised by the iOS 12 fallback in updateShiftGlyph(); iOS 13+ uses an image.
        shiftButton.useGlyphTitleFont(size: KeyButton.shiftTitleFontSize)
        shiftButton.tintColor = KeyButton.defaultKeyFill
        shiftButton.setTitleColor(KeyButton.defaultKeyFill, for: .normal)
        updateShiftGlyph()
        shiftButton.setBackgroundImage(UIImage.fromColor(KeyboardViewController.shiftKeyFill), for: .normal)
        shiftButton.addTarget(self, action: #selector(KeyboardViewController.shiftButtonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(shiftButton)
    }
    
    fileprivate func addDeleteButton() {
        deleteButton = KeyButton(frame: CGRect(x: view.frame.width - keyWidth - spacing, y: spacing * 3 + keyHeight * 2, width: keyWidth, height: keyHeight))
        deleteButton.setTitle("\u{232B}", for: .normal)
        deleteButton.useGlyphTitleFont(size: KeyButton.backspaceTitleFontSize)
        deleteButton.setTitleColor(KeyButton.defaultKeyFill, for: .normal)
        deleteButton.setBackgroundImage(UIImage.fromColor(KeyboardViewController.deleteKeyFill), for: .normal)
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
        nextKeyboardButton.setBackgroundImage(UIImage.fromColor(KeyButton.defaultKeyFill), for: .normal)
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
        kaartKeyboardButton.setBackgroundImage(UIImage.fromColor(KeyButton.defaultKeyFill), for: .normal)
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
        returnButton.setBackgroundImage(UIImage.fromColor(presetKeyFill), for: .normal)
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

        // The layout is built around exactly these three rows: row 1 is offset by half a key, row 2
        // by a key and a half with shift filling the gap, and delete closes row 0. A file with more
        // rows than that has nowhere to put them, and appending into characterButtons[3] would trap.
        // Show the rows that do fit and say what was dropped, rather than losing the language.
        if language.rows.count > characterButtons.count {
            os_log("%{public}@ declares %ld character rows; the layout has %ld, so the extra rows are not shown",
                   log: keyboardLog, type: .error,
                   language.title, language.rows.count, characterButtons.count)
        }

        for (rowIndex, row) in language.rows.prefix(characterButtons.count).enumerated() {
            
            
            // The widths updateConstraintForCharacter will use. The bottom row used to be built
            // against `row.row.count + 1` here and `row.count` there, so the frames these buttons
            // are created with described a different keyboard from the constraints that then
            // position them. Invisible -- the constraint pass replaces these frames before
            // anything is drawn, and measuring the glyphs put every row within 1.4pt of centre --
            // but there is no reason for the two passes to disagree.
            let rowKeyWidth = keyWidth(inRowOf: row.row.count)
            var x: CGFloat = 0
            switch rowIndex {
            case 1:
                x = spacing * 1.5 + rowKeyWidth * 0.5
            case 2:
                x = spacing * 2.5 + rowKeyWidth * 1.5
            default:
                x = spacing
            }
            for char in row.row {
                let characterButton = CharacterButton(frame: CGRect(x: x, y: y, width: rowKeyWidth, height: keyHeight), primaryCharacter: char.primary.lowercased(), secondaryCharacter: char.secondary, tertiaryCharacters: char.tertiary, delegate: self)
                self.view.addSubview(characterButton)
                characterButtons[rowIndex].append(characterButton)
                x += rowKeyWidth + spacing
            }
            y += keyHeight + spacing
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
        
        // y outside the loop. It was declared inside it and incremented after it, so it was 0 on
        // every pass and both preset rows were built at the same y. Auto Layout moves them to the
        // right places immediately afterwards, which is why nothing looked wrong, but the frames a
        // key is created with are the frames its labels are laid out against.
        var y: CGFloat = 0.0
        for (rowIndex, row) in shortWord.enumerated(){
            for index in 1...row.count{
                shortWordButton = KeyButton(frame: CGRect(x: spacing * CGFloat(index) + presetKeyWidth * CGFloat(index-1), y: y, width: presetKeyWidth, height: keyHeight))
                shortWordButton.setTitle(shortWord[rowIndex][index - 1], for: .normal)
                shortWordButton.setTitleColor(UIColor.white, for: .normal)
                shortWordButton.setBackgroundImage(UIImage.fromColor(presetKeyFill), for: .normal)
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
        // Only on .began, as pasteShortWord below already does. Without this the editor was torn
        // down and rebuilt, and the band reopened and re-laid out, once more for the release and
        // again for every touch move in between.
        guard gesture.state == .began, let pressed = gesture.view as? UIButton else { return }

        selectedShortWordBtn.layer.borderWidth = 0.0
        selectedShortWordBtn.layer.borderColor = UIColor.clear.cgColor

        predictiveTextScrollView.isHidden = true

        selectedShortWordBtn = pressed
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

    /// The shift mode the document was in before the rename editor took it over, held so Done can
    /// give it back. Nil whenever no rename is in progress.
    fileprivate var shiftModeBeforeRenaming: ShiftMode?
    
    var shortWordTxtFld : UITextField = UITextField.init()
    
    //    let inputAccessory: UIView = {
    //        let inputAccessoryView = UIView(frame: )
    //        inputAccessoryView.backgroundColor = UIColor.lightGray
    //        inputAccessoryView.alpha = 0.6
    //        return inputAccessoryView
    //    }()
    
    // MARK: Short Word method
    
    func addShortWordTxtFld(){

        // Open the band first, then lay out into it: the presets move down by a row and the
        // keyboard grows to match, so the editor lands on a line of its own.
        isRenamingPreset = true
        applyPresetBandChange()

        self.shortWordTxtFld.removeFromSuperview()

        // Created at zero and placed by layoutPresetEditor() below, so the geometry lives in one
        // place instead of being computed here and then again on every relayout.
        self.shortWordTxtFld = UITextField(frame: .zero)

        self.shortWordTxtFld.backgroundColor = UIColor.lightGray
        
        let gesture : UILongPressGestureRecognizer = UILongPressGestureRecognizer.init(target: self, action: #selector(self.pasteShortWord(_:)))
        gesture.minimumPressDuration = 0.4
        self.shortWordTxtFld.addGestureRecognizer(gesture)
        
        self.view.addSubview(shortWordTxtFld)
        self.view.bringSubviewToFront(self.shortWordTxtFld)

        doneBtn.removeFromSuperview()
        doneBtn = KeyButton(frame: .zero)
        
        doneBtn.setTitle("Done", for: .normal)
        doneBtn.setBackgroundImage(UIImage.fromColor(UIColor.white), for: .normal)
        
        doneBtn.addTarget(self, action: #selector(self.doneSelect(_:)), for: .touchUpInside)
        
        doneBtn.backgroundColor = UIColor.gray
        self.view.addSubview(doneBtn)

        // Place both now rather than waiting for the next layout pass, so the editor never shows
        // up at zero size for a frame.
        layoutPresetEditor()

        // Remember where shift was so Done can put it back, then start the preset name capitalised.
        // Only on the way in: long-pressing a second preset while the editor is already open comes
        // back through here, and overwriting the saved mode with the editor's own .on would lose the
        // document's state instead of restoring it.
        if shiftModeBeforeRenaming == nil {
            shiftModeBeforeRenaming = shiftMode
        }
        shiftMode = .on
    }
    
    /// Places the rename editor's text field and Done key across the band.
    ///
    /// The two are positioned by frame rather than by constraints, unlike every key on the
    /// keyboard, so nothing moved them when the keyboard's width changed: rotating the device
    /// mid-rename left the editor at its portrait width while the presets underneath it took their
    /// landscape positions. There was a method for recomputing these frames, but nothing ever
    /// called it.
    ///
    /// Called from viewDidLayoutSubviews and on the way in, so the frames are derived from the
    /// width the keyboard actually has at the moment they are applied.
    fileprivate func layoutPresetEditor() {
        guard isRenamingPreset else { return }

        let band = shortWordEditRect

        // Done takes a control key's width at the band's trailing edge, which is the margin the
        // control keys use, so Done, P1/2 and Num line up in one column. The field takes the rest.
        shortWordTxtFld.frame = CGRect(x: band.minX,
                                       y: band.minY,
                                       width: max(0, band.width - controlKeyWidth - spacing),
                                       height: band.height)

        doneBtn.frame = CGRect(x: band.maxX - controlKeyWidth,
                               y: band.minY,
                               width: controlKeyWidth,
                               height: band.height)
    }

    /// The width the key constraints were last built for, so a change can be noticed.
    fileprivate var lastLaidOutWidth: CGFloat = 0

    /// Every layout pass, which is what a rotation ultimately produces.
    ///
    /// Two things have to happen when the keyboard's width changes, and neither happened before.
    ///
    /// The keys are constrained, but their constraints carry *constants* computed from the width --
    /// `constant: keyWidth`, and so on -- so they only move if updateViewConstraints() runs again.
    /// Measured with a temporary NSLog: updateViewConstraints is not called on a plain layout pass,
    /// only when something asks for it, and the one thing that asked on rotation was
    /// didRotate(from:), deprecated and not called since iOS 8. So the constants stayed at their
    /// portrait values. Asking for them here, and only when the width actually changed, is what
    /// makes rotation reach them. It settles after one extra pass, because the second pass sees the
    /// same width and does nothing.
    ///
    /// The rename editor is positioned by frame rather than by constraints, so it needs placing on
    /// every pass regardless.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = view.frame.width
        if width > 0 && width != lastLaidOutWidth {
            lastLaidOutWidth = width
            updateViewConstraints()
        }

        layoutPresetEditor()
    }

    @objc func pasteShortWord(_ gesture:UILongPressGestureRecognizer){
        if gesture.state == .began, let pasted = UIPasteboard.general.string {
            self.shortWordTxtFld.text = pasted
        }
    }
    
    var doneBtn:KeyButton = KeyButton.init(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    
    @objc func doneSelect(_ btn:UIButton){
        
        let newStr = shortWordTxtFld.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        
        if let target = selectedShortWordIndex, newStr.isEmpty == false,
           target.row < shortWord.count, target.column < shortWord[target.row].count {
            
            shortWord[target.row][target.column] = newStr
            
            let defaults : UserDefaults = UserDefaults.standard
            // No synchronize(): deprecated since iOS 12 and a no-op long before that. The system
            // persists these writes on its own.
            defaults.set(shortWord, forKey: shortWordKeys[activeBank])
            
            arrayOfShortWordButton[target.row][target.column].setTitle(newStr, for: .normal)
        }
        shortWordTxtFld.isHidden = true
        doneBtn.isHidden = true

        shortWordTxtFld.removeFromSuperview()
        doneBtn.removeFromSuperview()

        // Close the band again, giving the row back to the screen.
        isRenamingPreset = false
        applyPresetBandChange()
        
        // No removeFromParentViewController() here, which is what this line used to do, and which
        // is why a preset could only be renamed once. The keyboard was detaching itself from the
        // controller that sizes it every time Done was pressed, so from then on the height it asked
        // for was never granted: measured on the second rename, the height constraint and the rows
        // had both moved to the taller value while the frame stayed at the old one -- the bottom row
        // hanging half off the screen, and dead space below the keyboard on the way back down.
        //
        // Nothing wanted the controller gone. The band is closed by isRenamingPreset just above,
        // and the editor's own views are removed a few lines before that.

        selectedShortWordBtn.layer.borderWidth = 0.0
        selectedShortWordBtn.layer.borderColor = UIColor.clear.cgColor
        selectedShortWordIndex = nil

        // Hand shift back to the document. Opening the editor forces .on so the preset name starts
        // capitalised, and typing a letter into it drops shift to .off -- so without this, finishing
        // a rename silently changed the case of the next letter typed into whatever the user was
        // actually writing.
        if let restored = shiftModeBeforeRenaming {
            shiftMode = restored
            shiftModeBeforeRenaming = nil
        }
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
            return true
        }else{
            return false
        }
    }
    
    
    fileprivate func addNumpadButton()
    {
        for button in arrayOfNumberButton { button.removeFromSuperview() }
        arrayOfNumberButton = []
        
        for index in 1...10{
            numpadButton = SymbolKeyButton(frame: CGRect(x: spacing * CGFloat(index) + keyWidth * CGFloat(index-1), y: spacing + keyHeight, width: keyWidth/12, height: keyHeight))
            numpadButton.setTitle(arabicNumerals[index - 1], for: .normal)
            // The same white the presets and the return key use. Set once here rather than in
            // updateNumeralTitles, which only swaps the title and the font, so the arabic and
            // roman numerals both read as white against the number key's fill.
            numpadButton.setTitleColor(UIColor.white, for: .normal)
            numpadButton.setBackgroundImage(UIImage.fromColor(midKeyFill), for: .normal)
            numpadButton.setBackgroundImage(UIImage.fromColor(UIColor.black), for: .selected)
            
            //numpadButton.setBackgroundImage(gradient.UIImageFromCALayer(), forState: .Normal)
            
            numpadButton.addTarget(self, action: #selector(KeyboardViewController.numpadButtonPressed(_:)), for: .touchUpInside)

            let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(KeyboardViewController.numpadButtonSwipedDown(_:)))
            swipeDown.direction = .down
            numpadButton.addGestureRecognizer(swipeDown)

            self.view.addSubview(numpadButton)
            arrayOfNumberButton.append(numpadButton);
        }
        updateNumeralTitles()
        updateNumberRowSymbols()
    }

    /// Repaints the number row's corner symbols from the active language. Separate from
    /// addNumpadButton so a language switch, which rebuilds only the character rows, can bring
    /// the symbols along with it.
    fileprivate func updateNumberRowSymbols() {
        let symbols = Language.numberRowSymbols(currentLanguage?.numberRowSymbols,
                                                paddedTo: arrayOfNumberButton.count)
        for (index, button) in arrayOfNumberButton.enumerated() {
            (button as? SymbolKeyButton)?.symbol = symbols[index]
        }
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
            title: "Num",
            action: #selector(KeyboardViewController.numeralSwapPressed(_:)))

        updatePresetControlFills()
    }

    fileprivate func makePresetControlButton(title: String, action: Selector) -> KeyButton {
        let button = KeyButton(frame: CGRect(x: view.frame.width - controlKeyWidth - spacing,
                                             y: predictiveTextBandHeight + spacing,
                                             width: controlKeyWidth,
                                             height: keyHeight))
        button.setTitle(title, for: .normal)
        button.setTitleColor(KeyButton.defaultKeyFill, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        self.view.addSubview(button)
        return button
    }
    
    /// Drives each fill off the state it controls rather than blind-toggling it, so the shades
    /// stay right when the keys are rebuilt -- on rotation, say -- with a swap already applied.
    fileprivate func updatePresetControlFills() {
        let groupFill = activeBank % 2 == 1 ? controlKeyFillAlternate : controlKeyFillPrimary
        let numeralFill = isRomanNumerals ? controlKeyFillAlternate : controlKeyFillPrimary
        presetGroupSwapButton?.setBackgroundImage(UIImage.fromColor(groupFill), for: .normal)
        numeralSwapButton?.setBackgroundImage(UIImage.fromColor(numeralFill), for: .normal)
    }
    
    fileprivate func updateShiftGlyph() {
        if #available(iOS 13.0, *) {
            let symbolName = shiftMode == .off ? shiftGlyphOutlineSymbolName : shiftGlyphFilledSymbolName
            let configuration = UIImage.SymbolConfiguration(pointSize: KeyButton.shiftTitleFontSize, weight: .regular)
            let image = UIImage(systemName: symbolName, withConfiguration: configuration)?.withRenderingMode(.alwaysTemplate)
            shiftButton?.setImage(image, for: .normal)
        } else {
            let glyph = shiftMode == .off ? shiftGlyphOutlineFallback : shiftGlyphFilledFallback
            shiftButton?.setTitle(glyph, for: .normal)
        }
    }
    
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
        let size = isRomanNumerals ? KeyButton.titleFontSize : arabicNumeralFontSize
        for (index, button) in arrayOfNumberButton.enumerated() where index < titles.count {
            button.setTitle(titles[index], for: .normal)
            button.titleLabel?.font = UIFont(name: "HelveticaNeue", size: size)
        }
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
