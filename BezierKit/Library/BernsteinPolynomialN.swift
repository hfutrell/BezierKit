//
//  BezierCurve.swift
//  GraphicsPathNearest
//
//  Created by Holmes Futrell on 2/19/21.
//

import CoreGraphics

func binomialCoefficient(_ n: Int, choose k: Int) -> Int {
    precondition(n >= 0 && k >= 0)
    var result = 1
    for i in 0..<k {
      result *= (n - i)
      result /= (i + 1)
    }
    return result
}

func linearInterpolate(_ first: CGFloat, _ second: CGFloat, _ t: CGFloat) -> CGFloat {
    return (1 - t) * first + t * second
}

public struct BernsteinPolynomialN: BernsteinPolynomial {
    public let coefficients: [CGFloat]

    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomialN {
        fatalError("unimplemented.")
    }

    public var order: Int { return coefficients.count - 1 }
    public init(coefficients: [CGFloat]) {
        precondition(coefficients.isEmpty == false, "Bezier curves require at least one point")
        self.coefficients = coefficients
    }
    static func * (left: CGFloat, right: BernsteinPolynomialN) -> BernsteinPolynomialN {
        return BernsteinPolynomialN(coefficients: right.coefficients.map { left * $0 })
    }
    public static func == (left: BernsteinPolynomialN, right: BernsteinPolynomialN) -> Bool {
        return left.coefficients == right.coefficients
    }
    func reversed() -> BernsteinPolynomialN {
        return BernsteinPolynomialN(coefficients: coefficients.reversed())
    }
    public var derivative: BernsteinPolynomialN {
        guard order > 0 else { return BernsteinPolynomialN(coefficients: [CGFloat.zero]) }
        return CGFloat(order) * hodograph
    }
    public func value(at t: CGFloat) -> CGFloat {
        return self.split(at: t).left.coefficients.last!
    }
    private var hodograph: BernsteinPolynomialN {
        precondition(order > 0)
        let differences = (0..<order).map { coefficients[$0 + 1] - coefficients[$0] }
        return BernsteinPolynomialN(coefficients: differences)
    }
    func split(at t: CGFloat) -> (left: BernsteinPolynomialN, right: BernsteinPolynomialN) {
        guard order > 0 else {
            // splitting a point results in getting a point back
            return (left: self, right: self)
        }
        // apply de Casteljau Algorithm
        var leftPoints = [CGFloat](repeating: .zero, count: coefficients.count)
        var rightPoints = [CGFloat](repeating: .zero, count: coefficients.count)
        let n = order
        var scratchPad: [CGFloat] = coefficients
        leftPoints[0] = scratchPad[0]
        rightPoints[n] = scratchPad[n]
        for j in 1...n {
            for i in 0...n - j {
                scratchPad[i] = linearInterpolate(scratchPad[i], scratchPad[i + 1], t)
            }
            leftPoints[j] = scratchPad[0]
            rightPoints[n - j] = scratchPad[n - j]
        }
        return (left: BernsteinPolynomialN(coefficients: leftPoints),
                right: BernsteinPolynomialN(coefficients: rightPoints))
    }
    func split(from t1: CGFloat, to t2: CGFloat) -> BernsteinPolynomialN {
        guard (t1 > t2) == false else {
            // simplifying to t1 <= t2 would infinite loop on NaN because NaN comparisons are always false
            return split(from: t2, to: t1).reversed()
        }
        guard t1 != 0 else { return split(at: t2).left }
        let right = split(at: t1).right
        guard t2 != 1 else { return right }
        let t2MappedToRight = (t2 - t1) / (1 - t1)
        return right.split(at: t2MappedToRight).left
    }
}

extension BernsteinPolynomialN {
    static func + (left: BernsteinPolynomialN, right: BernsteinPolynomialN) -> BernsteinPolynomialN {
        precondition(left.order == right.order, "curves must have equal degree (unless we support upgrading degrees, which we don't here)")
        return BernsteinPolynomialN(coefficients: zip(left.coefficients, right.coefficients).map(+))
    }
    static func * (left: BernsteinPolynomialN, right: BernsteinPolynomialN) -> BernsteinPolynomialN {
        // the polynomials are multiplied in Bernstein form, which is a little different
        // from normal polynomial multiplication. For a discussion of how this works see
        // "Computer Aided Geometric Design" by T.W. Sederberg,
        // 9.3 Multiplication of Polynomials in Bernstein Form
        var points: [CGFloat] = []
        let m = left.order
        let n = right.order
        for k in 0...m + n {
            let start = max(k - n, 0)
            let end = min(m, k)
            let sum = (start...end).reduce(CGFloat.zero) { totalSoFar, i  in
                let j = k - i
                return totalSoFar + CGFloat(binomialCoefficient(m, choose: i) * binomialCoefficient(n, choose: j)) * left.coefficients[i] * right.coefficients[j]
            }
            let divisor = CGFloat(binomialCoefficient(m + n, choose: k))
            points.append(sum / divisor)
        }
        return BernsteinPolynomialN(coefficients: points)
    }
}
