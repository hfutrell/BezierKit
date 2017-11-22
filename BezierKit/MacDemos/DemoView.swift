//
//  DemoView.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit
import BezierKit

class DemoView: NSView, DraggableDelegate {
    
    // MARK: - UI
    
    @IBOutlet var popup: NSPopUpButton!

    @IBAction func popupAction(sender: NSPopUpButton){
        self.currentDemo = self.demos[sender.indexOfSelectedItem]
    }
    
    @IBOutlet var quadraticRadioButton: NSButton!
    @IBOutlet var cubicRadioButton: NSButton!
    
    @IBAction func radioButtonAction(sender: NSButton) {
        self.useQuadratic = (sender == quadraticRadioButton)
    }
    
    // MARK: -
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: 200, height: 210)
    }
    
    var affineTransform: CGAffineTransform {
        let tx = (self.frame.size.width - self.intrinsicContentSize.width) / 2.0
        let ty = (self.frame.size.height - self.intrinsicContentSize.height) / 2.0
        return CGAffineTransform(translationX: tx, y: ty)
    }
    
    var curve: CubicBezierCurve?
    
    var mouseTrackingArea: NSTrackingArea?
    
    var draggables: [Draggable] = [Draggable]()
    var selectedDraggable: Draggable?

    var demos: [Demo] = []
    
    var lastMouseLocation: CGPoint? = nil
    
    func resetDemoState() {
        self.clearDraggables()
        let demo = self.currentDemo!
        let controlPoints = self.useQuadratic ? demo.quadraticControlPoints : demo.cubicControlPoints
        for p in controlPoints {
            self.addDraggable(initialLocation: p, radius: 7)
        }
        self.resetCursorRects()
        self.resetTrackingAreas()
        self.setNeedsDisplay(self.bounds)
    }
    
    var useQuadratic: Bool = false {
        didSet {
           self.resetDemoState()
            quadraticRadioButton.state = self.useQuadratic ? .on : .off
            cubicRadioButton.state = self.useQuadratic ? .off : .on
        }
    }
    
    var currentDemo: Demo? = nil {
        didSet {
            self.resetDemoState()
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    func registerDemo(_ demo: Demo) {
        self.demos.append(demo)
    }
    

    required init?(coder: NSCoder) {
        
        super.init(coder: coder)
        
        self.demos += Demos.all
                
    }
    
    override func awakeFromNib() {
        
        let index: Int = 1
        
        self.currentDemo = self.demos[index]
        self.useQuadratic = false
        
        self.popup.removeAllItems()
        for demo in self.demos {
            self.popup.addItem(withTitle: demo.title)
        }
        self.popup.selectItem(at: index)
    }
    
    func draggableQuadraticCurve() -> QuadraticBezierCurve {
        assert(self.useQuadratic)
        assert(self.draggables.count >= 3, "uh oh, did you set the control points in demo?")
        return QuadraticBezierCurve( p0: self.draggables[0].bkLocation,
                                     p1: self.draggables[1].bkLocation,
                                     p2: self.draggables[2].bkLocation)
    }
    
    func draggableCubicCurve() -> CubicBezierCurve {
        assert(self.useQuadratic == false)
        assert(self.draggables.count >= 4, "uh oh, did you set the control points in demo?")
        return CubicBezierCurve( p0: self.draggables[0].bkLocation,
                                 p1: self.draggables[1].bkLocation,
                                 p2: self.draggables[2].bkLocation,
                                 p3: self.draggables[3].bkLocation )
    }
    
    func clearDraggables() {
        self.selectedDraggable = nil
        self.resetCursorRects()
        self.draggables = []
    }
    
    func draggable(_ draggable: Draggable, didUpdateLocation location: CGPoint) {
        self.resetCursorRects()
        self.setNeedsDisplay(self.bounds)
    }
    
    override func resetCursorRects() {
        
        let cursor: NSCursor = NSCursor.pointingHand
        
        self.discardCursorRects()
        for d: Draggable in self.draggables {
            self.addCursorRect(d.cursorRect.applying(self.affineTransform), cursor: cursor)
        }
    }
    
    func resetTrackingAreas() {
        
        self.mouseTrackingArea = NSTrackingArea(rect: self.bounds, options: [NSTrackingArea.Options.activeInKeyWindow, NSTrackingArea.Options.mouseMoved, NSTrackingArea.Options.mouseEnteredAndExited], owner: self, userInfo: nil)
        
        self.addTrackingArea(self.mouseTrackingArea!)
        
    }
    
    func addDraggable(initialLocation location: CGPoint, radius: CGFloat) {
        let draggable = Draggable(initialLocation: location, radius: radius)
        draggable.delegate = self
        self.draggables.append(draggable)
    }

    // MARK: - mouse functions
    
    override func mouseDown(with event: NSEvent) {
        let location = self.superview!.convert(event.locationInWindow, to: self)
        for d in self.draggables {
            if d.containsLocation(location.applying(self.affineTransform.inverted())) {
                self.selectedDraggable = d
                return
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if let draggable : Draggable = self.selectedDraggable {
            let location = self.superview!.convert(event.locationInWindow, to: self)
            draggable.updateLocation(location.applying(self.affineTransform.inverted()))
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        self.selectedDraggable = nil
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func mouseMoved(with event: NSEvent) {
//        NSLog("mouse location \(event.locationInWindow)")
        let location = self.superview!.convert(event.locationInWindow, to: self)
        self.lastMouseLocation = location
        self.setNeedsDisplay(self.bounds)
    }
    
    override func mouseExited(with event: NSEvent) {
        self.lastMouseLocation = nil
    }
    
    // MARK:
    
    override func draw(_ dirtyRect: NSRect) {
        
        let context: CGContext = NSGraphicsContext.current!.cgContext
        
        context.saveGState()
        context.setFillColor(NSColor.white.cgColor)
        context.fill(self.bounds)
        
        context.concatenate(self.affineTransform)
        
        Draw.reset(context)
        if let demo = currentDemo {
            var curve: BezierCurve? = nil
            if self.draggables.count > 0 {
                curve = self.useQuadratic ? self.draggableQuadraticCurve() : self.draggableCubicCurve()
            }
            let demoState: DemoState = DemoState(quadratic: self.useQuadratic, lastInputLocation: self.lastMouseLocation?.applying(self.affineTransform.inverted()), curve: curve)
            demo.drawFunction(context, demoState)
        }
        
        context.restoreGState()
        
    }
    
 
}
