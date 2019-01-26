//
//  BoundingVolumeHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

internal class BVH {
    
    private let boundingBoxes: UnsafePointer<BoundingBox>
    private let inodeCount: Int
    private let lastRowIndex: Int
    private let elementCount: Int
        
    var boundingBox: BoundingBox {
        return self.boundingBoxes[0]
    }
    
    fileprivate static func leafNodeIndexToElementIndex(_ nodeIndex: Int, leafCount: Int, lastRowIndex: Int) -> Int {
        assert(nodeIndex + 1 >= leafCount, "not actually a leaf (index of left child is a valid node")
        var elementIndex = nodeIndex - lastRowIndex
        if elementIndex < 0 {
            elementIndex += leafCount
        }
        return elementIndex
    }
    
    init(boxes leafBoxes: [BoundingBox]) {
        // create a complete binary tree of bounding boxes where boxes[0] is the root and left child is 2*index+1 and right child is 2*index+2
        assert(leafBoxes.count > 0)
        let boxes = UnsafeMutablePointer<BoundingBox>.allocate(capacity: 2*leafBoxes.count-1)
        
        self.elementCount = leafBoxes.count
        self.inodeCount = leafBoxes.count-1
        
        var lastRowIndex = 0
        while lastRowIndex < self.inodeCount {
            lastRowIndex *= 2
            lastRowIndex += 1
        }
        self.lastRowIndex = lastRowIndex
        
        for i in 0..<leafBoxes.count {
            let nodeIndex = i+self.inodeCount
            let elementIndex = BVH.leafNodeIndexToElementIndex(nodeIndex, leafCount: leafBoxes.count, lastRowIndex: lastRowIndex)
            boxes[nodeIndex] = leafBoxes[elementIndex]
        }
        for i in stride(from: self.inodeCount-1, through: 0, by: -1) {
            boxes[i] = BoundingBox(first: boxes[2*i+1], second: boxes[2*i+2])
        }
        self.boundingBoxes = UnsafePointer<BoundingBox>(boxes)
    }
    
    deinit {
        self.boundingBoxes.deallocate()
    }
    
    func visit(callback: (BVHNode, Int) -> Bool) {
        func visit(index: Int, depth: Int, callback: (BVHNode, Int) -> Bool) {
            guard callback(BVHNode(boundingBox: self.boundingBoxes[index],
                                   type: index < self.inodeCount ? .internal: .leaf(elementIndex: BVH.leafNodeIndexToElementIndex(index, leafCount: self.elementCount, lastRowIndex: self.lastRowIndex))),
                           depth) == true else {
                return
            }
            if index < self.inodeCount {
                let nextDepth = depth + 1
                visit(index: 2*index+1, depth: nextDepth, callback: callback)
                visit(index: 2*index+2, depth: nextDepth, callback: callback)
            }
        }
        visit(index: 0, depth: 0, callback: callback)
    }
    
    func intersects(callback: (Int, Int) -> Void) {
        self.intersects(node: self, callback: callback)
    }
    
    func intersects(node other: BVH, callback: (Int, Int) -> Void) {
        let inodecount1 = self.inodeCount
        let inodecount2 = other.inodeCount
        let boxes1 = self.boundingBoxes
        let boxes2 = other.boundingBoxes
        let checkSelfIntersection = (other === self)
        func intersects(index1: Int, index2: Int, callback: (Int, Int) -> Void) {
            
            if checkSelfIntersection && index1 == index2 { // special handling for self-intersection
                if index1 >= inodecount1 { // if it's a leaf node
                    let elementIndex1 = BVH.leafNodeIndexToElementIndex(index1, leafCount: self.elementCount, lastRowIndex: self.lastRowIndex)
                    callback(elementIndex1, elementIndex1)
                }
                else {
                    let l = 2*index1+1
                    let r = 2*index1+2
                    intersects(index1: l, index2: l, callback: callback)
                    intersects(index1: l, index2: r, callback: callback)
                    intersects(index1: r, index2: r, callback: callback)
                }
                return
            }
            
            guard boxes1[index1].overlaps(boxes2[index2]) else {
                return // nothing to do
            }
            
            let leaf1 = index1 >= inodecount1
            let leaf2 = index2 >= inodecount2
            if leaf1, leaf2 {
                let elementIndex1 = BVH.leafNodeIndexToElementIndex(index1, leafCount: self.elementCount, lastRowIndex: self.lastRowIndex)
                let elementIndex2 = BVH.leafNodeIndexToElementIndex(index2, leafCount: other.elementCount, lastRowIndex: other.lastRowIndex)
                callback(elementIndex1, elementIndex2)
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
    let boundingBox: BoundingBox
    let nodeType: NodeType
    enum NodeType {
        case leaf(elementIndex: Int)
        case `internal`
    }
    fileprivate init(boundingBox: BoundingBox, type: NodeType) {
        self.nodeType = type
        self.boundingBox = boundingBox
    }
}
