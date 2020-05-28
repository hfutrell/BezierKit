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
                                    let curves: [QuadraticCurve] = tvalues.map({(t: CGFloat) -> QuadraticCurve in
                                        return QuadraticCurve(start: CGPoint(x: 150, y: 40),
                                                                    end: CGPoint(x: 35, y: 160),
                                                                    mid: B,
                                                                    t: t)
                                    })
                                    let offset = CGPoint(x: 45, y: 30)
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
                                    Draw.drawCircle(context, center: curves[0].points[0], radius: 3, offset: offset)
                                    Draw.drawCircle(context, center: curves[0].points[2], radius: 3, offset: offset)
                                    Draw.drawCircle(context, center: B, radius: 3, offset: offset)
                                } else {
                                    let p1 = CGPoint(x: 110, y: 50)
                                    let B = CGPoint(x: 50, y: 80)
                                    let p3 = CGPoint(x: 135, y: 100)
                                    let tvalues: [CGFloat] = [0.2, 0.3, 0.4, 0.5]
                                    let curves = tvalues.map { CubicCurve(start: p1, end: p3, mid: B, t: $0) }
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
                                let points = stride(from: 0, through: 1, by: 1.0 / 7.0).map { curve.point(at: $0) }

                                Draw.drawSkeleton(context, curve: curve)
                                let LUT = curve.lookupTable(steps: 16)
                                for p in points {
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
                                    if idx == last {
                                        let p1 = curve.offset(t: 0.95, distance: -15)
                                        let p2 = c.point(at: 1)
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
                                Draw.drawPoint(context, origin: curve.point(at: 0.5))
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
                                    let pt = curve.point(at: CGFloat(t))
                                    let dv = curve.derivative(at: CGFloat(t))
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
                                    let pt = curve.point(at: CGFloat(t))
                                    let dv = curve.normal(at: CGFloat(t))
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
                                Draw.drawCircle(context, center: curve.point(at: 0.25), radius: 3)
                                Draw.drawCircle(context, center: curve.point(at: 0.75), radius: 3)
    })
    static let demo9 = Demo(title: ".extrema()",
                            quadraticControlPoints: quadraticControlPoints,
                            cubicControlPoints: cubicControlPoints,
                            drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                for t in curve.extrema().all {
                                    Draw.drawCircle(context, center: curve.point(at: t), radius: 3)
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
                                Draw.drawCircle(context, center: hull.last!, radius: 5)
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
                                    let p = curve.project(mouse).point
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
                                    let curve: QuadraticCurve = demoState.curve! as! QuadraticCurve
                                    reduced = curve.reduce().map({s in return s.curve})
                                } else {
                                    let curve: CubicCurve = demoState.curve! as! CubicCurve
                                    reduced = curve.reduce().map({s in return s.curve})
                                }
                                if !reduced.isEmpty {
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
    static let demo15 = Demo(title: ".scale(d)",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: cubicControlPoints,
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.setColor(context, color: Draw.black)
                                var reduced: [BezierCurve] = []
                                if demoState.quadratic {
                                    let curve: QuadraticCurve = demoState.curve! as! QuadraticCurve
                                    reduced = curve.reduce().map({s in return s.curve})
                                } else {
                                    let curve: CubicCurve = demoState.curve! as! CubicCurve
                                    reduced = curve.reduce().map({s in return s.curve})
                                }
                                if !reduced.isEmpty {
                                    for i in 0..<reduced.count {
                                        let c = reduced[i]
                                        if i > 0 {
                                            Draw.drawCircle(context, center: c.points[0], radius: 3)
                                        }
                                        Draw.drawCurve(context, curve: c)
                                    }
                                    for i in stride(from: -30, through: 30, by: 10) {
                                        guard let scaled = reduced[reduced.count/2].scale(distance: CGFloat(i)) else { continue }
                                        Draw.drawCurve(context, curve: scaled)
                                    }
                                } else {
                                    Draw.drawCurve(context, curve: curve)
                                }
    })
    static let demo16 = Demo(title: ".outline(d)",
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
                                outline.offset(distance: 10)?.curves.forEach(doc)
                                outline.offset(distance: -10)?.curves.forEach(doc)
    })

    static let demo17 = Demo(title: "outlineShapes",
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
    static let demo18 = Demo(title: ".selfIntersections()",
                             quadraticControlPoints: quadraticControlPoints,
                             cubicControlPoints: [CGPoint(x: 100, y: 25), CGPoint(x: 10, y: 180), CGPoint(x: 170, y: 165), CGPoint(x: 65, y: 70)],
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                for intersection in curve.selfIntersections() {
                                    Draw.drawPoint(context, origin: curve.point(at: intersection.t1))
                                }
                                if demoState.quadratic {
                                    Draw.drawText(context,
                                                  text: "note: self-intersection not possible\nwith quadratic bezier curves",
                                                  offset: CGPoint(x: 15, y: 160))
                                }
    })

    // construct a line segment from start to end
    static let demo19  = Demo(title: ".intersections(with line: LineSegment)",
                              quadraticControlPoints: [CGPoint(x: 58, y: 173), CGPoint(x: 26, y: 28), CGPoint(x: 163, y: 104)],
                              cubicControlPoints: [CGPoint(x: 53, y: 163), CGPoint(x: 27, y: 19), CGPoint(x: 182, y: 176), CGPoint(x: 155, y: 36)],
                              drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                let line: LineSegment = LineSegment( p0: CGPoint(x: 0.0, y: 175.0), p1: CGPoint(x: 200.0, y: 25.0) )
                                Draw.setColor(context, color: Draw.red)
                                Draw.drawLine(context, from: line.p0, to: line.p1)
                                Draw.setColor(context, color: Draw.black)
                                for intersection in curve.intersections(with: line) {
                                    Draw.drawPoint(context, origin: curve.point(at: intersection.t1))
                                }
    })
    static let demo20 = Demo(title: ".intersections(with curve: BezierCurve)",
                             quadraticControlPoints: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 187), CGPoint(x: 166, y: 37)],
                             cubicControlPoints: [CGPoint(x: 48, y: 84), CGPoint(x: 104, y: 176), CGPoint(x: 190, y: 37), CGPoint(x: 121, y: 75)],
                             drawFunction: {(context: CGContext, demoState: DemoState) in
                                let curve = demoState.curve!
                                let curve2: BezierCurve = demoState.quadratic ? QuadraticCurve(points: [CGPoint(x: 68.0, y: 150.0), CGPoint(x: 74.0, y: 6.0), CGPoint(x: 143.0, y: 150.0)]) : CubicCurve(points: [CGPoint(x: 68.0, y: 145.0), CGPoint(x: 74.0, y: 6.0), CGPoint(x: 143.0, y: 197.0), CGPoint(x: 138.0, y: 55.0)])
                                Draw.drawSkeleton(context, curve: curve)
                                Draw.drawCurve(context, curve: curve)
                                Draw.setColor(context, color: Draw.red)
                                Draw.drawCurve(context, curve: curve2)
                                Draw.setColor(context, color: Draw.black)
                                for intersection in curve.intersections(with: curve2) {
                                    Draw.drawPoint(context, origin: curve.point(at: intersection.t1))
                                }
    })
    static let demo21 = Demo(title: "CGPath interoperability",
                             quadraticControlPoints: [],
                             cubicControlPoints: [],
                             drawFunction: {(context: CGContext, demoState: DemoState) in

                                Draw.reset(context)

                                var flip = CGAffineTransform(scaleX: 1, y: -1)
                                let font = CTFontCreateWithName("Times" as CFString, 350, &flip)
                                let height = CTFontGetXHeight(font)
                                var translate = CGAffineTransform.init(translationX: 0, y: -height + 15)

                                var unichar1: UniChar = ("B" as NSString).character(at: 0)
                                var glyph1: CGGlyph = 0
                                CTFontGetGlyphsForCharacters(font, &unichar1, &glyph1, 1)

                                var unichar2: UniChar = ("K" as NSString).character(at: 0)
                                var glyph2: CGGlyph = 0
                                CTFontGetGlyphsForCharacters(font, &unichar2, &glyph2, 1)

                                assert(glyph1 != 0 && glyph2 != 0, "couldn't get glyphs")

                                let cgPath1: CGPath = CTFontCreatePathForGlyph(font, glyph1, nil)!
                                var path1 = Path(cgPath: cgPath1.copy(using: &translate)!)

                                if let mouse = demoState.lastInputLocation {

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

//                                    let augmentedGraph = AugmentedGraph(path1: path1, path2: path2, intersections: path1.intersections(with: path2, accuracy: 0.5), operation: .intersect)
//                                    augmentedGraph.draw(context)

                                    let subtracted = path1.intersect(path2)
                                    Draw.drawPath(context, subtracted)
                                }
    })
    static let demo22 = Demo(title: "BoundingBoxHierarchy",
                             quadraticControlPoints: [],
                             cubicControlPoints: [],
                             drawFunction: {(context: CGContext, _: DemoState) in

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
                                for s in path.components {
                                    Draw.drawPathComponent(context, pathComponent: s, offset: CGPoint(x: 100.0, y: 100.0), includeBoundingVolumeHierarchy: true)
                                }

    })

    static let all: [Demo] = [demo1, demo2, demo3, demo4, demo5, demo6, demo7, demo8, demo9, demo10, demo11, demo12, demo13, demo14, demo15, demo16, demo17, demo18, demo19, demo20, demo21, demo22]
}
