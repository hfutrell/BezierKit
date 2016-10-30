//
//  DemoView.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

class DemoView: NSView {
    
    var curve: CubicBezier
    
    override var isFlipped: Bool {
        get {
            return true
        }
    }
    
    required init?(coder: NSCoder) {
        NSLog("init with coder")
        
        self.curve = CubicBezier(p0: BKPoint(x: 100, y: 25),
                                 p1: BKPoint(x: 10, y: 90),
                                 p2: BKPoint(x: 110, y: 100),
                                 p3: BKPoint(x: 150, y: 195))

        super.init(coder: coder)
        
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
        let context: CGContext = NSGraphicsContext.current()!.cgContext
        
        context.setFillColor(NSColor.white.cgColor)
        context.fill(self.bounds)
        
        Draw.drawSkeleton(context, curve: curve)
        Draw.drawCurve(context, curve: curve)
        
    }
    
 
}
