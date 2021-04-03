//
//  GraphicsPathView.swift
//  GraphicsPathNearest
//
//  Created by Holmes Futrell on 2/19/21.
//  Copyright © 2021 Ginger Labs, Inc. All rights reserved.
//  https://www.gingerlabs.com
//

import UIKit

extension BezierCurve2D {
    var path: CGPath {
        let mutablePath = CGMutablePath()
        mutablePath.move(to: points.first!)
        let lastPoint = points.last!
        switch degree {
        case 1:
            mutablePath.addLine(to: lastPoint)
        case 2:
            mutablePath.addQuadCurve(to: lastPoint, control: points[1])
        case 3:
            mutablePath.addCurve(to: lastPoint, control1: points[1], control2: points[2])
        default:
            assertionFailure("unexpected curve degree \(degree)")
        }
        return mutablePath
    }
}

class ControlPointGestureRecognizer: UIPanGestureRecognizer {
    private var action: (UIGestureRecognizer) -> Void
    private var _controlPoint: (UIGestureRecognizer) -> CGPoint
    var controlPoint: CGPoint { return _controlPoint(self) }
    
    init(action: @escaping (_ gesture: UIGestureRecognizer) -> Void,
         controlPoint: @escaping (_ gesture: UIGestureRecognizer) -> CGPoint) {
        self.action = action
        _controlPoint = controlPoint
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(execute))
    }

    @objc private func execute() {
        action(self)
    }
}

class GraphicsPathView: UIView {
    
    struct Constants {
        static let inset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        static let skeletonWidth: CGFloat = 1
        static let skeletonColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.25)
        static let lineWidth: CGFloat = 2
        static let curveColor = UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0)
        static let nearestLineColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
        static let derivativeColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
        static let dashLengths: [CGFloat] = [5.0, 2.0]
        static let tangentLineLength: CGFloat = 50
        static let pointRadius: CGFloat = 3
        static let skeletonPointSize: CGFloat = 4
        static let controlPointTouchTargetSize: CGFloat = 15
    }
        
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupControlPointGestureRecognizers()
        self.backgroundColor = UIColor.white
    }

    /// transforms the origin to the inset center of the view, and flips things so +y is up
    var ctm: CGAffineTransform {
        let insetWidth = bounds.width - Constants.inset.left - Constants.inset.right
        let insetHeight = bounds.height - Constants.inset.top - Constants.inset.bottom
        var transform =  CGAffineTransform(translationX: Constants.inset.left, y: Constants.inset.top)
        transform = transform.translatedBy(x: insetWidth / 2.0, y: insetHeight / 2.0)
        transform = transform.scaledBy(x: 1, y: -1)
        return transform
    }
    
    var curve: BezierCurve2D = BezierCurve2D(points: [CGPoint(x: -100, y: -50),
                                                      CGPoint(x: 25, y: -75),
                                                      CGPoint(x: -25, y: 75),
                                                      CGPoint(x: 100, y: -25)])
            
    var point: CGPoint = CGPoint(x: -50, y: -25)
    
    
    var controlPointGestureRecognizers: [UIGestureRecognizer] = []
    
    private func setupControlPointGestureRecognizers() {
        
        // remove any existing gestures
        controlPointGestureRecognizers.forEach {
            removeGestureRecognizer($0)
        }
        controlPointGestureRecognizers.removeAll()
        controlPointGestureRecognizers.forEach { removeGestureRecognizer($0) }
        
        // setup gesture for the point off the curve
        let gesture = ControlPointGestureRecognizer(action: { [weak self] gesture in
            guard let view = self else { return }
            view.point = gesture.location(in: view).applying(view.ctm.inverted())
            view.setNeedsDisplay()
        }, controlPoint: { [weak self] gesture -> CGPoint in
            guard let view = self else { return CGPoint.zero }
            return view.point
        })
        controlPointGestureRecognizers.append(gesture)

        // setup gestures for the curve's points
        (0..<curve.points.count).forEach { i in
            let action = { [weak self] (gesture: UIGestureRecognizer) in
                guard let view = self else { return }
                view.curve.points[i] = gesture.location(in: view).applying(view.ctm.inverted())
                view.setNeedsDisplay()
            }
            let controlPoint = { [weak self] (gesture: UIGestureRecognizer) -> CGPoint in
                guard let view = self else { return .zero }
                return view.curve.points[i]
            }
            let gesture = ControlPointGestureRecognizer(action: action, controlPoint: controlPoint)
            controlPointGestureRecognizers.append(gesture)
        }
        
        // add the new gestures to the view
        controlPointGestureRecognizers.forEach {
            addGestureRecognizer($0)
            $0.delegate = self
        }
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.concatenate(ctm)
        
        // draw the curve's skeleton
        if curve.points.count > 2 {
            context.saveGState()
            context.setLineWidth(Constants.skeletonWidth)
            context.setStrokeColor(Constants.skeletonColor.cgColor)
            context.move(to: curve.points[0])
            context.addLine(to: curve.points[1])
            context.move(to: curve.points[curve.points.count - 2])
            context.addLine(to: curve.points[curve.points.count - 1])
            context.strokePath()
            context.restoreGState()
        }
        
        // draw the curve and its control points
        context.setLineWidth(Constants.lineWidth)
        context.saveGState()
        context.setStrokeColor(Constants.curveColor.cgColor)
        context.addPath(curve.path)
        context.strokePath()
        curve.points.enumerated().forEach { i, point in
            if i == 0 || i == curve.points.count - 1 {
                context.setFillColor(Constants.curveColor.cgColor)
            } else {
                context.setFillColor(Constants.skeletonColor.cgColor)
            }
            context.fill(CGRect(origin: point, size: .zero).insetBy(dx: -Constants.skeletonPointSize / 2.0, dy: -Constants.skeletonPointSize / 2.0))
        }
        context.restoreGState()
        
        // find closest point to curve
        let (closestT, closestPoint) = curve.nearestPointOnCurve(to: point)

        // draw a line to the nearest point
        context.saveGState()
        context.setStrokeColor(Constants.nearestLineColor.cgColor)
        context.move(to: closestPoint)
        context.addLine(to: point)
        context.setLineDash(phase: 0, lengths: Constants.dashLengths)
        context.strokePath()
        context.restoreGState()
        
        // draw the point
        context.saveGState()
        context.addEllipse(in: CGRect(origin: point, size: .zero).insetBy(dx: -Constants.pointRadius, dy: -Constants.pointRadius))
        context.strokePath()
        context.restoreGState()

        // draw a tangent line (if derivative non-zero)
        let derivative = curve.derivative.value(at: closestT)
        let derivativeLength = distance(derivative, .zero)
        if derivativeLength > 0, closestT > 0, closestT < 1 {
            context.saveGState()
            context.setStrokeColor(Constants.derivativeColor.cgColor)
            context.move(to: closestPoint)
            context.addLine(to: curve.value(at: closestT) + Constants.tangentLineLength / derivativeLength * derivative)
            context.strokePath()
            context.restoreGState()
        }
    }
}

extension GraphicsPathView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        
        guard let controlPointGestureRecognizer = gestureRecognizer as? ControlPointGestureRecognizer else {
            return true // the default
        }
        let locationInView = touch.location(in: self)
        let pointLocationInView = controlPointGestureRecognizer.controlPoint.applying(ctm)
        guard distance(locationInView, pointLocationInView) < Constants.controlPointTouchTargetSize else {
            return false
        }
        return true
    }
    
}
