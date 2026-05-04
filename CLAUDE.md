# Claude hints for BezierKit

## High level goals

BezierKit aims to be bug-free. There must never be a case where a public API gives incorrect output.

BezierKit aims to provide public APIs with maximal accuracy, ideally close to floating point machine-level accuracy.

BezierKit's algorithms must be numerically stable and must not ever "explode" in corner cases.

BezierKit aims for API stability. You must never change the public API without being explicitly directed to do so. You may suggest specific changes but the authorization to make every change must come from a human being.

BezierKit aims to maintain its code quality through development processes such as enforcing linting rules. These processes are managed by humans. You may not change these processes without human authorization.

## Performance test guidelines

You must *always* enable all compiler optimizations for performance tests when measuring the CPU time impact of optimizations. Results of performance tests which were run in debug mode provide no signal and must be disregarded. When optimizing for performance the release build CPU execution time is of utmost importance; CPU execution time of debug builds is of no importance at all.

When comparing performance results you must always ensure it is an apples-to-apples comparison. For example when comparing across branches you should verify the tests are measuring the same thing. Run benchmarks sequentially, never in parallel with other CPU-intensive processes; CPU contention from concurrent worktrees or background tasks is a common source of spurious results.

Performance tests should run long enough to provide good signal. XCTest runs several iterations when measuring performance. 100ms per iteration is a good target and allows for good signal even after further optimization.

Code intended for debug asserts must be completely compiled out of release builds. When optimizing code you should ensure that code that evaluates the assertion condition falls entirely within the assertion conditional argument so that it is not evaluated in release builds. If that strategy results in messy code you must use #if DEBUG surrounding the code which supports the assertion check to ensure the compiler cannot retain the code in release builds.

Checks such as precondition(…) which are not compiled out of release builds are not allowed except for public APIs, and those must:
1. represent a previously documented part of the API contract
2. represent irrecoverable errors

## Optimization guidelines

The most significant optimizations stem from choosing the best algorithms. When deciding on an approach you should consider prior work on solving the problem at hand. Once you have a working initial implementation you should search the literature for potential meaningful improvements to the base algorithm. As an example, after implementing Bezier Clipping you should check if further improvements are possible through "Curve intersection using hybrid clipping" by Qi Lou and Ligang Liu.

You must always eliminate the following overheads, which you can locate by inspecting the output assembly of the library compiled with optimizations enabled.
— Heap allocations. Creating Swift arrays for intermediate calculations or return results from internal/private functions almost always results in heap allocations and is undesirable. Some strategies to avoid this include using withUnsafeTemporaryAllocation, invoking a closure on each item (instead of returning them), or using fixed sized struct (eg BernsteinPolynomial1, BernsteinPolynomial2, etc).
— Swift exclusivity access (eg swift_beginAccess). When this overhead appears in profiling results this can sometimes be eliminated using @inline(__always). You must always run performance tests with and without the hint and confirm a substantial speedup before keeping it. @inline(__always) can cause code-size bloat that hurts unrelated call sites, so it must never be used speculatively — only when benchmarks confirm a clear improvement.
— Protocol witness table dispatch. Avoid existentials (`any Protocol`) in hot paths; use generics with concrete type constraints instead, which allows the compiler to specialize and inline.

You should use FMA (fused multiply-add) instructions when they speed execution without accuracy loss. For example Swift Float's addingProduct has been successfully applied to speed execution without decreasing accuracy.

When optimizing you must never trade implementation accuracy for speed. It is an error to decrease the order of magnitude of accuracy of a public API and you should verify the accuracy of the new approach. When you provide a new implementation you must compare the accuracy against the old one on test data.

When optimizing you must always consider the numerical stability of new implementations. For example, if a change introduces a division by an argument you must consider if the solution will "explode" when the denominator of the division (the argument) is nearly zero. It is an error to provide a new implementation whose accuracy degrades the accuracy of public APIs on worst case input examples.

## Code style

Code readability is important
— SwiftLint enforces clean code in the codebase and should always pass. You must not disable SwiftLint rules in order to write code that violates them. If your code triggers SwiftLint rules try to find another way to write it that conforms to the rules. If conforming to the rules negatively impacts optimizations or structure then seek explicit human authorization for disabling SwiftLint in targeted ways — preferably via inline `// swiftlint:disable:next` comments at specific call sites, or if the rule is genuinely inapplicable project-wide, by adding it to the `disabled_rules` list in `.swiftlint.yml`. In either case the authorization must be explicit and the reason documented.
— Code duplication of significant length (eg greater than 5 lines) should generally be avoided. For example if a function has two lengthy codepaths which are largely the same, it is better to encompass the commonalities in a private function or closure.
— Code should use available utility methods, for example instead of writing "if u < 0 { u = 0 } else if u > 1 { u = 1 }" write "u = Utils.clamp(u, 0, 1)"
— Swift files should be under 400 lines of code. When a file exceeds this length think about breaking functionality into a separate file.
— Released code should not contain commented out sections. These sections often hint to unresolved issues or vestigial approaches.
— Released code should not contain TODOs. These should be converted to issues.

Code should be concise
— where possible avoid self.method() in favor of simply calling method.
— single value methods and properties should omit "return"
— omit unnecessary keywords when they reflect the default access control in their context, such as "internal" when the default for the function would be internal anyway.

## Code coverage

BezierKit aims for 100% unit test code coverage. Every public and internal API must have at least one unit test, and unit tests must hit every possible codepath. When you add code you must verify that unit tests achieve code coverage.

BezierKit aims for no "dead code". Every line of code you add must be reachable through public APIs. When you remove usage of an internal type or caller you must run the tests to check if the code has become unused or unreachable (dead). Code and internal types which are dead must be removed.

**Platform-specific test guards.** WASM targets use 32-bit `CGFloat`. Tests that require 64-bit floating-point precision (sub-1e-5 accuracy, catastrophic-cancellation sensitivity, near-degenerate geometry) must be guarded with `#if !os(WASI)`. Add a short comment on the guard explaining the precision requirement (e.g. `// tiny cubic coefficient causes catastrophic cancellation in 32-bit`). Do not skip WASI tests for any reason other than 32-bit precision.
