# BezierKit

[![Build Status](https://travis-ci.org/hfutrell/BezierKit.svg?branch=master)](https://travis-ci.org/hfutrell/BezierKit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/hfutrell/BezierKit/branch/master/graph/badge.svg)](https://codecov.io/gh/hfutrell/BezierKit)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/BezierKit.svg)](https://img.shields.io/cocoapods/v/BezierKit.svg)

BezierKit is a library for Bézier curves written in Swift and based on the popular javascript library [Bezier.js](https://pomax.github.io/bezierjs/).

- [Warning! Prerelease software!](#warning!)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [License](#license)

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
    pod 'BezierKit', '> 0.1.1'
end
```

Then, run the following command:

```bash
$ pod install
```

## Usage

## License

BezierKit is released under the MIT license. [See LICENSE](https://github.com/hfutrell/BezierKit/blob/master/LICENSE) for details.
