//
//  Path+Project.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

import Foundation

private enum SearchCriteria: Equatable {
    case best
    case lessThanOrEqualTo(distance: CGFloat)
}

public extension Path {
    private typealias ComponentTuple = (component: PathComponent, index: Int, lowerBound: CGFloat, upperBound: CGFloat)
    private typealias Candidate = (point: CGPoint, location: IndexedPathLocation, distance: CGFloat)
    private func searchForClosestLocation(to point: CGPoint, criteria: SearchCriteria) -> (point: CGPoint, location: IndexedPathLocation)? {
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
        }
        return nil
    }
    func project(_ point: CGPoint) -> (point: CGPoint, location: IndexedPathLocation)? {
        return self.searchForClosestLocation(to: point, criteria: .best)
    }
    @objc(point:isWithinDistanceOfBoundary:) func pointIsWithinDistanceOfBoundary(_ point: CGPoint, distance: CGFloat) -> Bool {
        guard let result = self.searchForClosestLocation(to: point, criteria: .lessThanOrEqualTo(distance: distance)) else {
            return false
        }
        return BezierKit.distance(result.point, point) <= distance
    }
}

public extension PathComponent {
    private func anyLocation(in node: BoundingBoxHierarchy.Node) -> IndexedPathComponentLocation {
        switch node.type {
        case .leaf(let elementIndex):
            return IndexedPathComponentLocation(elementIndex: elementIndex, t: 0)
        case .internal(let startingElementIndex, _):
            return IndexedPathComponentLocation(elementIndex: startingElementIndex, t: 0)
        }
    }
    private func searchForClosestLocation(to point: CGPoint, criteria: SearchCriteria) -> (point: CGPoint, location: IndexedPathComponentLocation)? {
        var bestSoFar: IndexedPathComponentLocation?
        var bestUpperBoundSoFar: CGFloat = CGFloat.infinity
        var done = false
        if case let .lessThanOrEqualTo(distance) = criteria {
            bestUpperBoundSoFar = distance
        }
        self.bvh.visit { node, _ in
            let boundingBox = node.boundingBox
            let lowerBound = boundingBox.lowerBoundOfDistance(to: point)
            guard !done else {
                return false
            }
            guard lowerBound < bestUpperBoundSoFar else {
                return false
            }
            let upperBound = boundingBox.upperBoundOfDistance(to: point)
            if upperBound < bestUpperBoundSoFar {
                bestUpperBoundSoFar = upperBound
                bestSoFar = self.anyLocation(in: node)
                if case .lessThanOrEqualTo(_) = criteria {
                    done = true
                    return false
                }
            }
            if case .leaf(let elementIndex) = node.type {
                let curve = self.element(at: elementIndex)
                let projection = curve.project(point)
                let distanceToCurve = distance(point, projection.point)
                if distanceToCurve < bestUpperBoundSoFar {
                    bestUpperBoundSoFar = distanceToCurve
                    bestSoFar = IndexedPathComponentLocation(elementIndex: elementIndex, t: projection.t)
                    if case .lessThanOrEqualTo(_) = criteria {
                        done = true
                        return false
                    }
                }
            }
            return true // visit chidlren
        }
        if let bestSoFar = bestSoFar {
            return (point: self.point(at: bestSoFar), location: bestSoFar)
        } else {
            assert(criteria != .best, "unexpectedly empty result")
            return nil
        }
    }
    func project(_ point: CGPoint) -> (point: CGPoint, location: IndexedPathComponentLocation) {
        guard let result = self.searchForClosestLocation(to: point, criteria: .best) else {
            assertionFailure("expected non-empty result")
            return (point: self.startingPoint, self.startingIndexedLocation)
        }
        return result
    }
    @objc(point:isWithinDistanceOfBoundary:) func pointIsWithinDistanceOfBoundary(_ point: CGPoint, distance: CGFloat) -> Bool {
        guard let result = self.searchForClosestLocation(to: point, criteria: .lessThanOrEqualTo(distance: distance)) else {
            return false
        }
        return BezierKit.distance(result.point, point) <= distance
    }
}
