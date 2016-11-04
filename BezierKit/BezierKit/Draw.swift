//
//  Draw.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/29/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

// should Draw just be an extension of CGContext, or have a CGContext instead of passing it in to all these functions?
class Draw {
    
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
            return;
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
                temp[i] = temp1 + (temp2 - temp1) * 6.0 * temp[i];
            }
            else {
                if (2.0 * temp[i]) < 1.0 {
                    temp[i] = temp2;
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
        outR = temp[0];
        outG = temp[1];
        outB = temp[2];
    }

    
    static let lightGrey = CGColor(red: 211.0 / 255.0, green: 211.0 / 255.0, blue: 211.0 / 255.0, alpha: 1.0)
    static let black = CGColor.black
    private static var randomIndex = 0
    private static let randomColors: [CGColor] = {
        var temp: [CGColor] = [];
        for i in 0..<360 {
            var j = (i*47) % 360
            var r: CGFloat = 0.0;
            var g: CGFloat = 0.0;
            var b: CGFloat = 0.0;
            HSLToRGB(h: CGFloat(j) / 360.0, s: 0.5, l: 0.5, outR: &r, outG: &g, outB: &b)
            
            temp.append(CGColor(red: r, green: g, blue: b, alpha: 1.0));
        }
        return temp
    }()
    
    static func reset(_ context: CGContext) {
        context.setStrokeColor(black)
        randomIndex = 0;
    }
    
    static func setRandomColor(_ context: CGContext) {
        randomIndex = (randomIndex+1) % randomColors.count
        let c = randomColors[randomIndex];
        context.setStrokeColor(c);
    }
    
    static func setColor(_ context: CGContext, color: CGColor) {
        context.setStrokeColor(color)
    }
    
    static func drawCurve(_ context: CGContext, curve: CubicBezier, offset: BKPoint=BKPoint(x:0.0, y: 0.0)) {
        context.beginPath()
        context.move(to: curve.p0 + offset)
        context.addCurve(to: curve.p3 + offset,
                         control1: curve.p1 + offset,
                         control2: curve.p2 + offset)
        context.strokePath()
    }
    
    static func drawCircle(_ context: CGContext, center: BKPoint, radius r : Double, offset: BKPoint=BKPoint(x:0.0, y: 0.0)) {
        context.beginPath()
        context.addEllipse(in: CGRect(origin: center - CGPoint(x: r, y: r),
                            size: CGSize(width: 2.0 * r, height: 2.0 * r))
                            )
        context.strokePath()
    }
    
    static func drawPoints(_ context: CGContext,
                    points: [BKPoint],
                    offset: BKPoint=BKPoint(x: 0.0, y: 0.0)) {
        for p in points {
            self.drawCircle(context, center: p, radius: 3.0, offset: offset)
        }
    }
    
    static func drawLine(_ context: CGContext,
                  from p0: BKPoint,
                  to p1: BKPoint,
                  offset: BKPoint=BKPoint(x: 0.0, y: 0.0)) {
        context.beginPath()
        context.move(to: p0 + offset)
        context.addLine(to: p1 + offset)
        context.strokePath()
    }
 
    static func drawSkeleton(_ context: CGContext,
                  curve: CubicBezier,
                  offset: BKPoint=BKPoint(x: 0.0, y: 0.0),
                  coords: Bool=true) {
    
        context.setStrokeColor(lightGrey)
        
        self.drawLine(context, from: curve.p0, to: curve.p1, offset: offset)
        self.drawLine(context, from: curve.p2, to: curve.p3, offset: offset)
        
        context.setStrokeColor(black)
        if (coords == true) {
            self.drawPoints(context, points: curve.points)
        }
        
    }
    
}
