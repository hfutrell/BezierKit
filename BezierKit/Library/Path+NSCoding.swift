//
//  Path+NSCoding.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/14/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import Foundation

@objc extension Path: NSCoding {
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.subpaths)
    }
    public init?(coder aDecoder: NSCoder) {
        guard self.init(coder: coder) else {
            return nil
        }
        subpaths = aDecoder.decodeObject() as! [PolyBezier]
    }
}
