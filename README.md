# BezierKit
a library for dealing with bezier curves

[![Build Status](https://travis-ci.org/hfutrell/BezierKit.svg?branch=master)](https://travis-ci.org/hfutrell/BezierKit)
[![codecov](https://codecov.io/gh/hfutrell/BezierKit/branch/0.0.4-release/graph/badge.svg)](https://codecov.io/gh/hfutrell/BezierKit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Goals for v0.0.4 (upcoming)
1. quadratic and cubic intersected with lines will fail because: unsupported (the reverse will succeed!)
2. figure out if we can change intersection to return BezierCurve in protocol but concrete instance int he classes themselves 
 * is it possible?
 * does it prevent performance optimizations?

## Goals for v0.0.5 (upcoming)
1. unit test *all* the things
2. drop Utils.makeline in favor of LineSegment where applicable
3. add ray support
4. no more unnecessary sorting and de-duping of intersections
5. profiling of intersections and removal of all overhead
6. tbd

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
