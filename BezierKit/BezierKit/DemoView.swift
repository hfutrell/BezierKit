//
//  DemoView.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

struct Demo {
    var controlPoints: [CGPoint]
    var drawFunction: (_ context: CGContext, _ demo: Demo ) -> Void
}

class DemoView: NSView, DraggableDelegate {
    
    var curve: CubicBezier?
    
    var draggables: [Draggable] = [Draggable]()
    var selectedDraggable: Draggable?

    var demos: [Demo] = []
    
    
    var currentDemo: Demo? = nil {
        didSet {
            self.clearDraggables()
            for p in self.currentDemo!.controlPoints {
                self.addDraggable(initialLocation: p, radius: 7)
            }
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    override var isFlipped: Bool {
        get {
            return true
        }
    }
    
    func registerDemo(_ demo: Demo) {
        self.demos.append(demo)
    }
    

    required init?(coder: NSCoder) {
        
        super.init(coder: coder)
        
        let controlPoints = [CGPoint(x: 100, y: 25),
                             CGPoint(x: 10, y: 90),
                             CGPoint(x: 110, y: 100),
                             CGPoint(x: 150, y: 195)]
        
        // warning, these blocks introduce memory leaks!
        
        let demo1 = Demo(controlPoints: controlPoints,
                         drawFunction: { (context: CGContext, demo: Demo) in
            let curve = CubicBezier( p0: self.draggables[0].bkLocation,
                                     p1: self.draggables[1].bkLocation,
                                     p2: self.draggables[2].bkLocation,
                                     p3: self.draggables[3].bkLocation
            );
            Draw.drawSkeleton(context, curve: curve)
            Draw.drawCurve(context, curve: curve)
        })
        let demo2 = Demo(controlPoints: [],
                         drawFunction: { (context: CGContext, demo: Demo) in
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
        })
        let demo3 = Demo(controlPoints: controlPoints,
                         drawFunction: { (context: CGContext, demo: Demo) in
            let curve = CubicBezier( p0: self.draggables[0].bkLocation,
                                     p1: self.draggables[1].bkLocation,
                                     p2: self.draggables[2].bkLocation,
                                     p3: self.draggables[3].bkLocation
            );
            Draw.drawSkeleton(context, curve: curve);
            let LUT = curve.generateLookupTable(withSteps: 16);
            
            for p in LUT {
                Draw.drawCircle(context, center: p, radius: 2);
            }
        })

        
        self.registerDemo(demo1)
        self.registerDemo(demo2)
        self.registerDemo(demo3)
        
        postInit()
        
    }
    
    func postInit() {
        self.currentDemo = self.demos[1]
    }
    
    func clearDraggables() {
        self.selectedDraggable = nil
        self.resetCursorRects()
        self.draggables = []
    }
    
    func draggable(_ draggable: Draggable, didUpdateLocation location: CGPoint) {
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
    
    func addDraggable(initialLocation location: CGPoint, radius: CGFloat) {
        let draggable = Draggable(initialLocation: location, radius: radius)
        draggable.delegate = self
        self.draggables.append(draggable)
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
        
        currentDemo!.drawFunction(context, currentDemo! )
        
    }
    
 
}
