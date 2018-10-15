/*
 * Doxygen documentation for the lib2geom library
 *
 * Authors:
 *    Krzysztof Kosiński <tweenk.pl@gmail.com>
 * 
 * Copyright 2009-2011 Authors
 *
 * This library is free software; you can redistribute it and/or
 * modify it either under the terms of the GNU Lesser General Public
 * License version 2.1 as published by the Free Software Foundation
 * (the "LGPL") or, at your option, under the terms of the Mozilla
 * Public License Version 1.1 (the "MPL"). If you do not alter this
 * notice, a recipient may use your version of this file under either
 * the MPL or the LGPL.
 *
 * You should have received a copy of the LGPL along with this library
 * in the file COPYING-LGPL-2.1; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 * You should have received a copy of the MPL along with this library
 * in the file COPYING-MPL-1.1
 *
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY
 * OF ANY KIND, either express or implied. See the LGPL or the MPL for
 * the specific language governing rights and limitations.
 */

// Main page of the documentation - contains logo and introductory text
/**
 * @mainpage
 *
 * @image html 2geom-logo.png
 *
 * @section Introduction
 *
 * 2Geom is a computational geometry library intended for use with 2D vector graphics.
 * It concentrates on high-level algorithms, such as computing the length of a curve
 * or Boolean operations on paths. It evolved from the geometry code used
 * in Inkscape, a free software, cross-platform vector graphics editor.
 *
 * @section UserGuide User guide
 *
 * - @subpage Overview "Overview of 2Geom"
 * - @ref Primitives "Primitives" - points, angles, lines, axis-aligned rectangles...
 * - @ref Transforms "Transformations" - mathematical representation for operations
 *   like translation, scaling and rotation.
 * - @ref Fragments "Fragments" - one-dimensional functions and related utilities.
 * - @ref Curves "Curves" - functions mapping the unit interval to points on a plane.
 * - @ref Shapes "Shapes" - circles, ellipses, polygons and the like.
 * - @ref Paths "Paths" - sequences of contiguous curves, aka splines, and their processing.
 * - @ref ShapeOps "Shape operations" - boolean algebra, offsets and other advanced operations.
 * - @ref Containers "Geometric containers" - efficient ways to store and retrieve
 *   geometric information.
 * - @ref Utilities "Utilities" - other useful code that does not fit under the above categories.
 * - @subpage ReleaseNotes "Release notes" - what's new in 2Geom
 *
 * @section DeveloperInfo Developer information
 *
 * - @subpage CodingStandards "Coding standards used in 2Geom"
 */

// Overview subpage
/**
 * @page Overview Overview of 2Geom
 *
 * 2Geom has two APIs: a high level one, which uses virtual functions to allow handling
 * objects of in a generic way without knowing their actual type at compile time,
 * and a lower-level one based on templates, which is designed with performance in mind.
 * For performance-critical tasks it may be necessary to use the lower level API.
 *
 * @section CoordSys Standard coordinate system
 *
 * 2Geom's standard coordinate system is common for computer graphics: the X axis grows
 * to the right and the Y axis grows downwards. Angles start from the +X axis
 * and grow towards the +Y axis (clockwise).
 *
 * @image html coords.png Standard coordinate system in 2Geom
 *
 * Most functions can be used without taking the coordinate system into account,
 * as their interpretation is the same regardless of the coordinate system. However,
 * a few of them depend on this definition, for example Rect's top() and bottom() methods.
 *
 * @section OpNote Operator note
 *
 * Most operators are provided by Boost operator helpers. This means that not all operators
 * are defined in the class. For example, Rect only implements the operators
 * +=, -= for points and *= for affines. The corresponding +, - and * operators
 * are generated automatically by Boost.
 */

// RELEASE NOTES
// Update this to describe the most important API changes.
/**
 * @page ReleaseNotes 2Geom release notes
 *
 * @section Ver04 Version 0.4
 *   - API additions:
 *     - Integer versions of Point, Interval and OptInterval, called
 *       IntPoint, IntInterval and OptIntInterval.
 *     - New geometric primitives: Angle and AngleInterval.
 *   - Major changes:
 *     - Matrix has been renamed to Affine.
 *     - Classification methods of Affine, for example Affine::isRotation(), will now
 *       return true for transforms that are close to identity. This is to reflect the
 *       fact that an identity transform can be interpreted as a rotation by zero
 *       degrees. To get the old behavior of returning false for identity, use
 *       methods prefixed with "Nonzero", e.g. Affine::isNonzeroRotation().
 *     - EllipticalArc and SVGEllipticalArc have been merged. Now there is only the former.
 *       All arcs are SVG-compliant.
 *   - Minor changes:
 *     - Affine::without_translation() is now called Affine::withoutTranslation().
 *     - Interval::strict_contains() is now called Interval::interiorContains().
 *       The same change has been made for Rect.
 *     - Some unclear and unused operators of D2 were removed, for instance D2 * Point.
 *     - Interval is now a derived class of a GenericInterval template.
 *     - Rect is no longer a D2 specialization.
 *     - isnan.h merged with math-utils.h.
 * @section Ver03 Version 0.3
 *     - release notes were started after this version.
 */

/**
 * @page CodingStandards Coding standards and conventions used in 2Geom
 *
 * @section Filenames
 *
 * Files and directories should be all lowercase. Words should be separated with hyphens (-).
 * Underscores, capital letters and non-ASCII characters should not be used.
 *
 * @section Indenting
 *
 * All files should use 4 spaces as indentation.
 * 
 * @section Namespaces
 *
 * All classes intended for direct use by the end users should be in the Geom namespace.
 * Contents of namespaces should not be indented. Closing brace of a namespace
 * should have a comment indicating which namespace it is closing.
 * @code
 namespace Geom {
 namespace FooInternal {
 
 unsigned some_function()
 {
 // ...code...
 }

 } // namespace FooInternal
 } // namespace Geom
 @endcode
 * 
 * @section Classes
 *
 * @code
 // superclass list should use Boost notation,
 // especially if there is more than one.
 class Foo
     : public Bar
     , public Baz
 {
     // constructors should use Boost notation if the class has superclasses.
     Foo(int a)
         : Bar(a)
         , Baz(b)
     {
         // constructor body
     }
     Foo(int a) {
         // constructor with default initialization of superclasses
     }

     // methods use camelCaseNames.
     // one-line methods can be collapsed.
     bool isActive() { return _blurp; }
     // multi-line methods have the opening brace on the same line.
     void invert() {
         // ... code ...
     }

     // static functions use lowercase_with_underscores.
     // static factory functions should be called from_something.
     static Foo from_point(Point const &p) {
         // ...
     }
 }; // end of class Foo

 // Closing brace of a class should have the above comment, unless it's very short.
 @endcode
 *
 * @section FreeFuns Free functions
 *
 * Functions should use lowercase_with_underscores names. The opening brace of
 * the definition should be on a separate line.
 *
 * @section InlineInClasses When to use inline
 *
 * The "inline" keyword is not required when the body of the function is given
 * in the definition of the class. Do not mark such functions inline, because
 * they are automatically marked as inline by the compiler. It is only
 * necessary to use the inline keyword when the body of the function is given
 * after the class definition.
 */

// Documentation for groups
/**
 * @defgroup Transforms Affine transformations
 * @brief Transformations of the plane such as rotation and scaling
 *
 * Each transformation class represent a set of affine transforms that is closed
 * under multiplication. Those are translation, scaling, rotation, horizontal shearing
 * and vertical shearing. Any affine transform can be obtained by combining those
 * basic operations.
 *
 * Each of the transforms can be applied to points and matrices (using multiplication).
 * Each can also be converted into a matrix (which can represent any composition
 * of transforms generically). All (except translation) use the origin (0,0) as the invariant
 * point (e.g. one that stays in the same place after applying the transform to the plane).
 * To obtain transforms with different invariant points, combine them with translation to
 * and back from the origin. For example, to get a 60 degree rotation around the point @a p:
 * @code Affine rot_around_p = Translate(-p) * Rotate::from_degrees(60) * Translate(p); @endcode
 *
 * Multiplication of transforms is associative: the result of an expression involving
 * points and matrices is the same regardless of the order of evaluating multiplications.
 *
 * If you need to transform a complicated object
 * by A, then B, and then C, you should first compute the total transform and apply it to the
 * object in one go. This way instead of performing 3 expensive operations, you will only do
 * two very fast matrix multiplications and one complex transformation. Here is an example:
 * @code
 transformed_path = long_path * A * B * C; // wrong! long_path will be transformed 3 times.
 transformed_path = long_path * (A * B * C); // good! long_path will be transformed only once.
 Affine total = A * B * C; // you can store the transform to apply it to several objects.
 transformed_path = long_path * total; // good!
   @endcode
 * Ordering note: if you compose transformations via multiplication, they are applied
 * from left to right. If you write <code> ptrans = p * A * B * C * D;</code>, then it means
 * that @a ptrans is obtained from @a p by first transforming it by A, then by B, then by C,
 * and finally by D. This is a consequence of interpreting points as row vectors, instead
 * of the more common column vector interpretation; 2Geom's choice leads to more intuitive
 * notation.
 */

/**
 * @defgroup Primitives Primitives
 * @brief Basic mathematical objects such as intervals and points
 *
 * 2Geom has several basic geometrical objects: points, lines, intervals, angles,
 * and others. Most of those objects can be treated as sets of points or numbers
 * satisfying some equation or as functions.
 */

/**
 * @defgroup Fragments Fragments and related classes
 * @brief 1D functions on the unit interval
 *
 * Each type of fragments represents one of the various ways in which a function from
 * the unit interval to the real line may be given. These are the most important mathematical
 * primitives in 2Geom.
 */

/**
 * @defgroup Curves Curves
 * @brief Functions mapping the unit interval to a plane
 *
 * Curves are functions \f$\mathbf{C}: [0, 1] \to \mathbb{R}^2\f$. For details, see
 * the documentation for the Curve class. All curves can be included in paths and path sequences.
 */

/**
 * @defgroup Shapes Basic shapes
 * @brief Circles, ellipes, polygons...
 *
 * Among the shapes supported by 2Geom are circles, ellipses and polygons.
 * Polygons can also be represented by paths containing only linear segments.
 */

/**
 * @defgroup Paths Paths and path sequences
 * @brief Sequences of contiguous curves, aka splines, and their processing
 */

/**
 * @defgroup Utilities Miscellaneous utilities
 * @brief Useful code that does not fit under other categories.
 */

/*
  Local Variables:
  mode:c++
  c-file-style:"stroustrup"
  c-file-offsets:((innamespace . 0)(inline-open . 0)(case-label . +))
  indent-tabs-mode:nil
  fill-column:99
  End:
*/
// vim: filetype=cpp:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:fileencoding=utf-8:textwidth=99 :
