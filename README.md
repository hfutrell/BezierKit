# BezierKit
a library for dealing with bezier curves

[![Build Status](https://travis-ci.org/hfutrell/BezierKit.svg?branch=master)](https://travis-ci.org/hfutrell/BezierKit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Goals for v0.0.4
1. unit test *all* the things
2. add ray support
3. no more unnecessary sorting and de-duping of intersections
4. profiling of intersections and removal of all overhead
5. tbd

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
