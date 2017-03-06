//
//  DemoView.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

typealias DemoDrawFunction = (_ context: CGContext, _ demo: Demo ) -> Void
typealias DemoDrawFunction2 = (_ context: CGContext, _ demo: Demo, _ curve: BezierCurve ) -> Void

protocol Demo {
    var title: String {get}
    var quadraticControlPoints: [CGPoint] {get}
    var cubicControlPoints: [CGPoint] {get}
}

struct SingleDrawFuncDemo: Demo {
    var title: String
    var quadraticControlPoints: [CGPoint]
    var cubicControlPoints: [CGPoint]
    var drawFunction: DemoDrawFunction2
}

struct DualDrawFuncDemo:Demo {
    var title: String
    var quadraticControlPoints: [CGPoint]
    var quadraticDrawFunction: DemoDrawFunction
    var cubicControlPoints: [CGPoint]
    var cubicDrawFunction: DemoDrawFunction
}

class DemoView: NSView, DraggableDelegate {
    
    // MARK: - UI
    
    @IBOutlet var popup: NSPopUpButton!

    @IBAction func popupAction(sender: NSPopUpButton){
        self.currentDemo = self.demos[sender.indexOfSelectedItem]
    }
    
    @IBOutlet var quadraticRadioButton: NSButton!
    @IBOutlet var cubicRadioButton: NSButton!
    
    @IBAction func radioButtonAction(sender: NSButton) {
        self.useQuadratic = (sender == quadraticRadioButton)
    }
    
    // MARK: -
    
    var curve: CubicBezierCurve?
    
    var mouseTrackingArea: NSTrackingArea?
    
    var draggables: [Draggable] = [Draggable]()
    var selectedDraggable: Draggable?

    var demos: [Demo] = []
    
    var lastMouseLocation: CGPoint? = nil
    
    func resetDemoState() {
        self.clearDraggables()
        let demo = self.currentDemo!
        let controlPoints = self.useQuadratic ? demo.quadraticControlPoints : demo.cubicControlPoints
        for p in controlPoints {
            self.addDraggable(initialLocation: p, radius: 7)
        }
        self.resetCursorRects()
        self.resetTrackingAreas()
        self.setNeedsDisplay(self.bounds)
    }
    
    var useQuadratic: Bool = false {
        didSet {
           self.resetDemoState()
            quadraticRadioButton.state = self.useQuadratic ? NSOnState : NSOffState
            cubicRadioButton.state = self.useQuadratic ? NSOffState : NSOnState
        }
    }
    
    var currentDemo: Demo? = nil {
        didSet {
            self.resetDemoState()
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
        let quadraticControlPoints = [CGPoint(x: 150, y: 40),
                                      CGPoint(x: 80, y: 30),
                                      CGPoint(x: 105, y: 150)]

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
        
        let demo1 = DualDrawFuncDemo(title: "new Bezier(...)",
                         quadraticControlPoints: quadraticControlPoints,
                         quadraticDrawFunction: {[unowned self](context: CGContext, demo: Demo) in
                        let curve = self.draggableQuadraticCurve()
                        Draw.drawSkeleton(context, curve: curve)
                        Draw.drawCurve(context, curve: curve)

        },
                        cubicControlPoints: controlPoints,
                        cubicDrawFunction: {[unowned self](context: CGContext, demo: Demo) in
                        let curve = self.draggableCubicCurve()
                        Draw.drawSkeleton(context, curve: curve)
                        Draw.drawCurve(context, curve: curve)
        })
        let demo2 = DualDrawFuncDemo(title: "Bezier.quadraticFromPoints",
                         quadraticControlPoints: [],
                         quadraticDrawFunction: {(context: CGContext, demo: Demo) in
                let B = BKPoint(x: 100, y: 50)
                let tvalues: [BKFloat] = [0.2, 0.3, 0.4, 0.5]
                let curves: [QuadraticBezierCurve] = tvalues.map({(t: BKFloat) -> QuadraticBezierCurve in
                    return QuadraticBezierCurve(p0: BKPoint(x:150, y: 40),
                                                p1: B,
                                                p2: BKPoint(x:35, y:160),
                                                t: t)
                })
                let offset = BKPoint(x:45,y:30)
                for (i, b) in curves.enumerated() {
                    Draw.drawSkeleton(context, curve: b, offset: offset, coords: true)
                    Draw.setColor(context, color: Draw.transparentBlack)
                    Draw.drawCircle(context, center: b.points[1], radius: 3, offset: offset)
                    Draw.drawText(context, text: "t=\(tvalues[i])", offset: BKPoint(
                        x: b.points[1].x + offset.x - 15,
                        y: b.points[1].y + offset.y - 20
                    ))
                    Draw.setRandomColor(context)
                    Draw.drawCurve(context, curve: b, offset: offset)
                }
                Draw.setColor(context, color: Draw.black)
                Draw.drawCircle(context, center: curves[0].points[0], radius:3, offset: offset)
                Draw.drawCircle(context, center: curves[0].points[2], radius:3, offset: offset)
                Draw.drawCircle(context, center: B, radius: 3, offset: offset)
            },
                         cubicControlPoints: [],
                         cubicDrawFunction: {(context: CGContext, demo: Demo) in
            let p1 = BKPoint(x: 110, y: 50)
            let B = BKPoint(x: 50, y: 80)
            let p3 = BKPoint(x:135, y:100)
            let tvalues: [BKFloat] = [0.2, 0.3, 0.4, 0.5]
            let curves: [CubicBezierCurve] = tvalues.map({
                (t: CGFloat) -> (CubicBezierCurve) in
                    return CubicBezierCurve(fromPointsWithS: p1, B: B, E: p3, t: t)
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
        let demo3 = SingleDrawFuncDemo(title: ".getLUT(steps)",
                         quadraticControlPoints: quadraticControlPoints,
                         cubicControlPoints: controlPoints,
                         drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
            Draw.drawSkeleton(context, curve: curve)
            let LUT = curve.generateLookupTable(withSteps: 16)
            for p in LUT {
                Draw.drawCircle(context, center: p, radius: 2)
            }
        })
        let demo4 = SingleDrawFuncDemo(title: ".length()",
            quadraticControlPoints: quadraticControlPoints,
            cubicControlPoints: lengthControlPoints,
            drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            let arclength = curve.length()
                            let offset = curve.offset(distance: -10)
                            let last = offset.count-1
                            for idx in 0 ..< offset.count {
                                let c = offset[idx]
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
        let demo5 = SingleDrawFuncDemo(title: ".get(t) and .compute(t)",
                         quadraticControlPoints: quadraticControlPoints,
                         cubicControlPoints: controlPoints,
                         drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            Draw.drawPoint(context, origin: curve.compute(0.5))
        })
        let demo6 = SingleDrawFuncDemo(title: ".derivative(t)",
                         quadraticControlPoints: quadraticControlPoints,
                         cubicControlPoints: controlPoints,
                         drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            for t in stride(from: 0, through: 1, by: 0.1) {
                                let pt = curve.compute(BKFloat(t));
                                let dv = curve.derivative(BKFloat(t));
                                Draw.drawLine(context, from: pt, to: pt + dv );
                            }
        })
        let demo7 = SingleDrawFuncDemo(title: ".normal(t)",
                         quadraticControlPoints: quadraticControlPoints,
                         cubicControlPoints: controlPoints,
                         drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
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
        let demo8 = SingleDrawFuncDemo(title: ".split(t) and .split(t1,t2)",
                         quadraticControlPoints: quadraticControlPoints,
                         cubicControlPoints: controlPoints,
                         drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
                            Draw.setColor(context, color: Draw.lightGrey)
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            let c = curve.split(from: 0.25, to: 0.75)
                            Draw.setColor(context, color: Draw.red)
                            Draw.drawCurve(context, curve: c)
                            Draw.drawCircle(context, center: curve.compute(0.25), radius: 3);
                            Draw.drawCircle(context, center: curve.compute(0.75), radius: 3);
        })
        let demo9 = SingleDrawFuncDemo(title: ".extrema()",
                         quadraticControlPoints: quadraticControlPoints,
                         cubicControlPoints: controlPoints,
                         drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            for t in curve.extrema().values {
                                Draw.drawCircle(context, center: curve.compute(t), radius: 3);
                            }
        })
        let demo10 = SingleDrawFuncDemo(title: ".bbox()",
                          quadraticControlPoints: quadraticControlPoints,
                          cubicControlPoints: controlPoints,
                          drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.pinkish)
                            Draw.drawBoundingBox(context, boundingBox: curve.boundingBox)
            })
        let demo11 = SingleDrawFuncDemo(title: ".hull(t)",
                          quadraticControlPoints: quadraticControlPoints,
                          cubicControlPoints: hullPoints,
                          drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            let hull = curve.hull(0.5)
                            Draw.drawHull(context, hull: hull);
                            Draw.drawCircle(context, center: hull[hull.count-1], radius: 5);
        })
        let demo12 = SingleDrawFuncDemo(title: ".project(point)",
                          quadraticControlPoints: quadraticControlPoints,
                          cubicControlPoints: hullPoints,
                          drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.pinkish)
                            if let mouse = self.lastMouseLocation {
                                let p = curve.project(point: BKPoint(mouse))
                                Draw.drawLine(context, from: BKPoint(mouse), to: p)
                            }
        })
        let demo13 = SingleDrawFuncDemo(title: ".offset(d) and .offset(t, d)",
                          quadraticControlPoints: quadraticControlPoints,
                          cubicControlPoints: controlPoints,
                          drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            for c in curve.offset(distance: 25) {
                                Draw.drawCurve(context, curve: c)
                            }
                            Draw.drawPoint(context, origin: curve.offset(t: 0.5, distance: 25))
        
            })
        let demo14 = SingleDrawFuncDemo(title: ".reduce(t)",
                          quadraticControlPoints: quadraticControlPoints,
                          cubicControlPoints: controlPoints,
                          drawFunction: {(context: CGContext, demo: Demo, curve: BezierCurve) in
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
        let demo15 = DualDrawFuncDemo(title: ".arcs() and .arcs(threshold)",
                          quadraticControlPoints: [],
                          quadraticDrawFunction: {[unowned self](context: CGContext, demo: Demo) in },
                          cubicControlPoints: controlPoints,
                          cubicDrawFunction: {[unowned self](context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            let arcs = curve.arcs();
                            Draw.setColor(context, color: Draw.black)
                            for arc in arcs {
                                Draw.setRandomFill(context, alpha: 0.1)
                                Draw.draw(context, arc: arc);
                            }
        })
        let demo16 = DualDrawFuncDemo(title: ".scale(d)",
                          quadraticControlPoints: [],
                          quadraticDrawFunction: {[unowned self](context: CGContext, demo: Demo) in },
                          cubicControlPoints: controlPoints,
                          cubicDrawFunction: {[unowned self](context: CGContext, demo: Demo) in
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
                                    Draw.drawCurve(context, curve: c as! CubicBezierCurve)
                                }
                                for i in stride(from: -30, through: 30, by: 10) {
                                    Draw.drawCurve(context, curve: reduced[(reduced.count/2)].curve.scale(distance: BKFloat(i)));
                                }
                            }
                            else {
                                Draw.drawCurve(context, curve: curve)
                            }
            })
        let demo17 = DualDrawFuncDemo(title: ".outline(d)",
                          quadraticControlPoints: [],
                          quadraticDrawFunction: {[unowned self](context: CGContext, demo: Demo) in },
                          cubicControlPoints: outlinePoints,
                          cubicDrawFunction: {[unowned self](context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            let doc = {(c: BezierCurve) in Draw.drawCurve(context, curve: c) }
                            let outline = curve.outline(distance: 25)
                            outline.curves.forEach(doc)
                            Draw.setColor(context, color: Draw.transparentBlue)
                            outline.offset(distance: 10).curves.forEach(doc)
                            outline.offset(distance: -10).curves.forEach(doc)
        })
        
        let demo18 = DualDrawFuncDemo(title: "graduated outlines, using .outline(d1,d2,d3,d4)",
                          quadraticControlPoints: [],
                          quadraticDrawFunction: {[unowned self](context: CGContext, demo: Demo) in },
                          cubicControlPoints: outlinePoints,
                          cubicDrawFunction: {[unowned self](context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            let doc = {(c: BezierCurve) in Draw.drawCurve(context, curve: c) }
                            let outline = curve.outline(d1: 5, d2: 5, d3: 25, d4: 25)
                            outline.curves.forEach(doc)
        })
        let demo19 = DualDrawFuncDemo(title: "outlineShapes",
                          quadraticControlPoints: [],
                          quadraticDrawFunction: {[unowned self](context: CGContext, demo: Demo) in },
                          cubicControlPoints: controlPoints,
                          cubicDrawFunction: {[unowned self](context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            Draw.setColor(context, color: Draw.red)
                            for shape in curve.outlineShapes(distance: 25) {
                                Draw.setRandomFill(context, alpha: 0.2)
                                Draw.drawShape(context, shape: shape);
                            }
        })

        let demo20 = DualDrawFuncDemo(title: ".intersects()",
                          quadraticControlPoints: [],
                          quadraticDrawFunction: {[unowned self](context: CGContext, demo: Demo) in },
                          cubicControlPoints: intersectsPoints,
                          cubicDrawFunction: {[unowned self](context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            Draw.drawSkeleton(context, curve: curve)
                            Draw.drawCurve(context, curve: curve)
                            for intersection in curve.intersects() {
                                Draw.drawPoint(context, origin: curve.compute(intersection.t1))
                            }
                            
        })
        let demo21 = DualDrawFuncDemo(title: ".intersects(line)",
                          quadraticControlPoints: [],
                          quadraticDrawFunction: {[unowned self](context: CGContext, demo: Demo) in },
                          cubicControlPoints: intersectsLine,
                          cubicDrawFunction: {[unowned self](context: CGContext, demo: Demo) in
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
        let demo22 = DualDrawFuncDemo(title: ".intersects(curve)",
                          quadraticControlPoints: [],
                          quadraticDrawFunction: {[unowned self](context: CGContext, demo: Demo) in },
                          cubicControlPoints: intersectsCurve1,
                          cubicDrawFunction: {[unowned self](context: CGContext, demo: Demo) in
                            let curve = self.draggableCubicCurve()
                            let curve2 =  CubicBezierCurve(points: intersectsCurve2)
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
        self.registerDemo(demo15)
        self.registerDemo(demo16)
        self.registerDemo(demo17)
        self.registerDemo(demo18)
        self.registerDemo(demo19)
        self.registerDemo(demo20)
        self.registerDemo(demo21)
        self.registerDemo(demo22)
        
    }
    
    override func awakeFromNib() {
        
        let index: Int = 1
        
        self.currentDemo = self.demos[index]
        self.useQuadratic = false
        
        self.popup.removeAllItems()
        for demo in self.demos {
            self.popup.addItem(withTitle: demo.title)
        }
        self.popup.selectItem(at: index)
    }
    
    func draggableQuadraticCurve() -> QuadraticBezierCurve {
        assert(self.useQuadratic)
        assert(self.draggables.count >= 3, "uh oh, did you set the control points in demo?")
        return QuadraticBezierCurve( p0: self.draggables[0].bkLocation,
                                     p1: self.draggables[1].bkLocation,
                                     p2: self.draggables[2].bkLocation)
    }
    
    func draggableCubicCurve() -> CubicBezierCurve {
        assert(self.useQuadratic == false)
        assert(self.draggables.count >= 4, "uh oh, did you set the control points in demo?")
        return CubicBezierCurve( p0: self.draggables[0].bkLocation,
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

    // MARK: - mouse functions
    
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
    
    // MARK:
    
    override func draw(_ dirtyRect: NSRect) {
        
        let context: CGContext = NSGraphicsContext.current()!.cgContext
        
        context.setFillColor(NSColor.white.cgColor)
        context.fill(self.bounds)
        
        Draw.reset(context)
        if let demo = currentDemo! as? DualDrawFuncDemo {
            if self.useQuadratic {
                demo.quadraticDrawFunction(context, demo )
            }
            else {
                demo.cubicDrawFunction(context, demo )
            }
        }
        else if let demo = currentDemo! as? SingleDrawFuncDemo {
            let curve = self.useQuadratic ? self.draggableQuadraticCurve() : self.draggableCubicCurve()
            demo.drawFunction(context, demo, curve)
        }
        
    }
    
 
}
