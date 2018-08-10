//
//  BoundingVolumeHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import Foundation

private class BVHNode<A> where A: BoundingBoxProtocol {
    var boundingBox: BoundingBox = BoundingBox.empty
    var children: [BVHNode<A>] = []
    
    var object: A? = nil
    
    var cost: CGFloat {
        if children.count == 0 {
            return 5.0 // cost of intersecting a primitive
        }
        else {
            let totalArea = self.boundingBox.area
            // constant cost of bounding rect intersection over each child plus the cost of each child times the probability it gets intersected
            return 1.0 * CGFloat(children.count) + children.reduce(CGFloat(0.0)) { $0 + $1.area * $1.cost } / totalArea
        }
    }
    
    var area: CGFloat {
        return self.boundingBox.area
    }
    
    private func costOfAddingInternalNode(child c: BVHNode) -> CGFloat {
        let areaWithC = BoundingBox(first: self.boundingBox, second: c.boundingBox).area
        return 1.0 + (c.area/areaWithC) * c.cost + self.existingInternalNodeCosts * ((1.0 / areaWithC) - (1.0 / self.area))
    }
    
    private func costOfPassingToChildren(child c: BVHNode, bestChildIndex: inout Int) -> CGFloat {
        var bestCost: CGFloat? = nil
        for i in 0..<children.count {
            let change = // ???
            if bestCost == nil || change < bestCost! {
                bestCost = change
                bestChildIndex = i
            }
        }
        return bestCost!
    }
    
    internal func insert(node: BVHNode) {
        let nodeBoundingBox = node.boundingBox
        guard children.count > 0 else {
            self.children.append(node)
            self.boundingBox = BoundingBox(first: self.boundingBox, second: nodeBoundingBox)
            return
        }
        let cost1 = self.costOfAddingInternalNode(child: node)
        var bestChildIndex = 0
        let cost2 = self.costOfPassingToChildren(child: node, bestChildIndex: &bestChildIndex)
        if cost1 < cost2 {
            self.children.append(node)
        }
        else {
            self.children[bestChildIndex].insert(node: node)
        }
        self.boundingBox = BoundingBox(first: self.boundingBox, second: nodeBoundingBox)
    }
    
}

public class BoundingVolumeHierarchy<A> where A: BoundingBoxProtocol {
    
    private let root: BVHNode<A> = BVHNode<A>()
    
    public init(objects: [A]) {
        objects.forEach {
            let node = BVHNode<A>()
            node.object = $0
            root.insert(node: node)
        }
    }
}
