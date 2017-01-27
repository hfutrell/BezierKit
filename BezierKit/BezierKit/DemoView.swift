//
//  DemoView.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

typealias DemoDrawFunction = (_ context: CGContext, _ demo: Demo ) -> Void

struct Demo {
    var title: String
    var controlPoints: [CGPoint]
    var quadraticDrawFunction: DemoDrawFunction
    var cubicDrawFunction: DemoDrawFunction
}

class DemoView: NSView, DraggableDelegate {
    
    @IBOutlet var popup: NSPopUpButton!

    @IBAction func popupAction(sender: NSPopUpButton){
        self.currentDemo = self.demos[sender.indexOfSelectedItem]
    }
    
    var curve: CubicBezier?
    
    var mouseTrackingArea: NSTrackingArea?
    
    var draggables: [Draggable] = [Draggable]()
    var selectedDraggable: Draggable?

    var demos: [Demo] = []
    
    var lastMouseLocation: CGPoint? = nil
    
    var currentDemo: Demo? = nil {
        didSet {
            self.clearDraggables()
            for p in self.currentDemo!.controlPoints {
                self.addDraggable(initialLocation: p, radius: 7)
            }
            self.resetCursorRects()
            self.resetTrackingAreas()
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    override var isFlipped: Bool {
        return true
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
        let lengthControlPoints = [CGPoint(x: 100, y: 25),
                             CGPoint(x: 10, y: 90),
                             CGPoint(x: 110, y: 100),
                             CGPoint(x: 132, y: 192)]

        let hullPoints = [CGPoint(x: 100, y: 25),
                             CGPoint(x: 10, y: 90),
                             CGPoint(x: 50, y: 185),
                             CGPoint(x: 170, y: 175)]

        let outlinePoints = [CGPoint(x: 102, y: 33),
                          CGPoint(x: 16, y: 99),
                          CGPoint(x: 101, y: 129),
                          CGPoint(x: 132, y: 173)]
        let intersectsPoints = [CGPoint(x: 100, y: 25),
                             CGPoint(x: 10, y: 180),
                             CGPoint(x: 170, y: 165),
                             CGPoint(x: 65, y: 70)]
        let intersectsLine = [CGPoint(x: 53, y: 163),
                                CGPoint(x: 27, y: 19),
                                CGPoint(x: 182, y: 176),
                                CGPoint(x: 155, y: 36)]
        let intersectsCurve1 = [CGPoint(x: 48, y: 84),
                                CGPoint(x: 104, y: 176),
                                CGPoint(x: 190, y: 37),
                                CGPoint(x: 121, y: 75)]
        let intersectsCurve2 = [BKPoint(x: 68, y: 145),
                                BKPoint(x: 74, y: 6),
                                BKPoint(x: 143, y: 197),
                                BKPoint(x: 138, y: 55)]
        
        // warning, these blocks introduce memory leaks! (because they reference self)
        
        let demo1 = Demo(title: "new Bezier(...)",
                         controlPoints: controlPoints,
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
            let curve = self.draggableCubicCurve()
            Draw.drawSkeleton(context, curve: curve)
            Draw.drawCurve(context, curve: curve)
        })
        let demo2 = Demo(title: "Bezier.quadraticFromPoints",
                         controlPoints: [],
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: { (context: CGContext, demo: Demo) in
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
            Draw.drawCircle(context, center: B, radius: 3, offset: offset)
        })
        let demo3 = Demo(title: ".getLUT(steps)",
                        controlPoints: controlPoints,
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
            let curve = self.draggableCubicCurve()
            Draw.drawSkeleton(context, curve: curve)
            let LUT = curve.generateLookupTable(withSteps: 16)
            
            for p in LUT {
                Draw.drawCircle(context, center: p, radius: 2)
            }
        })
        let demo4 = Demo(title: ".length()",
                         //TODO: you still haven't implemented length function or drawText
                         controlPoints: lengthControlPoints,
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            let arclength = curve.length()
                            let offset = curve.offset(distance: -10)
                            let last = offset.count-1
                            for idx in 0 ..< offset.count {
                                let c: CubicBezier = offset[idx]
                                Draw.drawCurve(context, curve: c)
                                if(idx==last) {
                                    let p1 = curve.offset(t: 0.95, distance: -15)
                                    let p2 = c.compute(1)
                                    let p3 = curve.offset(t: 0.95, distance: -5)
                                    Draw.drawLine(context, from: p1, to: p2)
                                    Draw.drawLine(context, from: p2, to: p3)
                                    let label = String(format: "%3.1fpx", arclength)
                                    Draw.drawText(context, text: label, offset: BKPoint(x: p2.x+7, y: p2.y-3))
                                }
                            }
        })
        let demo5 = Demo(title: ".get(t) and .compute(t)",
                         controlPoints: controlPoints,
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            Draw.drawPoint(context, origin: curve.compute(0.5))
        })
        let demo6 = Demo(title: ".derivative(t)",
                         controlPoints: controlPoints,
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            for t in stride(from: 0, through: 1, by: 0.1) {
                                let pt = curve.compute(BKFloat(t));
                                let dv = curve.derivative(BKFloat(t));
                                Draw.drawLine(context, from: pt, to: pt + dv );
                            }
        })
        let demo7 = Demo(title: ".normal(t)",
                         controlPoints: controlPoints,
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            let d: BKFloat = 20.0
                            for t in stride(from: 0, through: 1, by: 0.1) {
                                let pt = curve.compute(BKFloat(t));
                                let dv = curve.normal(BKFloat(t));
                                Draw.drawLine(context, from: pt, to: pt + dv * d );
                            }
        })
        let demo8 = Demo(title: ".split(t) and .split(t1,t2)",
                         controlPoints: controlPoints,
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.setColor(context, color: Draw.lightGrey)
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            let c = curve.split(from: 0.25, to: 0.75);
                            Draw.setColor(context, color: Draw.red)
                            Draw.drawCurve(context, curve: c)
                            Draw.drawCircle(context, center: curve.compute(0.25), radius: 3);
                            Draw.drawCircle(context, center: curve.compute(0.75), radius: 3);
        })
        let demo9 = Demo(title: ".extrema()",
                         controlPoints: controlPoints,
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            for t in curve.extrema().values {
                                Draw.drawCircle(context, center: curve.compute(t), radius: 3);
                            }
        })
        let demo10 = Demo(title: ".bbox()",
                         controlPoints: controlPoints,
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.pinkish)
                            Draw.drawBoundingBox(context, boundingBox: curve.boundingBox)
            })
        let demo11 = Demo(title: ".hull(t)",
                         controlPoints: hullPoints,
                         quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                         cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            let hull = curve.hull(0.5)
                            Draw.drawHull(context, hull: hull);
                            Draw.drawCircle(context, center: hull[hull.count-1], radius: 5);
        })
        let demo12 = Demo(title: ".project(point)",
                          controlPoints: hullPoints,
                          quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                          cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.pinkish)
                            if let mouse = self.lastMouseLocation {
                                let p = curve.project(point: BKPoint(mouse))
                                Draw.drawLine(context, from: BKPoint(mouse), to: p)
                            }
        })
        let demo13 = Demo(title: ".offset(d) and .offset(t, d)",
                          controlPoints: controlPoints,
                          quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                          cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            for c in curve.offset(distance: 25) {
                                Draw.drawCurve(context, curve: c)
                            }
                            Draw.drawPoint(context, origin: curve.offset(t: 0.5, distance: 25))
        
            })
        let demo14 = Demo(title: ".reduce(t)",
                          controlPoints: controlPoints,
                          quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                          cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            let reduced = curve.reduce()
                            if reduced.count > 0 {
                                for i in 0..<reduced.count {
                                    let c = reduced[i].curve
                                    Draw.setColor(context, color: Draw.black)
                                    if i > 0 {
                                        Draw.drawCircle(context, center: c.points[0], radius: 3)
                                    }
                                    Draw.setRandomColor(context)
                                    Draw.drawCurve(context, curve: c)
                                }
                            }
                            else {
                                Draw.drawCurve(context, curve: curve)
                            }
        })
        let demo16 = Demo(title: ".scale(d)",
                          controlPoints: controlPoints,
                          quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                          cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.setColor(context, color: Draw.black)
                            let reduced = curve.reduce()
                            if reduced.count > 0 {
                                for i in 0..<reduced.count {
                                    let c = reduced[i].curve
                                    if i > 0 {
                                        Draw.drawCircle(context, center: c.points[0], radius: 3)
                                    }
                                    Draw.drawCurve(context, curve: c)
                                }
                                for i in stride(from: -30, through: 30, by: 10) {
                                    Draw.drawCurve(context, curve: reduced[(reduced.count/2)].curve.scale(distance: BKFloat(i)));
                                }
                            }
                            else {
                                Draw.drawCurve(context, curve: curve)
                            }
            })
        let demo17 = Demo(title: ".outline(d)",
                          controlPoints: outlinePoints,
                          quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                          cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            let doc = {(c: CubicBezier) in Draw.drawCurve(context, curve: c) }
                            let outline = curve.outline(distance: 25)
                            outline.curves.forEach(doc)
                            Draw.setColor(context, color: Draw.transparentBlue)
                            outline.offset(distance: 10).curves.forEach(doc)
                            outline.offset(distance: -10).curves.forEach(doc)
        })
        
        let demo18 = Demo(title: "graduated outlines, using .outline(d1,d2,d3,d4)",
                          controlPoints: outlinePoints,
                          quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                          cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            let doc = {(c: CubicBezier) in Draw.drawCurve(context, curve: c) }
                            let outline = curve.outline(d1: 5, d2: 5, d3: 25, d4: 25)
                            outline.curves.forEach(doc)
        })
        let demo20 = Demo(title: ".intersects()",
                          controlPoints: intersectsPoints,
                          quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                          cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            for intersection in curve.intersects() {
                                Draw.drawPoint(context, origin: curve.compute(intersection.t1))
                            }
                            
        })
        let demo21 = Demo(title: ".intersects(line)",
                          controlPoints: intersectsLine,
                          quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                          cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            let line: Line = Line( p1: BKPoint(x:0, y:175), p2: BKPoint(x:200,y:25) )
                            Draw.setColor(context, color: Draw.red)
                            Draw.drawLine(context, from: line.p1, to: line.p2)
                            Draw.setColor(context, color: Draw.black)
                            for intersection in curve.intersects(line: line) {
                                Draw.drawPoint(context, origin: curve.compute(intersection))
                            }
        })
        let demo22 = Demo(title: ".intersects(curve)",
                          controlPoints: intersectsCurve1,
                          quadraticDrawFunction: { (context: CGContext, demo: Demo) in },
                          cubicDrawFunction: {[unowned self] (context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            let curve2 =  CubicBezier(points: intersectsCurve2)
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            Draw.drawCurve(context, curve: curve2)
                            Draw.setColor(context, color: Draw.black);
                            for intersection in curve.intersects(curve: curve2) {
                                Draw.drawPoint(context, origin: curve.compute(intersection.t1))
                            }
        })


        
        self.registerDemo(demo1)
        self.registerDemo(demo2)
        self.registerDemo(demo3)
        self.registerDemo(demo4)
        self.registerDemo(demo5)
        self.registerDemo(demo6)
        self.registerDemo(demo7)
        self.registerDemo(demo8)
        self.registerDemo(demo9)
        self.registerDemo(demo10)
        self.registerDemo(demo11)
        self.registerDemo(demo12)
        self.registerDemo(demo13)
        self.registerDemo(demo14)
        self.registerDemo(demo16)
        self.registerDemo(demo17)
        self.registerDemo(demo18)
        self.registerDemo(demo20)
        self.registerDemo(demo21)
        self.registerDemo(demo22)

    }
    
    override func awakeFromNib() {
        
        let index: Int = 1
        
        self.currentDemo = self.demos[index]
        
        self.popup.removeAllItems()
        for demo in self.demos {
            self.popup.addItem(withTitle: demo.title)
        }
        self.popup.selectItem(at: index)
    }
    
    func draggableCubicCurve() -> CubicBezier {
        return CubicBezier( p0: self.draggables[0].bkLocation,
                            p1: self.draggables[1].bkLocation,
                            p2: self.draggables[2].bkLocation,
                            p3: self.draggables[3].bkLocation )
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
    
    func resetTrackingAreas() {
        
        self.mouseTrackingArea = NSTrackingArea(rect: self.bounds, options: [NSTrackingAreaOptions.activeInKeyWindow, NSTrackingAreaOptions.mouseMoved, NSTrackingAreaOptions.mouseEnteredAndExited], owner: self, userInfo: nil)
        
        self.addTrackingArea(self.mouseTrackingArea!)
        
    }
    
    func addDraggable(initialLocation location: CGPoint, radius: CGFloat) {
        let draggable = Draggable(initialLocation: location, radius: radius)
        draggable.delegate = self
        self.draggables.append(draggable)
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = self.superview!.convert(event.locationInWindow, to: self)
        for d in self.draggables {
            if d.containsLocation(location) {
                self.selectedDraggable = d
                return
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if let draggable : Draggable = self.selectedDraggable {
            let location = self.superview!.convert(event.locationInWindow, to: self)
            draggable.updateLocation(location)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        self.selectedDraggable = nil
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func mouseMoved(with event: NSEvent) {
//        NSLog("mouse location \(event.locationInWindow)")
        let location = self.superview!.convert(event.locationInWindow, to: self)
        self.lastMouseLocation = location
        self.setNeedsDisplay(self.bounds)
    }
    
    override func mouseExited(with event: NSEvent) {
        self.lastMouseLocation = nil
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
        let context: CGContext = NSGraphicsContext.current()!.cgContext
        
        context.setFillColor(NSColor.white.cgColor)
        context.fill(self.bounds)
        
        Draw.reset(context)
        
        currentDemo!.cubicDrawFunction(context, currentDemo! )
        
    }
    
 
}
