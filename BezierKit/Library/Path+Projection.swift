//
//  Path+Project.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

import Foundation

public extension Path {
    private typealias ComponentTuple = (component: PathComponent, index: Int, lowerBound: CGFloat, upperBound: CGFloat)
    private typealias Candidate = (point: CGPoint, location: IndexedPathLocation, distance: CGFloat)
    func project(_ point: CGPoint) -> (point: CGPoint, location: IndexedPathLocation)? {
        let tuples: [ComponentTuple]
        // TODO: do we really need to map and sort a bunch of components that we might not even need to search?
        // sort the components by proximity to avoid searching distant components later on
        tuples = self.components.enumerated().map { i, component in
            let boundingBox = component.boundingBox
            let lower = boundingBox.lowerBoundOfDistance(to: point)
            let upper = boundingBox.upperBoundOfDistance(to: point)
            return (component: component, index: i, lowerBound: lower, upperBound: upper)
        }.sorted(by: { $0.upperBound < $1.upperBound })
        // iterate through each component and find the closest point
        let best = tuples.reduce(nil) { (bestSoFar: Candidate?, next: ComponentTuple) in
            if let best = bestSoFar, next.lowerBound > best.distance {
                // `lowerBound` guarantees distance is further than best so far, so skip searching this component
                return bestSoFar
            }
            let projection = next.component.project(point)
            let candidate = (point: projection.point,
                             location: IndexedPathLocation(componentIndex: next.index, locationInComponent: projection.location),
                             distance: distance(point, projection.point))
            if let bestSoFar = bestSoFar, bestSoFar.distance <= candidate.distance {
                return bestSoFar
            }
            return candidate
        }
        // return the best answer
        if let best = best {
            return (point: best.point, location: best.location)
        } else {
            return nil
        }
    }
    @objc(point:isWithinDistanceOfBoundary:) func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat) -> Bool {
        return self.components.contains {
            $0.pointIsWithinDistanceOfBoundary(point: p, distance: d)
        }
    }
}
