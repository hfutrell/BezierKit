//
//  PathComponent+Project.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

import Foundation

public extension PathComponent {
    func project(_ point: CGPoint) -> (point: CGPoint, location: IndexedPathComponentLocation) {
        var bestLocation = self.startingIndexedLocation
        var bestDistance = distanceSquared(point, self.startingPoint)
        curves.enumerated().forEach { index, curve in
            let projection = curve.project(point)
            let distance = distanceSquared(projection.point, point)
            if distance < bestDistance {
                bestDistance = distance
                bestLocation = IndexedPathComponentLocation(elementIndex: index, t: projection.t)
            }
        }
        return (point: self.point(at: bestLocation), location: bestLocation)
    }
    @objc(point:isWithinDistanceOfBoundary:) func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat) -> Bool {
        var found = false
        self.bvh.visit { node, _ in
            let boundingBox = node.boundingBox
            if boundingBox.upperBoundOfDistance(to: p) <= d {
                found = true
            } else if case let .leaf(elementIndex) = node.type {
                let curve = self.element(at: elementIndex)
                if distance(p, curve.project(p).point) < d {
                    found = true
                }
            }
            return !found && node.boundingBox.lowerBoundOfDistance(to: p) <= d
        }
        return found
    }
}
