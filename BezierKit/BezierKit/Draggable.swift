//
//  Draggable.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

typealias DraggableCallback = (_ dragPosition: BKPoint) -> (BKPoint)

protocol DraggableDelegate: class {
    func draggable(_ draggable: Draggable, didUpdateLocation location: BKPoint)
}

class Draggable {
    
    private(set) public var location: BKPoint
    public weak var delegate: DraggableDelegate?
    private let callback: DraggableCallback
    public let radius: Double
    
    public init(initialLocation location: BKPoint, radius: Double, callback: @escaping DraggableCallback) {
        self.location = location
        self.radius = radius
        self.callback = callback
    }
    public convenience init(initialLocation location: BKPoint, radius: Double) {
        let callback: DraggableCallback = { (dragPosition: BKPoint) -> (BKPoint) in
            return dragPosition
        }
        self.init(initialLocation: location, radius: radius, callback: callback)
    }
    public func updateLocation(_ location: BKPoint) {
        let updatedLocation = self.callback(location)
        if self.location.equalTo(updatedLocation) == false {
            self.location = updatedLocation
            self.delegate!.draggable(self, didUpdateLocation: updatedLocation)
        }
    }
    public func containsLocation(_ location: BKPoint) -> Bool {
        let c = self.cursorRect as CGRect
        return c.contains(location)
    }
    public var cursorRect: NSRect {
        get {
            let r = self.radius
            let r2 = 2.0 * r
            return CGRect( origin: self.location - CGPoint(x: r, y: r),
                           size: CGSize(width: r2, height: r2))
        }
    }
    
}
