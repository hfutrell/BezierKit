//
//  BoundingVolumeHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

internal class BVH {
    
    fileprivate let boundingBoxes: UnsafePointer<BoundingBox>?
    fileprivate var inodeCount: Int
    
    fileprivate var root: BVHNode {
        return BVHNode(index: 0, bvh: Unmanaged.passUnretained(self) )
    }
    
    internal var boundingBox: BoundingBox {
        if let boxes = self.boundingBoxes {
            return boxes[0]
        }
        else {
            return BoundingBox.empty
        }
    }
    
    internal init(boxes leafBoxes: [BoundingBox]) {
        // create a complete binary tree of bounding boxes where boxes[0] is the root and left child is 2*index+1 and right child is 2*index+2
        let boxes = UnsafeMutablePointer<BoundingBox>.allocate(capacity: 2*leafBoxes.count-1)
        self.inodeCount = leafBoxes.count-1
        for i in 0..<leafBoxes.count {
            boxes[i+self.inodeCount] = leafBoxes[i]
        }
        for i in stride(from: self.inodeCount-1, through: 0, by: -1) {
            boxes[i] = BoundingBox(first: boxes[2*i+1], second: boxes[2*i+2])
        }
        self.boundingBoxes = UnsafePointer<BoundingBox>(boxes)
    }
    
    deinit {
        self.boundingBoxes?.deallocate()
    }
    
    internal func visit(callback: (BVHNode, Int) -> Bool) {
        guard self.boundingBoxes != nil else {
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
        let inodecount1 = self.inodeCount
        let inodecount2 = other.inodeCount
        guard let boxes1 = self.boundingBoxes, let boxes2 = other.boundingBoxes else {
            return
        }
        func intersects(index1: Int, index2: Int, callback: (Int, Int) -> Void) {
            guard boxes1[index1].overlaps(boxes2[index2]) else {
                return // nothing to do
            }
            let leaf1 = index1 >= inodecount1
            let leaf2 = index2 >= inodecount2
            if leaf1, leaf2 {
                callback(index1 - inodecount1, index2 - inodecount2)
            }
            else if leaf1 {
                intersects(index1: index1, index2: 2*index2+1, callback: callback)
                intersects(index1: index1, index2: 2*index2+2, callback: callback)
            }
            else if leaf2 {
                intersects(index1: 2*index1+1, index2: index2, callback: callback)
                intersects(index1: 2*index1+2, index2: index2, callback: callback)
            }
            else {
                intersects(index1: 2*index1+1, index2: 2*index2+1, callback: callback)
                intersects(index1: 2*index1+1, index2: 2*index2+2, callback: callback)
                intersects(index1: 2*index1+2, index2: 2*index2+1, callback: callback)
                intersects(index1: 2*index1+2, index2: 2*index2+2, callback: callback)
            }
        }
        intersects(index1: 0, index2: 0, callback: callback)
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
        return self.bvh.takeUnretainedValue().boundingBoxes![index]
    }
    
    internal var nodeType: NodeType {
        let internalNodeCount = self.bvh.takeUnretainedValue().inodeCount
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
