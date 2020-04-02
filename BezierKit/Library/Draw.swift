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
    internal static func HSLToRGB(h: CGFloat, s: CGFloat, l: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {

        // Check for saturation. If there isn't any just return the luminance value for each, which results in gray.
        if s == 0.0 {
            return (r: l, g: l, b: l)
        }

        var temp1, temp2: CGFloat
        var temp: [CGFloat] = [0, 0, 0]

        // Test for luminance and compute temporary values based on luminance and saturation
        if l < 0.5 {
            temp2 = l * (1.0 + s)
        } else {
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
            } else if temp[i] > 1.0 {
                temp[i] -= 1.0
            }

            if (6.0 * temp[i]) < 1.0 {
                temp[i] = temp1 + (temp2 - temp1) * 6.0 * temp[i]
            } else if (2.0 * temp[i]) < 1.0 {
                temp[i] = temp2
            } else if (3.0 * temp[i]) < 2.0 {
                temp[i] = temp1 + (temp2 - temp1) * ((2.0 / 3.0) - temp[i]) * 6.0
            } else {
                temp[i] = temp1
            }
        }
        // Assign temporary values to R, G, B
        return (r: temp[0], g: temp[1], b: temp[2])
    }

    // MARK: - some useful hard-coded colors
    public static let lightGrey = Draw.Color(red: 211.0 / 255.0, green: 211.0 / 255.0, blue: 211.0 / 255.0, alpha: 1.0)
    public static let black = Draw.Color(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    public static let red = Draw.Color(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
    public static let pinkish = Draw.Color(red: 1.0, green: 100.0 / 255.0, blue: 100.0 / 255.0, alpha: 1.0)
    public static let transparentBlue = Draw.Color(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.3)
    public static let transparentBlack = Draw.Color(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
    public static let blue = Draw.Color(red: 0.0, green: 0.0, blue: 255.0, alpha: 1.0)
    public static let green = Draw.Color(red: 0.0, green: 255.0, blue: 0.0, alpha: 1.0)

    private static var randomIndex = 0
    private static let randomColors: [CGColor] = {
        var temp: [CGColor] = []
        for i in 0..<360 {
            var j = (i*47) % 360
            let (r, g, b) = HSLToRGB(h: CGFloat(j) / 360.0, s: 0.5, l: 0.5)
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

    public static func drawCurve(_ context: CGContext, curve: BezierCurve, offset: CGPoint=CGPoint.zero) {
        context.beginPath()
        if let quadraticCurve = curve as? QuadraticCurve {
            context.move(to: quadraticCurve.p0 + offset)
            context.addQuadCurve(to: quadraticCurve.p2 + offset,
                                 control: quadraticCurve.p1 + offset)
        } else if let cubicCurve = curve as? CubicCurve {
            context.move(to: cubicCurve.p0 + offset)
            context.addCurve(to: cubicCurve.p3 + offset,
                             control1: cubicCurve.p1 + offset,
                             control2: cubicCurve.p2 + offset)
        } else if let lineSegment = curve as? LineSegment {
            context.move(to: lineSegment.p0 + offset)
            context.addLine(to: lineSegment.p1 + offset)
        } else {
            fatalError("unsupported curve type")
        }
        context.strokePath()
    }

    public static func drawCircle(_ context: CGContext, center: CGPoint, radius r: CGFloat, offset: CGPoint = .zero) {
        context.beginPath()
        context.addEllipse(in: CGRect(origin: CGPoint(x: center.x - r + offset.x, y: center.y - r + offset.y),
                            size: CGSize(width: 2.0 * r, height: 2.0 * r))
                            )
        context.strokePath()
    }

    public static func drawPoint(_ context: CGContext, origin o: CGPoint, offset: CGPoint = .zero) {
        self.drawCircle(context, center: o, radius: 5.0, offset: offset)

    }

    public static func drawPoints(_ context: CGContext,
                                  points: [CGPoint],
                                  offset: CGPoint=CGPoint(x: 0.0, y: 0.0)) {
        for p in points {
            self.drawCircle(context, center: p, radius: 3.0, offset: offset)
        }
    }

    public static func drawLine(_ context: CGContext,
                                from p0: CGPoint,
                                to p1: CGPoint,
                                offset: CGPoint=CGPoint(x: 0.0, y: 0.0)) {
        context.beginPath()
        context.move(to: p0 + offset)
        context.addLine(to: p1 + offset)
        context.strokePath()
    }

    public static func drawText(_ context: CGContext, text: String, offset: CGPoint = .zero) {
    #if os(macOS)
        (text as NSString).draw(at: NSPoint(x: offset.x, y: offset.y), withAttributes: [:])
    #else
        (text as NSString).draw(at: CGPoint(x: offset.x, y: offset.y), withAttributes: [:])
    #endif
    }

    public static func drawSkeleton(_ context: CGContext,
                                    curve: BezierCurve,
                                    offset: CGPoint=CGPoint(x: 0.0, y: 0.0),
                                    coords: Bool=true) {

        context.setStrokeColor(lightGrey)

        if let cubicCurve = curve as? CubicCurve {
            self.drawLine(context, from: cubicCurve.p0, to: cubicCurve.p1, offset: offset)
            self.drawLine(context, from: cubicCurve.p2, to: cubicCurve.p3, offset: offset)
        } else if let quadraticCurve = curve as? QuadraticCurve {
            self.drawLine(context, from: quadraticCurve.p0, to: quadraticCurve.p1, offset: offset)
            self.drawLine(context, from: quadraticCurve.p1, to: quadraticCurve.p2, offset: offset)
        }

        if coords == true {
            context.setStrokeColor(black)
            self.drawPoints(context, points: curve.points, offset: offset)
        }
    }

    public static func drawHull(_ context: CGContext, hull: [CGPoint], offset: CGPoint = .zero) {
        context.beginPath()
        if hull.count == 6 {
            context.move(to: hull[0])
            context.addLine(to: hull[1])
            context.addLine(to: hull[2])
            context.move(to: hull[3])
            context.addLine(to: hull[4])
        } else {
            context.move(to: hull[0])
            context.addLine(to: hull[1])
            context.addLine(to: hull[2])
            context.addLine(to: hull[3])
            context.move(to: hull[4])
            context.addLine(to: hull[5])
            context.addLine(to: hull[6])
            context.move(to: hull[7])
            context.addLine(to: hull[8])
        }
        context.strokePath()
    }

    public static func drawBoundingBox(_ context: CGContext, boundingBox: BoundingBox, offset: CGPoint = .zero) {
        context.beginPath()
        context.addRect(boundingBox.cgRect.offsetBy(dx: offset.x, dy: offset.y))
        context.closePath()
        context.strokePath()
    }

    public static func drawShape(_ context: CGContext, shape: Shape, offset: CGPoint = .zero) {
        let order = shape.forward.points.count - 1
        context.beginPath()
        context.move(to: offset + shape.startcap.curve.startingPoint)
        context.addLine(to: offset + shape.startcap.curve.endingPoint)
        if order == 3 {
            context.addCurve(to: offset + shape.forward.points[3],
                             control1: offset + shape.forward.points[1],
                             control2: offset + shape.forward.points[2]

            )
        } else {
            context.addQuadCurve(to: offset + shape.forward.points[2],
                                 control: offset + shape.forward.points[1]
            )
        }
        context.addLine(to: offset + shape.endcap.curve.endingPoint)
        if order == 3 {
            context.addCurve(to: offset + shape.back.points[3],
                control1: offset + shape.back.points[1],
                control2: offset + shape.back.points[2]
            )
        } else {
            context.addQuadCurve(to: offset + shape.back.points[2],
                                 control: offset + shape.back.points[1]
            )
        }
        context.closePath()
        context.drawPath(using: .fillStroke)

    }

    public static func drawPathComponent(_ context: CGContext, pathComponent: PathComponent, offset: CGPoint = .zero, includeBoundingVolumeHierarchy: Bool = false) {
        if includeBoundingVolumeHierarchy {
            pathComponent.bvh.visit { node, depth in
                setColor(context, color: randomColors[depth])
                context.setLineWidth(1.0)
                context.setLineWidth(5.0 / CGFloat(depth+1))
                context.setAlpha(1.0 / CGFloat(depth+1))
                drawBoundingBox(context, boundingBox: node.boundingBox, offset: offset)
                return true // always visit children
            }
        }
        Draw.setRandomFill(context, alpha: 0.2)
        context.addPath(Path(components: [pathComponent]).cgPath)
        context.drawPath(using: .fillStroke)
    }

    public static func drawPath(_ context: CGContext, _ path: Path, offset: CGPoint = .zero) {
        Draw.setRandomFill(context, alpha: 0.2)
        context.addPath(path.cgPath)
        context.drawPath(using: .fillStroke)
    }
}
