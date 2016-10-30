//
//  DemoView.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

class DemoView: NSView {
    
    required init?(coder: NSCoder) {
        NSLog("init with coder")
        super.init(coder: coder)
    }
        
    override func draw(_ dirtyRect: NSRect) {

        NSLog("draw")
        
        let context: CGContext = NSGraphicsContext.current()!.cgContext
        
        context.setFillColor(NSColor.red.cgColor)
        context.fill(self.bounds)
        
    }
    
}
