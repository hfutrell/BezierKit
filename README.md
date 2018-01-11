# BezierKit
a Swift library for bezier curves, based on [Bezier.js](https://pomax.github.io/bezierjs/).

[![Build Status](https://travis-ci.org/hfutrell/BezierKit.svg?branch=master)](https://travis-ci.org/hfutrell/BezierKit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Goals for v0.1.0 (upcoming)
1. complete porting functionality from Bezier.js
2. unit tests for Bezier.js functionality for which we do not have tech demos

## issues to work out (upcoming)
1. droots and other root functions can explode in degenerate cases, for example a quadratic that is actually linear, or a cubic that is actually quadratic 
2. unit test *all* the things
3. we do about 2x as many bounding box computations in pairIteration as necessary ... can really slow things down
4. ...

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
