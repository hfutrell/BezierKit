//
//  DemoView.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

typealias DraggableCallback = (_ dragPosition: BKPoint) -> (BKPoint)

protocol DraggableDelegate: class {
    func draggable(_ draggable: Draggable, didUpdateLocation location: BKPoint)
}

class Draggable {
    
    var location: BKPoint
    weak var delegate: DraggableDelegate?
    private let callback: DraggableCallback
    private let radius: Double
    
    init(initialLocation location: BKPoint, radius: Double, callback: @escaping DraggableCallback) {
        self.location = location
        self.radius = radius
        self.callback = callback
    }
    convenience init(initialLocation location: BKPoint, radius: Double) {
        let callback: DraggableCallback = { (dragPosition: BKPoint) -> (BKPoint) in
            return dragPosition
        }
        self.init(initialLocation: location, radius: radius, callback: callback)
    }
    func updateLocation(_ location: BKPoint) {
        let updatedLocation = self.callback(location)
        if self.location.equalTo(updatedLocation) == false {
            self.location = updatedLocation
            self.delegate!.draggable(self, didUpdateLocation: updatedLocation)
        }
    }
    func containsLocation(_ location: BKPoint) -> Bool {
        let c = self.cursorRect as CGRect
        return c.contains(location)
    }
    var cursorRect: NSRect {
        get {
            let r = self.radius
            let r2 = 2.0 * r
            return CGRect( origin: self.location - CGPoint(x: r, y: r),
                           size: CGSize(width: r2, height: r2))
        }
    }
    
}

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

        self.cp0 = self.addDraggable(initialLocation: BKPoint(x: 100, y: 25), radius: 7)
        self.cp1 = self.addDraggable(initialLocation: BKPoint(x: 10, y: 90), radius: 7)
        self.cp2 = self.addDraggable(initialLocation: BKPoint(x: 110, y: 100), radius: 7)
        self.cp3 = self.addDraggable(initialLocation: BKPoint(x: 150, y: 195), radius: 7)

        self.updateCurves()

    }
    
    func updateCurves() {
        
        self.curve = CubicBezier(p0: cp0!.location,
                                 p1: cp1!.location,
                                 p2: cp2!.location,
                                 p3: cp3!.location)

        
    }
    
    func draggable(_ draggable: Draggable, didUpdateLocation location: BKPoint) {
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
    
    func addDraggable(initialLocation location: BKPoint, radius: Double) -> Draggable {
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
        
        Draw.drawSkeleton(context, curve: curve!)
        Draw.drawCurve(context, curve: curve!)
        
    }
    
 
}
