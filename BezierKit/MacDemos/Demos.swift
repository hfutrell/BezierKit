//
//  Demos.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/6/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import Foundation
import BezierKit
import CoreText

typealias DemoDrawFunction = (_ context: CGContext, _ demoState: DemoState) -> Void

struct Demo {
    var title: String
    var quadraticControlPoints: [CGPoint]
    var cubicControlPoints: [CGPoint]
    var drawFunction: DemoDrawFunction
}

struct DemoState {
    var quadratic: Bool             // whether the demo is set to quadratic (or if false: cubic) mode
    var lastInputLocation: CGPoint? // location of mouse / touch input if applicable
    var curve: BezierCurve?         // a user-draggable Bezier curve if applicable
}

class Demos {
    private static let cubicControlPoints = [CGPoint(x: 100, y: 25),
                                     CGPoint(x: 10, y: 90),
                                     CGPoint(x: 110, y: 100),
                                     CGPoint(x: 150, y: 195)]
    private static let quadraticControlPoints = [CGPoint(x: 150, y: 40),
                                         CGPoint(x: 80, y: 30),
                                         CGPoint(x: 105, y: 150)]
    
    static let demo1 = Demo(title: "new Bezier(...)",
                            quadraticControlPoints: quadraticControlPoints,
                            cubicControlPoints: cubicControlPoints,
                            drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                
    })
    static let demo2 = Demo(title: "Bezier.quadraticFromPoints",
                            quadraticControlPoints: [],
                            cubicControlPoints: [],
                            drawFunction: {(context: CGContext, demoState: DemoState) in
                                if demoState.quadratic {
                                    let B = CGPoint(x: 100, y: 50)
                                    let tvalues: [CGFloat] = [0.2, 0.3, 0.4, 0.5]
                                    let curves: [QuadraticBezierCurve] = tvalues.map({(t: CGFloat) -> QuadraticBezierCurve in
                                        return QuadraticBezierCurve(start: CGPoint(x:150, y: 40),
                                                                    end: CGPoint(x:35, y:160),
                                                                    mid: B,
                                                                    t: t)
                                    })
                                    let offset = CGPoint(x:45,y:30)
                                    for (i, b) in curves.enumerated() {
                                        Draw.drawSkeleton(context, curve: b, offset: offset, coords: true)
                                        Draw.setColor(context, color: Draw.transparentBlack)
                                        Draw.drawCircle(context, center: b.points[1], radius: 3, offset: offset)
                                        Draw.drawText(context, text: "t=\(tvalues[i])", offset: CGPoint(
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
                                }
                                else {
                                    let p1 = CGPoint(x: 110, y: 50)
                                    let B = CGPoint(x: 50, y: 80)
                                    let p3 = CGPoint(x:135, y:100)
                                    let tvalues: [CGFloat] = [0.2, 0.3, 0.4, 0.5]
                                    let curves: [CubicBezierCurve] = tvalues.map({
                                        (t: CGFloat) -> (CubicBezierCurve) in
                                        return CubicBezierCurve(start: p1, end: p3, mid: B, t: t)
                                        }
                                    )
                                    let offset = CGPoint(x: 0.0, y: 0.0)
                                    for curve in curves {
                                        Draw.setRandomColor(context)
                                        Draw.drawCurve(context, curve: curve, offset: offset)
                                    }
                                    Draw.setColor(context, color: Draw.black)
                                    Draw.drawCircle(context, center: curves[0].points[0], radius: 3, offset: offset)
                                    Draw.drawCircle(context, center: curves[0].points[3], radius: 3, offset: offset)
                                    Draw.drawCircle(context, center: B, radius: 3, offset: offset)
                                }
    })
    static let demo3 = Demo(title: ".getLUT(steps)",
                            quadraticControlPoints: quadraticControlPoints,
                            cubicControlPoints: cubicControlPoints,
                            drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                let LUT = curve.generateLookupTable(withSteps: 16)
                                for p in LUT {
                                    Draw.drawCircle(context, center: p, radius: 2)
                                }
    })
    static let demo4 = Demo(title: ".length()",
                            quadraticControlPoints: quadraticControlPoints,
                            cubicControlPoints: [CGPoint(x: 100, y: 25), CGPoint(x: 10, y: 90), CGPoint(x: 110, y: 100), CGPoint(x: 132, y: 192)],
                            drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
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
                                        let label = String(format: "%3.1fpt", arclength)
                                        Draw.drawText(context, text: label, offset: CGPoint(x: p2.x+7, y: p2.y-3))
                                    }
                                }
    })
    static let demo5 = Demo(title: ".get(t) and .compute(t)",
                            quadraticControlPoints: quadraticControlPoints,
                            cubicControlPoints: cubicControlPoints,
                            drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                Draw.drawPoint(context, origin: curve.compute(0.5))
    })
    static let demo6 = Demo(title: ".derivative(t)",
                            quadraticControlPoints: quadraticControlPoints,
                            cubicControlPoints: cubicControlPoints,
                            drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                for t in stride(from: 0, through: 1, by: 0.1) {
                                    let pt = curve.compute(CGFloat(t))
                                    let dv = curve.derivative(CGFloat(t))
                                    Draw.drawLine(context, from: pt, to: pt + dv )
                                }
    })
    static let demo7 = Demo(title: ".normal(t)",
                            quadraticControlPoints: quadraticControlPoints,
                            cubicControlPoints: cubicControlPoints,
                            drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                let d: CGFloat = 20.0
                                for t in stride(from: 0, through: 1, by: 0.1) {
                                    let pt = curve.compute(CGFloat(t))
                                    let dv = curve.normal(CGFloat(t))
                                    Draw.drawLine(context, from: pt, to: pt + d * dv )
                                }
    })
    static let demo8 = Demo(title: ".split(t) and .split(t1,t2)",
                            quadraticControlPoints: quadraticControlPoints,
                            cubicControlPoints: cubicControlPoints,
                            drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.setColor(context, color: Draw.lightGrey)
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                let c = curve.split(from: 0.25, to: 0.75)
                                Draw.setColor(context, color: Draw.red)
                                Draw.drawCurve(context, curve: c)
                                Draw.drawCircle(context, center: curve.compute(0.25), radius: 3)
                                Draw.drawCircle(context, center: curve.compute(0.75), radius: 3)
    })
    static let demo9 = Demo(title: ".extrema()",
                            quadraticControlPoints: quadraticControlPoints,
                            cubicControlPoints: cubicControlPoints,
                            drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                for t in curve.extrema().values {
                                    Draw.drawCircle(context, center: curve.compute(t), radius: 3)
                                }
    })
    static let demo10 = Demo(title: ".bbox()",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: cubicControlPoints,
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.pinkish)
                                Draw.drawBoundingBox(context, boundingBox: curve.boundingBox)
    })
    static let demo11 = Demo(title: ".hull(t)",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: [CGPoint(x: 100, y: 25), CGPoint(x: 10, y: 90), CGPoint(x: 50, y: 185), CGPoint(x: 170, y: 175)],
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                let hull = curve.hull(0.5)
                                Draw.drawHull(context, hull: hull)
                                Draw.drawCircle(context, center: hull[hull.count-1], radius: 5)
    })
    static let demo12 = Demo(title: ".project(point)",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: [CGPoint(x: 100, y: 25), CGPoint(x: 10, y: 90), CGPoint(x: 50, y: 185), CGPoint(x: 170, y: 175)],
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.pinkish)
                                if let mouse = demoState.lastInputLocation {
                                    let p = curve.project(point: mouse)
                                    Draw.drawLine(context, from: mouse, to: p)
                                }
    })
    static let demo13 = Demo(title: ".offset(d) and .offset(t, d)",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: cubicControlPoints,
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                for c in curve.offset(distance: 25) {
                                    Draw.drawCurve(context, curve: c)
                                }
                                Draw.drawPoint(context, origin: curve.offset(t: 0.5, distance: 25))
                                
    })
    static let demo14 = Demo(title: ".reduce(t)",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: cubicControlPoints,
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                Draw.drawSkeleton(context, curve: demoState.curve!)
                                var reduced: [BezierCurve] = []
                                if demoState.quadratic {
                                    let curve: QuadraticBezierCurve = demoState.curve! as! QuadraticBezierCurve
                                    reduced = curve.reduce().map({s in return s.curve})
                                }
                                else {
                                    let curve: CubicBezierCurve = demoState.curve! as! CubicBezierCurve
                                    reduced = curve.reduce().map({s in return s.curve})
                                }
                                if reduced.count > 0 {
                                    for i in 0..<reduced.count {
                                        let c = reduced[i]
                                        Draw.setColor(context, color: Draw.black)
                                        if i > 0 {
                                            Draw.drawCircle(context, center: c.points[0], radius: 3)
                                        }
                                        Draw.setRandomColor(context)
                                        Draw.drawCurve(context, curve: c)
                                    }
                                }
    })
    static let demo15 = Demo(title: ".arcs() and .arcs(threshold)",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: cubicControlPoints,
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve! as! ArcApproximateable
                                Draw.drawSkeleton(context, curve: curve)
                                let arcs = curve.arcs()
                                Draw.setColor(context, color: Draw.black)
                                for arc in arcs {
                                    Draw.setRandomFill(context, alpha: 0.1)
                                    Draw.draw(context, arc: arc)
                                }
    })
    static let demo16 = Demo(title: ".scale(d)",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: cubicControlPoints,
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.setColor(context, color: Draw.black)
                                var reduced: [BezierCurve] = []
                                if demoState.quadratic {
                                    let curve: QuadraticBezierCurve = demoState.curve! as! QuadraticBezierCurve
                                    reduced = curve.reduce().map({s in return s.curve})
                                }
                                else {
                                    let curve: CubicBezierCurve = demoState.curve! as! CubicBezierCurve
                                    reduced = curve.reduce().map({s in return s.curve})
                                }
                                if reduced.count > 0 {
                                    for i in 0..<reduced.count {
                                        let c = reduced[i]
                                        if i > 0 {
                                            Draw.drawCircle(context, center: c.points[0], radius: 3)
                                        }
                                        Draw.drawCurve(context, curve: c)
                                    }
                                    for i in stride(from: -30, through: 30, by: 10) {
                                        Draw.drawCurve(context, curve: reduced[(reduced.count/2)].scale(distance: CGFloat(i)))
                                    }
                                }
                                else {
                                    Draw.drawCurve(context, curve: curve)
                                }
    })
    static let demo17 = Demo(title: ".outline(d)",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: [CGPoint(x: 102, y: 33),
                                                  CGPoint(x: 16, y: 99),
                                                  CGPoint(x: 101, y: 129),
                                                  CGPoint(x: 132, y: 173)],
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
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
    
    static let demo18 = Demo(title: "graduated outlines, using .outline(d1,d2,d3,d4)",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: [CGPoint(x: 102, y: 33), CGPoint(x: 16, y: 99), CGPoint(x: 101, y: 129), CGPoint(x: 132, y: 173)],
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                let doc = {(c: BezierCurve) in Draw.drawCurve(context, curve: c) }
                                let outline = curve.outline(distanceAlongNormalStart: 5, distanceOppositeNormalStart: 5, distanceAlongNormalEnd: 25, distanceOppositeNormalEnd: 25)
                                outline.curves.forEach(doc)
    })
    static let demo19 = Demo(title: "outlineShapes",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: cubicControlPoints,
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                for shape in curve.outlineShapes(distance: 25) {
                                    Draw.setRandomFill(context, alpha: 0.2)
                                    Draw.drawShape(context, shape: shape)
                                }
    })
    static let demo20 = Demo(title: ".intersects()",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: [CGPoint(x: 100, y: 25), CGPoint(x: 10, y: 180), CGPoint(x: 170, y: 165), CGPoint(x: 65, y: 70)],
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                for intersection in curve.intersects() {
                                    Draw.drawPoint(context, origin: curve.compute(intersection.t1))
                                }
                                if demoState.quadratic {
                                    Draw.drawText(context,
                                                  text: "note: self-intersection not possible\nwith quadratic bezier curves",
                                                  offset: CGPoint(x: 15, y: 160))
                                }
    })
    static let demo21  = Demo(title: ".intersects(line)",
                              quadraticControlPoints: [CGPoint(x: 58, y: 173),CGPoint(x: 26, y: 28), CGPoint(x: 163, y: 104)],
                              cubicControlPoints: [CGPoint(x: 53, y: 163), CGPoint(x: 27, y: 19), CGPoint(x: 182, y: 176), CGPoint(x: 155, y: 36)],
                              drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                let line: LineSegment = LineSegment( p0: CGPoint(x:0.0, y:175.0), p1: CGPoint(x:200.0,y:25.0) )
                                Draw.setColor(context, color: Draw.red)
                                Draw.drawLine(context, from: line.p0, to: line.p1)
                                Draw.setColor(context, color: Draw.black)
                                for intersection in curve.intersects(line: line) {
                                    Draw.drawPoint(context, origin: curve.compute(intersection.t1))
                                }
    })
    static let demo22 = Demo(title: ".intersects(curve)",
                             quadraticControlPoints: [CGPoint(x: 0, y: 0),CGPoint(x: 100, y: 187), CGPoint(x: 166, y: 37)],
                             cubicControlPoints: [CGPoint(x: 48, y: 84), CGPoint(x: 104, y: 176), CGPoint(x: 190, y: 37), CGPoint(x: 121, y: 75)],
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                let curve2: BezierCurve = demoState.quadratic ? QuadraticBezierCurve(points: [CGPoint(x: 68.0, y: 150.0), CGPoint(x: 74.0, y: 6.0), CGPoint(x: 143.0, y: 150.0)]) : CubicBezierCurve(points: [CGPoint(x: 68.0, y: 145.0), CGPoint(x: 74.0, y: 6.0), CGPoint(x: 143.0, y: 197.0), CGPoint(x: 138.0, y: 55.0)])
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                Draw.drawCurve(context, curve: curve2)
                                Draw.setColor(context, color: Draw.black)
                                for intersection in curve.intersects(curve: curve2) {
                                    Draw.drawPoint(context, origin: curve.compute(intersection.t1))
                                }
    })
    static let demo23 = Demo(title: "CGPath interoperability",
                             quadraticControlPoints: [],
                             cubicControlPoints: [],
                             drawFunction: {(context: CGContext, demoState: DemoState) in

                                Draw.reset(context)
                                
                                var flip = CGAffineTransform.init(scaleX: 1, y: -1)
                                let font = CTFontCreateWithName("Times" as CFString, 350, &flip)
                                let height = CTFontGetXHeight(font)
                                var translate = CGAffineTransform.init(translationX: 0, y: -height + 15)
                                
                                var unichar1: UniChar = ("B" as NSString).character(at: 0)
                                var glyph1: CGGlyph = 0
                                CTFontGetGlyphsForCharacters(font, &unichar1, &glyph1, 1)
                                
                                var unichar2: UniChar = ("x" as NSString).character(at: 0)
                                var glyph2: CGGlyph = 0
                                CTFontGetGlyphsForCharacters(font, &unichar2, &glyph2, 1)
                                
                                assert(glyph1 != 0 && glyph2 != 0, "couldn't get glyphs")
                                
                                let cgPath1: CGPath = CTFontCreatePathForGlyph(font, glyph1, nil)!
                                var path1 = Path(cgPath: cgPath1.copy(using: &translate)!)
                                
                                if let mouse = demoState.lastInputLocation {
                                    
                                    //let m2 = CGPoint(x: -21.19140625, y: 131.38671875)
                                    //let me2 = CGPoint(x: 24.34375, y: 110.703125)
                                    
                                    //let me3 = CGPoint(x: -7.78515625, y: 161.7265625) // seems to cause an issue because intersections[5].t = 0.99999422905833845, clamping the t values when they are appropximately 1 or 0 seems to work (but fix not applied)
                                    // let me4 = CGPoint(x: 22.41796875, y: 168.48046875) // caused an infinite loop or graphical glitches
                                    
                                    var translation = CGAffineTransform.init(translationX: mouse.x, y: mouse.y)
                                    let cgPath2: CGPath = CTFontCreatePathForGlyph(font, glyph2, &translation)!
                                    let path2 = Path(cgPath: cgPath2)
                                    
//                                    Draw.drawPath(context, path2)

//                                    for intersection in path1.intersects(path: path2) {
//                                        Draw.drawPoint(context, origin: intersection)
//                                    }
                                    
//                                    var first: Vertex = augmentedGraph.v1
//                                    var v = first
//                                    repeat {
//                                        Draw.setColor(context, color: v.isIntersection ? Draw.blue : Draw.black)
//                                        if v.isIntersection {
//                                            if v.intersectionInfo.isEntry {
//                                                Draw.setColor(context, color: Draw.green)
//                                            }
//                                            if v.intersectionInfo.isExit {
//                                                Draw.setColor(context, color:Draw.red)
//                                            }
//                                        }
//                                        Draw.drawPoint(context, origin: v.location)
//                                        v = v.next
//                                    } while v !== first
                                    
                                    let subtracted = path1.intersecting(path2)
                                    Draw.drawPath(context, subtracted)
                                }
    })
    static let demo24 = Demo(title: "BVH",
                             quadraticControlPoints: [],
                             cubicControlPoints: [],
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                       
                                func location(_ angle: CGFloat) -> CGPoint {
                                    return 200.0 * CGPoint(x: cos(angle), y: sin(angle))
                                }
                                
                                let numPoints = 1000
                                
                                let radiansPerPoint = 2.0 * CGFloat.pi / CGFloat(numPoints)
                                
                                let startingAngle: CGFloat = 0
                                let mutablePath = CGMutablePath()
                                mutablePath.move(to: location(0.0) )
                                for i in 1..<numPoints {
                                    let angle = CGFloat(i) * radiansPerPoint + startingAngle
                                    mutablePath.addLine(to: location(angle))
                                }
                                mutablePath.closeSubpath()
                                
                                let path = Path(cgPath: mutablePath)
                                for s in path.subpaths {
                                    Draw.drawPathComponent(context, pathComponent: s, offset: CGPoint(x: 100.0, y: 100.0), includeBoundingVolumeHierarchy: true)
                                }

                                
                                
    })

    static let all: [Demo] = [demo1, demo2, demo3, demo4, demo5, demo6, demo7, demo8, demo9, demo10, demo11, demo12, demo13, demo14, demo15, demo16, demo17, demo18, demo19, demo20, demo21, demo22, demo23, demo24]
}
