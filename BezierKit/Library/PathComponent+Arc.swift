//
//  PathComponent+Arc.swift
//  BezierKit
//
//  Created by ky1vstar on 15.10.2020.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

import Foundation

extension PathComponent {
    public convenience init(
        ovalIn rect: CGRect,
        numberOfCurves: Int = 4
    ) {
        let diameter = min(rect.width, rect.height)
        let radius = diameter / 2
        
        let tempPath = PathComponent(
            arcCenter: .init(x: radius, y: radius),
            radius: radius,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true
            numberOfCurves: numberOfCurves
        )
        
        let transform = CGAffineTransform.identity
            .translatedBy(x: rect.origin.x, y: rect.origin.y)
            .scaledBy(
                x: rect.width / diameter,
                y: rect.height / diameter
            )
        
        self.init(
            points: tempPath.points.map {
                $0.applying(transform)
            },
            orders: tempPath.orders
        )
    }
    
    public convenience init(
        arcCenter center: CGPoint,
        radius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat,
        clockwise: Bool,
        numberOfCurves: Int = 4
    ) {
        precondition(numberOfCurves > 0)
        
        var curves = [CubicCurve]()
        let distance = Self.distanceBetween(
            startAngle,
            endAngle,
            clockwise: clockwise
        )
        let unitRadians = 2 * .pi / CGFloat(numberOfCurves)
        let numberOfFullUnits = Int(distance / unitRadians)
        let isClosed = numberOfFullUnits == numberOfCurves
        var currentPoint = CGPoint.zero
        
        func addArc(
            unitRadians: CGFloat,
            rotateRadians: CGFloat,
            endPoint: CGPoint? = nil
        ) {
            let transform = CGAffineTransform
                .init(scaleX: radius, y: radius)
                .rotated(by: rotateRadians)
            let cp1 = Self.controlPoint1(unitRadians)
                .applying(transform)
            let cp2 = Self.controlPoint2(unitRadians)
                .applying(transform)
            let endPoint = endPoint ?? (CGPoint(x: cos(unitRadians), y: sin(unitRadians))
                .applying(transform))
            
            let curve = CubicCurve(
                p0: currentPoint, p1: cp1,
                p2: cp2, p3: endPoint
            )
            curves.append(curve)
            currentPoint = endPoint
        }
        
        currentPoint = CGPoint(x: radius, y: 0)
        for i in 0 ..< numberOfFullUnits {
            var endPoint: CGPoint?
            if isClosed && i == numberOfFullUnits - 1 {
                endPoint = CGPoint(x: radius, y: 0)
            }
            addArc(
                unitRadians: unitRadians,
                rotateRadians: unitRadians * CGFloat(i),
                endPoint: endPoint
            )
        }
        
        if !isClosed {
            let rotateRadians = unitRadians * CGFloat(numberOfFullUnits)
            addArc(
                unitRadians: distance - rotateRadians,
                rotateRadians: rotateRadians
            )
        }
        
        var finalTransform = CGAffineTransform.identity
        finalTransform = finalTransform
            .translatedBy(x: center.x, y: center.y)
            .rotated(by: startAngle)
        if !clockwise {
            finalTransform = finalTransform
                .scaledBy(x: 1, y: -1)
        }
        curves = curves.map {
            CubicCurve(points: $0.points.map {
                $0.applying(finalTransform)
            })
        }
        
        self.init(curves: curves)
    }
    
    private static func distanceBetween(
        _ startRadians: CGFloat,
        _ endRadians: CGFloat,
        clockwise: Bool
    ) -> CGFloat {
        var startRadians = normalizeRadians(startRadians)
        var endRadians = normalizeRadians(endRadians)
        if !clockwise {
            swap(&startRadians, &endRadians)
        }
        let tau = CGFloat.pi * 2
        
        if endRadians > startRadians {
            return endRadians - startRadians
        } else {
            return tau - (startRadians - endRadians)
        }
    }
    
    private static func normalizeRadians(_ radians: CGFloat) -> CGFloat {
        let width = 2 * CGFloat.pi
        return radians - (floor(radians / width) * width)
    }
    
    private static func controlPoint1(_ radians: CGFloat) -> CGPoint {
        .init(
            x: 1,
            y: l(radians)
        )
    }
    
    private static func controlPoint2(_ radians: CGFloat) -> CGPoint {
        .init(
            x: cos(radians) + l(radians) * sin(radians),
            y: sin(radians) - l(radians) * cos(radians)
        )
    }
    
    private static func l(_ radians: CGFloat) -> CGFloat {
        4 / 3 * tan(radians / 4)
    }
}
