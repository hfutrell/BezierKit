//
//  Draw.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/29/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// should Draw just be an extension of CGContext, or have a CGContext instead of passing it in to all these functions?
public class Draw {
    
    private static let deviceColorspace = CGColorSpaceCreateDeviceRGB()
    
    // MARK: - helpers
    private static func Color(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> CGColor {
        // have to use this initializer because simpler one is MacOS 10.5+ (not iOS)
        return CGColor(colorSpace: Draw.deviceColorspace, components: [red, green, blue, alpha])!
    }

    /**
     * HSL to RGB converter.
     * Adapted from: https://github.com/alessani/ColorConverter
     */
    private static func HSLToRGB(h: CGFloat, s: CGFloat, l: CGFloat, outR: inout CGFloat, outG: inout CGFloat, outB: inout CGFloat) {
        
        // Check for saturation. If there isn't any just return the luminance value for each, which results in gray.
        if s == 0.0 {
            outR = l
            outG = l
            outB = l
            return
        }

        var temp1, temp2: CGFloat
        var temp: [CGFloat] = [0, 0, 0]

        // Test for luminance and compute temporary values based on luminance and saturation
        if l < 0.5 {
            temp2 = l * (1.0 + s)
        }
        else {
            temp2 = l + s - l * s
        }
        temp1 = 2.0 * l - temp2
        
        // Compute intermediate values based on hue
        temp[0] = h + 1.0 / 3.0
        temp[1] = h
        temp[2] = h - 1.0 / 3.0
        
        for i in 0..<3 {
        
            // Adjust the range
            if temp[i] < 0.0 {
                temp[i] += 1.0
            }
            if temp[i] > 1.0 {
                temp[i] -= 1.0
            }
            
            if (6.0 * temp[i]) < 1.0 {
                temp[i] = temp1 + (temp2 - temp1) * 6.0 * temp[i]
            }
            else {
                if (2.0 * temp[i]) < 1.0 {
                    temp[i] = temp2
                }
                else {
                    if (3.0 * temp[i]) < 2.0 {
                        temp[i] = temp1 + (temp2 - temp1) * ((2.0 / 3.0) - temp[i]) * 6.0
                    }
                    else {
                        temp[i] = temp1
                    }
                }
            }
        }
        // Assign temporary values to R, G, B
        outR = temp[0]
        outG = temp[1]
        outB = temp[2]
    }

    // MARK: - some useful hard-coded colors
    public static let lightGrey = Draw.Color(red: 211.0 / 255.0, green: 211.0 / 255.0, blue: 211.0 / 255.0, alpha: 1.0)
    public static let black = Draw.Color(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    public static let red = Draw.Color(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
    public static let pinkish = Draw.Color(red: 1.0, green: 100.0 / 255.0, blue: 100.0 / 255.0, alpha: 1.0)
    public static let transparentBlue = Draw.Color(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.3)
    public static let transparentBlack = Draw.Color(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
    
    private static var randomIndex = 0
    private static let randomColors: [CGColor] = {
        var temp: [CGColor] = []
        for i in 0..<360 {
            var j = (i*47) % 360
            var r: CGFloat = 0.0
            var g: CGFloat = 0.0
            var b: CGFloat = 0.0
            HSLToRGB(h: CGFloat(j) / 360.0, s: 0.5, l: 0.5, outR: &r, outG: &g, outB: &b)
            
            temp.append(Draw.Color(red: r, green: g, blue: b, alpha: 1.0))
        }
        return temp
    }()
    
    // MARK: -
    
    public static func reset(_ context: CGContext) {
        context.setStrokeColor(black)
        randomIndex = 0
    }
    
    // MARK: - setting colors
    
    public static func setRandomColor(_ context: CGContext) {
        randomIndex = (randomIndex+1) % randomColors.count
        let c = randomColors[randomIndex]
        context.setStrokeColor(c)
    }
    
    public static func setRandomFill(_ context: CGContext, alpha a: CGFloat = 1.0) {
        randomIndex = (randomIndex+1) % randomColors.count
        let c = randomColors[randomIndex]
        let c2 = c.copy(alpha: a)
        context.setFillColor(c2!)
    }
    
    public static func setColor(_ context: CGContext, color: CGColor) {
        context.setStrokeColor(color)
    }
    
    // MARK: - drawing various geometry
    
    public static func drawCurve(_ context: CGContext, curve: BezierCurve, offset: BKPoint=BKPoint(x:0.0, y: 0.0)) {
        context.beginPath()
        if let quadraticCurve = curve as? QuadraticBezierCurve {
            context.move(to: (quadraticCurve.p0 + offset).cgPoint)
            context.addQuadCurve(to: (quadraticCurve.p2 + offset).cgPoint,
                                 control: (quadraticCurve.p1 + offset).cgPoint)
        }
        else if let cubicCurve = curve as? CubicBezierCurve {
            context.move(to: (cubicCurve.p0 + offset).cgPoint)
            context.addCurve(to: (cubicCurve.p3 + offset).cgPoint,
                             control1: (cubicCurve.p1 + offset).cgPoint,
                             control2: (cubicCurve.p2 + offset).cgPoint)
        }
        else if let lineSegment = curve as? LineSegment {
            context.move(to: (lineSegment.p0 + offset).cgPoint)
            context.addLine(to: (lineSegment.p1 + offset).cgPoint)
        }
        else {
            fatalError("unsupported curve type")
        }
        context.strokePath()
    }
    
    public static func drawCircle(_ context: CGContext, center: BKPoint, radius r : BKFloat, offset: BKPoint=BKPoint(x:0.0, y: 0.0)) {
        context.beginPath()
        context.addEllipse(in: CGRect(origin: CGPoint(x: center.x - r + offset.x, y: center.y - r + offset.y),
                            size: CGSize(width: 2.0 * r, height: 2.0 * r))
                            )
        context.strokePath()
    }
    
    public static func drawPoint(_ context: CGContext, origin o: BKPoint, offset: BKPoint=BKPointZero) {
        self.drawCircle(context, center: o, radius: 5.0, offset: offset)
        
    }
    
    public static func drawPoints(_ context: CGContext,
                    points: [BKPoint],
                    offset: BKPoint=BKPoint(x: 0.0, y: 0.0)) {
        for p in points {
            self.drawCircle(context, center: p, radius: 3.0, offset: offset)
        }
    }
    
    public static func drawLine(_ context: CGContext,
                  from p0: BKPoint,
                  to p1: BKPoint,
                  offset: BKPoint=BKPoint(x: 0.0, y: 0.0)) {
        context.beginPath()
        context.move(to: (p0 + offset).cgPoint)
        context.addLine(to: (p1 + offset).cgPoint)
        context.strokePath()
    }
    
    public static func drawText(_ context: CGContext, text: String, offset: BKPoint = BKPointZero) {
    #if os(macOS)
        (text as NSString).draw(at: NSPoint(x: offset.x, y: offset.y), withAttributes: [:])
    #else
        (text as NSString).draw(at: CGPoint(x: offset.x, y: offset.y), withAttributes: [:])
    #endif
    }
 
    public static func drawSkeleton(_ context: CGContext,
                             curve: BezierCurve,
                             offset: BKPoint=BKPoint(x: 0.0, y: 0.0),
                             coords: Bool=true) {
        
        context.setStrokeColor(lightGrey)
        
        if let cubicCurve = curve as? CubicBezierCurve {
            self.drawLine(context, from: cubicCurve.p0, to: cubicCurve.p1, offset: offset)
            self.drawLine(context, from: cubicCurve.p2, to: cubicCurve.p3, offset: offset)
        }
        else if let quadraticCurve = curve as? QuadraticBezierCurve {
            self.drawLine(context, from: quadraticCurve.p0, to: quadraticCurve.p1, offset: offset)
            self.drawLine(context, from: quadraticCurve.p1, to: quadraticCurve.p2, offset: offset)
        }
        
        if (coords == true) {
            context.setStrokeColor(black)
            self.drawPoints(context, points: curve.points, offset: offset)
        }
        
    }
    
    public static func draw(_ context: CGContext, arc: Arc, offset: BKPoint = BKPointZero) {
        let o = offset
        context.beginPath()
        context.move(to: (arc.origin + o).cgPoint)
        context.addArc(center: (arc.origin + o).cgPoint,
                       radius: arc.radius,
                       startAngle: arc.startAngle,
                       endAngle: arc.endAngle,
                       clockwise: false)
        context.addLine(to: (arc.origin + o).cgPoint)
        context.drawPath(using: CGPathDrawingMode.fillStroke)
    }
    
    public static func drawHull(_ context: CGContext, hull: [BKPoint], offset : BKPoint = BKPointZero) {
        context.beginPath()
        if hull.count == 6 {
            context.move(to: hull[0].cgPoint)
            context.addLine(to: hull[1].cgPoint)
            context.addLine(to: hull[2].cgPoint)
            context.move(to: hull[3].cgPoint)
            context.addLine(to: hull[4].cgPoint)
        }
        else {
            context.move(to: hull[0].cgPoint)
            context.addLine(to: hull[1].cgPoint)
            context.addLine(to: hull[2].cgPoint)
            context.addLine(to: hull[3].cgPoint)
            context.move(to: hull[4].cgPoint)
            context.addLine(to: hull[5].cgPoint)
            context.addLine(to: hull[6].cgPoint)
            context.move(to: hull[7].cgPoint)
            context.addLine(to: hull[8].cgPoint)
        }
        context.strokePath()
    }

    public static func drawBoundingBox(_ context: CGContext, boundingBox: BoundingBox, offset ox : BKPoint = BKPointZero) {
        context.beginPath()
        context.addRect(boundingBox.cgRect)
        context.closePath()
        context.strokePath()
    }

    public static func drawShape(_ context: CGContext, shape: Shape, offset: BKPoint = BKPointZero) {
        let order = shape.forward.points.count - 1
        context.beginPath()
        context.move(to: (offset + shape.startcap.curve.startingPoint).cgPoint)
        context.addLine(to: (offset + shape.startcap.curve.endingPoint).cgPoint)
        if order == 3 {
            context.addCurve(to: (offset + shape.forward.points[3]).cgPoint,
                             control1: (offset + shape.forward.points[1]).cgPoint,
                             control2: (offset + shape.forward.points[2]).cgPoint
                             
            )
        }
        else {
            context.addQuadCurve(to: (offset + shape.forward.points[2]).cgPoint,
                                 control: (offset + shape.forward.points[1]).cgPoint
            )
        }
        context.addLine(to: (offset + shape.endcap.curve.endingPoint).cgPoint)
        if order == 3 {
            context.addCurve(to: (offset + shape.back.points[3]).cgPoint,
                control1: (offset + shape.back.points[1]).cgPoint,
                control2: (offset + shape.back.points[2]).cgPoint
            )
        }
        else {
            context.addQuadCurve(to:(offset + shape.back.points[2]).cgPoint,
                                 control: (offset + shape.back.points[1]).cgPoint
            )
        }
        context.closePath()
        context.drawPath(using: CGPathDrawingMode.fillStroke)
    
    }
    
    
}
