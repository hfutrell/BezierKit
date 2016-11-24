//
//  Types.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

struct BKPoint {
    var x : BKFloat
    var y : BKFloat
    var z : BKFloat
    init(x: BKFloat, y: BKFloat, z: BKFloat = 0.0) {
        self.x = x
        self.y = y
        self.z = z
    }
    init(_ p: CGPoint) {
        self.x = p.x
        self.y = p.y
        self.z = 0.0
    }
    func equalTo(_ other: BKPoint) -> Bool {
        if x != other.x {
            return false
        }
        if y != other.y {
            return false
        }
        if z != other.z {
            return false
        }
        return true
    }
}

struct BoundingBox {
    var min: BKPoint
    var max: BKPoint
    var mid: BKPoint {
        return (min + max)/2.0
    }
    var size: BKPoint {
        return max - min
    }
    var toCGRect: CGRect {
        let s = self.size
        return CGRect(origin: self.min.toCGPoint(), size: CGSize(width: s.x, height: s.y))
    }
}

let BKPointZero: BKPoint = BKPoint(x: 0.0, y: 0.0, z: 0.0)

extension CGPoint {
    init(_ p: BKPoint) {
        self.x = p.x
        self.y = p.y
    }
}

typealias BKFloat = CGFloat
typealias BKRect = CGRect

extension BKPoint {
    var length: BKFloat {
        return sqrt(self.lengthSquared)
    }
    var lengthSquared: CGFloat {
        let x = self.x
        let y = self.y
        let z = self.z
        return x * x + y * y + z * z
    }
    func normalize() -> BKPoint {
        return self / self.length
    }
    func toCGPoint() -> CGPoint {
        return CGPoint(self)
    }
}
func += ( left: inout BKPoint, right: BKPoint) {
    return left = left + right
}
func -= ( left: inout BKPoint, right: BKPoint) {
    return left = left - right
}
func + (left: BKPoint, right: BKPoint) -> BKPoint {
    return BKPoint(x: left.x + right.x, y: left.y + right.y, z: left.z + right.z)
}
func - (left: BKPoint, right: BKPoint) -> BKPoint {
    return BKPoint(x: left.x - right.x, y: left.y - right.y, z: left.z - right.z)
}
func / (left: BKPoint, right: BKFloat) -> BKPoint {
    return BKPoint(x: left.x / right, y: left.y / right, z: left.z / right)
}
func * (left: BKPoint, right: BKFloat) -> BKPoint {
    return BKPoint(x: left.x * right, y: left.y * right, z: left.z * right)
}
