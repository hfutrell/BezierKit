//
//  BoundingVolumeHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

internal class BVHNode {
    
    internal let boundingBox: BoundingBox
    
    internal let nodeType: NodeType
    
    internal enum NodeType {
        case leaf(object: BoundingBoxProtocol)
        case `internal`(list: [BVHNode])
    }
    
    convenience internal init(objects: [BoundingBoxProtocol]) {
        self.init(slice: ArraySlice<BoundingBoxProtocol>(objects))
    }
    
    internal func visit(callback: (BVHNode, Int) -> Bool) {
        self.visit(callback: callback, currentDepth: 0)
    }
    
    internal func intersects(node other: BVHNode, callback: (BoundingBoxProtocol, BoundingBoxProtocol) -> Void) {
        
        guard self.boundingBox.overlaps(other.boundingBox) else {
            return // nothing to do
        }
        
        if case let .leaf(object1) = self.nodeType {
            if case let .leaf(object2) = other.nodeType {
                callback(object1, object2)
            }
            else if case let .internal(list: list2) = other.nodeType {
                list2.forEach {
                    self.intersects(node: $0, callback: callback)
                }
            }
        }
        else if case let .`internal`(list: list1) = self.nodeType {
            if case .leaf(_) = other.nodeType {
                list1.forEach {
                    $0.intersects(node: other, callback: callback)
                }
            }
            else if case let .`internal`(list: list2) = other.nodeType {
                list1.forEach { node1 in
                    list2.forEach { node2 in
                        node1.intersects(node: node2, callback: callback)
                    }
                }
            }
        }
    }
    
    // MARK: - private
    
    private func visit(callback: (BVHNode, Int) -> Bool, currentDepth depth: Int) {
        guard callback(self, depth) == true else {
            return
        }
        if case let .`internal`(list: list) = self.nodeType {
            list.forEach {
                $0.visit(callback: callback, currentDepth: depth+1)
            }
        }
    }
    
    private init(slice: ArraySlice<BoundingBoxProtocol>) {
        if slice.isEmpty {
            self.nodeType = .internal(list: [])
            self.boundingBox = BoundingBox.empty
        }
        else if slice.count == 1 {
            let object = slice.first!
            self.nodeType = .leaf(object: object)
            self.boundingBox = object.boundingBox
        }
        else {
            let startIndex = slice.startIndex
            let splitIndex = ( slice.startIndex + slice.endIndex ) / 2
            let endIndex   = slice.endIndex
            let left    = BVHNode(slice: slice[startIndex..<splitIndex])
            let right   = BVHNode(slice: slice[splitIndex..<endIndex])
            let boundingBox = BoundingBox(first: left.boundingBox, second: right.boundingBox)
            self.boundingBox = boundingBox
            if slice.count > 2 {
                // an optimization when at least one of left or right is not a leaf node
                // check the surface-area heuristic to see if we actually get a better result by putting
                // the descendents of left and right as child nodes of self
                func descendents(_ node: BVHNode) -> [BVHNode] {
                    switch node.nodeType {
                    case .leaf(_):
                        return [node]
                    case let .internal(list):
                        return list
                    }
                }
                let leftDescendents     = descendents(left)
                let rightDescendents    = descendents(right)
                let costLeft            = CGFloat(leftDescendents.count) * ( 1.0 - left.boundingBox.area / boundingBox.area )
                let costRight           = CGFloat(rightDescendents.count) * ( 1.0 - right.boundingBox.area / boundingBox.area )
                if 2 > costLeft + costRight {
                    self.nodeType = .internal(list: leftDescendents + rightDescendents)
                    return
                }
            }
            self.nodeType = .internal(list: [left, right])
        }
    }
}
