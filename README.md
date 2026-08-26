Kaart Keyboard
===================

An iOS custom keyboard extension written in Swift designed to make text input in Go Map!! faster and more accurate.

## Accented Character Usage
1. Long press on base character to show accented characters
2. To make the accented characters go away either:
   
   a. Click on one of the accented characters
   
   b. Double click the base character



## Corner Glyphs and Swipe Down
A letter key shows its first accent in the top-left corner, so you can see at a glance which
letters have a long-press list; letters with no accents show nothing. Swiping down on a letter
types the accent shown, following the shift key's case.

The punctuation symbols live on the number row, one per key, also shown in the corner and typed
by swiping down. Each language sets its own ten in `Keyboard/Languages/<language>.json` under
`numberRowSymbols`. The comma and period keys are unchanged and still swipe down to `!` and `?`.

## Accented Character Notes
If you are editing one of the shortcut words and summon accented characters, the accented characters will cover the text box only until you dispose of the accented characters using either method described above.

## Paste usage while editing shortcut words
Once the desired text is copied, long press on the text field to paste -- there won't be any indicator other than the text showing up.
