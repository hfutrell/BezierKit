//
//  DemoView.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

class DemoView: NSView, DraggableDelegate {
    
    var curve: CubicBezier?
    
    var draggables: [Draggable] = [Draggable]()
    var selectedDraggable: Draggable?
    var cp0, cp1, cp2, cp3: Draggable?

    override var isFlipped: Bool {
        get {
            return true
        }
    }
    
    required init?(coder: NSCoder) {
        
        super.init(coder: coder)

        self.cp0 = self.addDraggable(initialLocation: CGPoint(x: 100, y: 25), radius: 7)
        self.cp1 = self.addDraggable(initialLocation: CGPoint(x: 10, y: 90), radius: 7)
        self.cp2 = self.addDraggable(initialLocation: CGPoint(x: 110, y: 100), radius: 7)
        self.cp3 = self.addDraggable(initialLocation: CGPoint(x: 150, y: 195), radius: 7)

        self.updateCurves()

    }
    
    func updateCurves() {
        
        self.curve = CubicBezier(p0: cp0!.bkLocation,
                                 p1: cp1!.bkLocation,
                                 p2: cp2!.bkLocation,
                                 p3: cp3!.bkLocation)

        
    }
    
    func draggable(_ draggable: Draggable, didUpdateLocation location: CGPoint) {
        self.updateCurves()
        self.resetCursorRects()
        self.setNeedsDisplay(self.bounds)
    }
    
    override func resetCursorRects() {
        
        let cursor: NSCursor = NSCursor.pointingHand()
        
        self.discardCursorRects()
        for d: Draggable in self.draggables {
            self.addCursorRect(d.cursorRect, cursor: cursor)
        }
    }
    
    func addDraggable(initialLocation location: CGPoint, radius: CGFloat) -> Draggable {
        let draggable = Draggable(initialLocation: location, radius: radius)
        draggable.delegate = self
        self.draggables.append(draggable)
        return draggable
    }
    
    override func mouseDown(with event: NSEvent) {
        var location = self.convert(event.locationInWindow, to: self)
        location.y = self.bounds.height - location.y
        for d in self.draggables {
            if d.containsLocation(location) {
                self.selectedDraggable = d
                return
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if let draggable : Draggable = self.selectedDraggable {
            var location = self.convert(event.locationInWindow, to: self)
            location.y = self.bounds.height - location.y
            draggable.updateLocation(location)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        self.selectedDraggable = nil
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
        let context: CGContext = NSGraphicsContext.current()!.cgContext
        
        context.setFillColor(NSColor.white.cgColor)
        context.fill(self.bounds)
        
        Draw.reset(context)
        
        let p1 = BKPoint(x: 110, y: 50)
        let B = BKPoint(x: 50, y: 80)
        let p3 = BKPoint(x:135, y:100)
        let tvalues: [BKFloat] = [0.2, 0.3, 0.4, 0.5]
        let curves: [CubicBezier] = tvalues.map({
            (t: CGFloat) -> (CubicBezier) in
                return CubicBezier(fromPointsWithS: p1, B: B, E: p3, t: t)
            }
        )
        
        let offset = BKPoint(x: 0.0, y: 0.0)
        for curve in curves {
            Draw.setRandomColor(context)
            Draw.drawCurve(context, curve: curve, offset: offset)
        }
        Draw.setColor(context, color: Draw.black)
        Draw.drawCircle(context, center: curves[0].points[0], radius: 3, offset: offset)
        Draw.drawCircle(context, center: curves[0].points[3], radius: 3, offset: offset)
        Draw.drawCircle(context, center: B, radius: 3, offset: offset);
        
    }
    
 
}
