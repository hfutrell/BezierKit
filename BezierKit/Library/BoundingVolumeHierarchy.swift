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
        
//        func intersects(index: Int, callback: (Int) -> Void) {
//            if index >= inodecount { // if it's a leaf node
//                callback(index - inodecount, index - inodecount)
//            }
//            else {
//                let l = 2*index+1
//                let r = 2*index+2
//                intersects(index: l, callback: callback)
//                intersects(index1: l, index2: r, callback: callback)
//                intersects(index: r, callback: callback)
//            }
//        }
//
//        func intersects(index1: Int, index2: Int, callback: (Int) -> Void) {
//            guard boundingBoxes[index1].overlaps(boundingBoxes[index2]) else {
//                return // nothing to do
//            }
//            let leaf1 = index1 >= inodecount
//            let leaf2 = index2 >= inodecount
//            if leaf1, leaf2 {
//                callback(index1 - inodecount, index2 - inodecount)
//            }
//            else if leaf1 {
//                intersects(index1: index1, index2: 2*index2+1, callback: callback)
//                intersects(index1: index1, index2: 2*index2+2, callback: callback)
//            }
//            else if leaf2 {
//                intersects(index1: 2*index1+1, index2: index2, callback: callback)
//                intersects(index1: 2*index1+2, index2: index2, callback: callback)
//            }
//            else {
//                intersects(index1: 2*index1+1, index2: 2*index2+1, callback: callback)
//                intersects(index1: 2*index1+1, index2: 2*index2+2, callback: callback)
//                intersects(index1: 2*index1+2, index2: 2*index2+1, callback: callback)
//                intersects(index1: 2*index1+2, index2: 2*index2+2, callback: callback)
//            }
//        }
//

        
        func intersects(index1: Int, index2: Int, boxes1: [BoundingBox], boxes2: [BoundingBox], callback: (Int, Int) -> Void) {
            guard boxes1[index1].overlaps(boxes2[index2]) else {
                return // nothing to do
            }
            let inodecount1 = (boxes1.count-1)/2
            let inodecount2 = (boxes2.count-1)/2
            let leaf1 = index1 >= inodecount1
            let leaf2 = index2 >= inodecount2
            if leaf1, leaf2 {
                callback(index1 - inodecount1, index2 - inodecount2)
            }
            else if leaf1 {
                intersects(index1: index1, index2: 2*index2+1, boxes1: boxes1, boxes2: boxes2, callback: callback)
                intersects(index1: index1, index2: 2*index2+2, boxes1: boxes1, boxes2: boxes2, callback: callback)
            }
            else if leaf2 {
                intersects(index1: 2*index1+1, index2: index2, boxes1: boxes1, boxes2: boxes2, callback: callback)
                intersects(index1: 2*index1+2, index2: index2, boxes1: boxes1, boxes2: boxes2, callback: callback)
            }
            else {
                intersects(index1: 2*index1+1, index2: 2*index2+1, boxes1: boxes1, boxes2: boxes2, callback: callback)
                intersects(index1: 2*index1+1, index2: 2*index2+2, boxes1: boxes1, boxes2: boxes2, callback: callback)
                intersects(index1: 2*index1+2, index2: 2*index2+1, boxes1: boxes1, boxes2: boxes2, callback: callback)
                intersects(index1: 2*index1+2, index2: 2*index2+2, boxes1: boxes1, boxes2: boxes2, callback: callback)
            }
        }
        guard self.boundingBoxes.isEmpty == false, other.boundingBoxes.isEmpty == false else {
            return
        }
        intersects(index1: 0, index2: 0, boxes1: self.boundingBoxes, boxes2: other.boundingBoxes, callback: callback)
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
