//
//  BoundingVolumeHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

internal class BVH {
    
    fileprivate var boundingBoxes: [BoundingBox]
    
    fileprivate var root: BVHNode {
        return BVHNode(index: 0, bvh: Unmanaged.passUnretained(self) )
    }
    
    internal var boundingBox: BoundingBox {
        return boundingBoxes.first!
    }
    
    internal init(boxes leafBoxes: [BoundingBox]) {
        // create a complete binary tree of bounding boxes where boxes[0] is the root and left child is 2*index+1 and right child is 2*index+2
        var boxes = [BoundingBox](repeating: BoundingBox.empty, count: leafBoxes.count - 1) + leafBoxes
        if leafBoxes.count > 1 {
            for i in stride(from: leafBoxes.count-2, through: 0, by: -1) {
                boxes[i] = BoundingBox(first: boxes[2*i+1], second: boxes[2*i+2])
            }
        }
        self.boundingBoxes = boxes
    }
    
    internal func visit(callback: (BVHNode, Int) -> Bool) {
        guard self.boundingBoxes.isEmpty == false else {
            return
        }
        root.visit(callback: callback)
    }
    
    internal func intersects(node other: BVH, callback: (Int, Int) -> Void) {
        self.root.intersects(node: other.root, callback: callback)
    }
}

internal struct BVHNode {
    
    private let bvh: Unmanaged<BVH>
    fileprivate let index: Int
    
    fileprivate init(index: Int, bvh: Unmanaged<BVH>) {
        self.bvh = bvh
        self.index = index
    }
    
    internal var boundingBox: BoundingBox {
        return self.bvh.takeUnretainedValue().boundingBoxes[index]
    }
    
    internal var nodeType: NodeType {
        let count = self.bvh.takeUnretainedValue().boundingBoxes.count
        let internalNodeCount = (count-1)/2
        if index < internalNodeCount {
            return .internal
        }
        else {
            return .leaf(elementIndex: index - internalNodeCount)
        }
    }
    
    internal enum NodeType {
        case leaf(elementIndex: Int)
        case `internal`
    }
    
    fileprivate var left: BVHNode {
        return BVHNode(index: 2 * self.index + 1, bvh: self.bvh)
    }
    
    fileprivate var right: BVHNode {
        return BVHNode(index: 2 * self.index + 2, bvh: self.bvh)
    }

    fileprivate func visit(callback: (BVHNode, Int) -> Bool) {
        self.visit(callback: callback, currentDepth: 0)
    }
    
    fileprivate func intersects(node other: BVHNode, callback: (Int, Int) -> Void) {
        guard self.boundingBox.overlaps(other.boundingBox) else {
            return // nothing to do
        }
        if case let .leaf(elementIndex1) = self.nodeType {
            if case let .leaf(elementIndex2) = other.nodeType {
                callback(elementIndex1, elementIndex2)
            }
            else if case .internal = other.nodeType {
                self.intersects(node: other.left, callback: callback)
                self.intersects(node: other.right, callback: callback)
            }
        }
        else if case .internal = self.nodeType {
            let left = self.left
            let right = self.right
            if case .leaf(_) = other.nodeType {
                left.intersects(node: other, callback: callback)
                right.intersects(node: other, callback: callback)
            }
            else if case .internal = other.nodeType {
                left.intersects(node: other.left, callback: callback)
                left.intersects(node: other.right, callback: callback)
                right.intersects(node: other.left, callback: callback)
                right.intersects(node: other.right, callback: callback)
            }
        }
    }
    
    // MARK: - private
    
    private func visit(callback: (BVHNode, Int) -> Bool, currentDepth depth: Int) {
        guard callback(self, depth) == true else {
            return
        }
        if case .`internal` = self.nodeType {
            self.left.visit(callback: callback, currentDepth: depth+1)
            self.right.visit(callback: callback, currentDepth: depth+1)
        }
    }
}
