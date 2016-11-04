//
//  Draw.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/29/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

class Draw {
    
    static let lightGrey = CGColor(red: 211.0 / 255.0, green: 211.0 / 255.0, blue: 211.0 / 255.0, alpha: 1.0)
    static let black = CGColor.black
    
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
