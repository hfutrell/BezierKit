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
        case leaf(elementIndex: Int)
        case `internal`(left: BVHNode, right: BVHNode)
    }
    
    convenience internal init(boxes: [BoundingBox]) {
        self.init(slice: ArraySlice<BoundingBox>(boxes))
    }
    
    internal func visit(callback: (BVHNode, Int) -> Bool) {
        self.visit(callback: callback, currentDepth: 0)
    }
    
    internal func intersects(node other: BVHNode, callback: (BoundingBoxProtocol, BoundingBoxProtocol, Int, Int) -> Void) {
        
        guard self.boundingBox.overlaps(other.boundingBox) else {
            return // nothing to do
        }
        
        if case let .leaf(object1, elementIndex1) = self.nodeType {
            if case let .leaf(object2, elementIndex2) = other.nodeType {
                callback(object1, object2, elementIndex1, elementIndex2)
            }
            else if case let .internal(left: left, right: right) = other.nodeType {
                self.intersects(node: left, callback: callback)
                self.intersects(node: right, callback: callback)
            }
        }
        else if case let .internal(left: left1, right: right1) = self.nodeType {
            if case .leaf(_) = other.nodeType {
                left1.intersects(node: other, callback: callback)
                right1.intersects(node: other, callback: callback)
            }
            else if case let .internal(left: left2, right: right2) = other.nodeType {
                left1.intersects(node: left2, callback: callback)
                left1.intersects(node: right2, callback: callback)
                right1.intersects(node: left2, callback: callback)
                right1.intersects(node: right2, callback: callback)
            }
        }
    }
    
    // MARK: - private
    
    private func visit(callback: (BVHNode, Int) -> Bool, currentDepth depth: Int) {
        guard callback(self, depth) == true else {
            return
        }
        if case let .`internal`(left: left, right: right) = self.nodeType {
            left.visit(callback: callback, currentDepth: depth+1)
            right.visit(callback: callback, currentDepth: depth+1)
        }
    }
    
    private init(slice: ArraySlice<BoundingBox>) {
        
        assert(slice.isEmpty == false)
        
        if slice.count == 1 {
            let object = slice.first!
            self.nodeType = .leaf(elementIndex: slice.startIndex)
            self.boundingBox = object
        }
        else {
            let startIndex = slice.startIndex
            let splitIndex = ( slice.startIndex + slice.endIndex ) / 2
            let endIndex   = slice.endIndex
            let left    = BVHNode(slice: slice[startIndex..<splitIndex])
            let right   = BVHNode(slice: slice[splitIndex..<endIndex])
            let boundingBox = BoundingBox(first: left.boundingBox, second: right.boundingBox)
            self.boundingBox = boundingBox
            self.nodeType = .internal(left: left, right: right)
        }
    }
}
