Kaart Keyboard
===================

An iOS custom keyboard extension written in Swift designed to make text input in Go Map!! faster and more accurate.

iPad only. Seven layouts ship with it: Bulgarian, English, Greek, Macedonian, Romanian, Serbian (Cyrillic) and Vietnamese.

## Setup
1. Install the Kaart Keyboard app.
2. Settings > General > Keyboard > Keyboards > Add New Keyboard, and pick **Kaart**.
3. Tap it again in that list and turn on **Allow Full Access**. Without it the keyboard cannot read the language settings you choose in step 4, and pasting into a preset will not work.
4. Open the Kaart Keyboard app and switch on the languages you want.

Step 4 is not optional and the keyboard cannot do it for you -- it has no UI of its own for enabling a language. Until at least one is switched on it falls back to English.

## Layout
The top two rows are presets, six to a row, with a control key in the seventh column of each:

- **P1/2**, top right, swaps the twelve presets on screen for a second group of twelve.
- **Numerals**, right below it, swaps the number row between `1-9,0` and `I-X` -- Roman numerals turn up often in street and monarch names in the Cyrillic-script layouts.

Below the presets are the number row, three character rows, and the space row.

- Backspace is at the right-hand end of the first character row, just past `P`.
- The space bar is labelled with the language currently in use.
- The **Kaart logo** key cycles through the languages you enabled in the app.
- The **globe** key switches to a different iOS keyboard.

## Preset usage
Long press a preset to edit it. A text field opens at the top of the keyboard; type the replacement and tap Done.

Edits are saved against the group they were made in, so a preset changed in group 1 stays in group 1 and does not disturb group 2. Presets live on the device the keyboard is running on -- they do not follow you to another iPad.

## Paste usage while editing presets
Once the desired text is copied, long press on the text field to paste -- there won't be any indicator other than the text showing up.

## Accented Character Usage
1. Long press on base character to show accented characters
2. To make the accented characters go away either:

   a. Click on one of the accented characters

   b. Click the red **X** at the end of the accented characters

## Corner Glyphs and Swipe Down
A letter key shows its first accent in the top-left corner, so you can see at a glance which
letters have a long-press list; letters with no accents show nothing. Swiping down on a letter
types the accent shown, following the shift key's case.

The punctuation symbols live on the number row, one per key, also shown in the corner and typed
by swiping down. Each language sets its own ten in `Keyboard/Languages/<language>.json` under
`numberRowSymbols`. The comma and period keys are unchanged and still swipe down to `!` and `?`.

## Accented Character Notes
If you are editing one of the presets and summon accented characters, the accented characters will cover the text box only until you dispose of the accented characters using either method described above.
