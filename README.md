# BezierKit

[![Build Status](https://travis-ci.org/hfutrell/BezierKit.svg?branch=master)](https://travis-ci.org/hfutrell/BezierKit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/hfutrell/BezierKit/branch/master/graph/badge.svg)](https://codecov.io/gh/hfutrell/BezierKit)

BezierKit is a Bézier curves library written in Swift based on the popular javascript library [Bezier.js](https://pomax.github.io/bezierjs/).

- [Warning! Prerelease software!](#Warning! Prerelease software!)
- [Features](#features)
- [Installation](#installation)

## Warning! Prerelease software!

Please note that BezierKit is currently pre-release software. Its releases follow [semantic versioning](https://semver.org/) which means that until it reaches 1.0 status the API may not be stable or backwards compatible.

## Features
- [x] Constructs linear (line segment), quadratic, and cubic Bézier curves
- [x] Draws curves via CoreGraphics
- [x] Determines positions, derivatives, and normals along curves
- [x] Lengths of curves via Legendre-Gauss quadrature
- [x] Intersects curves and computes cubic curve self-intersection to any degree of accuracy
- [x] Determines bounding boxes, extrema,
- [ ] and inflection points
- [x] Locates nearest on-curve location to point
- [ ] to any degree of accuracy
- [x] Splits and Subdivides curves into subcurves
- [x] Offsets and outlines curves
- [ ] Comprehensive Unit and Integration Test Coverage
- [ ] Complete Documentation

## Installation with Cocoapods

The recommended way to install BezierKit is via Cocoapods, however you may also find that dropping the contents of `Library` into your project also works.

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate BezierKit into your Xcode project using CocoaPods, add it to your target in your `Podfile`:

```ruby
target '<Your Target Name>' do
    pod 'BezierKit', '~> 0.1.1'
end
```

Then, run the following command:

```bash
$ pod install
```

## Goals for v0.1.1 (upcoming)
1. improve readme to include instructions for installation via Cocoapods
2. improve readme to include basic API usage
3. all public API entry points should have unit tests
4. unit test code coverage should read 95%

## issues to work out (upcoming)
1. droots and other root functions can explode in degenerate cases, for example a quadratic that is actually linear, or a cubic that is actually quadratic 
2. unit test *all* the things
3. we do about 2x as many bounding box computations in pairIteration as necessary ... can really slow things down
4. ...

## Goals for v0.1.0 (done and merged to master)
1. complete porting functionality from Bezier.js
2. unit tests for Bezier.js functionality for which we do not have tech demos

## Goals for v0.0.4 (done and merged to master)
1. quadratic and cubic intersected with lines will fail because: unsupported (the reverse will succeed!)
2. drop Utils.makeline in favor of LineSegment where applicable
3. codecov.io integration for unit testing code coverage
4. Swift 4 and XCode 9 migration

## Goals for v0.0.3 (done and merged to master)
1. fix intersection behavior at t = 0 and t = 1
2. write unit tests for intersections to ensure proper behavior on edge cases
3. write unit tests for self intersection and determine why it's broken in structure refactoring branch
4. merge in structure refactoring
5. implement LinearBezierCurve class
6. ensure types known at callsight for specialized generic (get rid of protocol witness table overhead), make sure its accessible otuside of module
7. make sure p0, p1, etc use public accessor!

## Goals for v0.0.2 (done and merged to master)
1. unit testing
2. Travis CI and build badge
3. fix issue where Cocoapods would complain about iOS 8 deployment target
