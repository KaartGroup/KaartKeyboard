//
//  GoMapKeyboard.swift
//
//  Created by Shashank Patel on 4/18/16.
//  Copyright (c) 2014 Shashank Patel. All rights reserved.
//

import UIKit

class GoMapKeyboard: KeyboardViewController {
    
    let takeDebugScreenshot: Bool = false
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
//        NSUserDefaults.standardUserDefaults().registerDefaults([kCatTypeEnabled: true])
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func keyPressed(key: Key) {
        let textDocumentProxy = self.textDocumentProxy
        
        let keyOutput = key.outputForCase(self.shiftState.uppercase())
        
        if key.type == .Character || key.type == .SpecialCharacter {
            if let context = textDocumentProxy.documentContextBeforeInput {
                if context.characters.count < 2 {
                    textDocumentProxy.insertText(keyOutput)
                    return
                }
                
                var index = context.endIndex
                
                index = index.predecessor()
                if context[index] != " " {
                    textDocumentProxy.insertText(keyOutput)
                    return
                }
                
                index = index.predecessor()
                if context[index] == " " {
                    textDocumentProxy.insertText(keyOutput)
                    return
                }

                textDocumentProxy.insertText(keyOutput)
                return
            }
            else {
                textDocumentProxy.insertText(keyOutput)
                return
            }
        }
        else {
            textDocumentProxy.insertText(keyOutput)
            return
        }
    }
    
    override func setupKeys() {
        super.setupKeys()
        
        if takeDebugScreenshot {
            if self.layout == nil {
                return
            }
        }
    }
    
}
