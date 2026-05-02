#!/usr/bin/env python3
"""
Performance regression detector for BezierKit.

Checks out every commit on the current branch that is not on master, runs the
XCTest performance suite with release optimizations and 100 measurement
iterations (10× the XCTest default of 10), then reports any commit-to-commit
regressions or improvements greater than 20%.

USAGE
-----
Run from the repository root (or any git worktree of the repo):

    python3 Scripts/performance_regression.py

    # Specify a different base branch (default: master):
    python3 Scripts/performance_regression.py --base main

    # Change the regression threshold (default: 20%):
    python3 Scripts/performance_regression.py --threshold 0.15

    # Save raw results to a JSON file for further analysis:
    python3 Scripts/performance_regression.py --output results.json

REQUIREMENTS
------------
- Python 3.8+
- Xcode command-line tools with `swift test` available
- Run on macOS (XCTest performance APIs not available on Linux/WASI)
- ~30 seconds per commit; budget ~30 min for a branch of 70 commits

HOW IT WORKS
------------
For each commit the script:
  1. Checks out the commit (detached HEAD).
  2. Patches PerformanceTests.swift to use XCTMeasureOptions.iterationCount=100
     if not already present.
  3. Runs `swift test -c release --filter PerformanceTests`.
  4. Parses the individual sample values from XCTest output (not the truncated
     3-decimal-place summary average) for full floating-point precision.
  5. Compares each test's mean against the previous commit.

After all commits are tested the branch is restored to its original HEAD.

Results below a 0.5 ms noise floor are excluded from regression analysis
because XCTest timing at that scale is dominated by scheduler jitter.

NOTES ON TEST WORKLOAD DIFFERENCES
-----------------------------------
Some tests on feature branches may have different inner loop counts or stride
parameters compared to master (e.g. an added `for _ in 0..<10` loop to
increase signal-to-noise). The script compares raw times commit-to-commit
within the branch, so test-structure changes will appear as a large one-time
jump at the commit where they were introduced. These can be distinguished from
genuine algorithmic regressions by their magnitude (typically >5×) and by
inspecting the diff at that commit.
"""

import argparse
import json
import os
import re
import statistics
import subprocess
import sys

MEASURE_OPTIONS_BLOCK = '''
    private static let measureOptions: XCTMeasureOptions = {
        let options = XCTMeasureOptions()
        options.iterationCount = 100
        return options
    }()
'''

PERF_TEST_PATH = 'BezierKit/BezierKitTests/PerformanceTests.swift'


def get_repo_root():
    r = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                       capture_output=True, text=True)
    return r.stdout.strip()


def get_commits(base_branch):
    r = subprocess.run(
        ['git', 'log', f'{base_branch}..HEAD', '--reverse', '--format=%H|||%s'],
        capture_output=True, text=True
    )
    commits = []
    for line in r.stdout.strip().split('\n'):
        if '|||' in line:
            sha, subject = line.split('|||', 1)
            commits.append((sha.strip(), subject.strip()))
    return commits


def get_current_branch():
    r = subprocess.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                       capture_output=True, text=True)
    return r.stdout.strip()


def patch_performance_tests(path):
    try:
        with open(path) as f:
            content = f.read()
    except FileNotFoundError:
        return
    if 'measureOptions' in content:
        return
    content = content.replace(
        'class PerformanceTests: XCTestCase {',
        'class PerformanceTests: XCTestCase {' + MEASURE_OPTIONS_BLOCK
    )
    content = re.sub(r'self\.measure \{',
                     'self.measure(options: Self.measureOptions) {', content)
    with open(path, 'w') as f:
        f.write(content)


def parse_results(output):
    """Parse sample value arrays for full-precision means."""
    results = {}
    pattern = (
        r"Test Case '-\[BezierKitTests\.PerformanceTests (\w+)\]' measured "
        r"\[Clock Monotonic Time, s\] average: [\d.]+.*?values: \[([^\]]+)\]"
    )
    for m in re.finditer(pattern, output):
        test_name = m.group(1)
        vals = [float(v.strip()) for v in m.group(2).split(',') if v.strip()]
        if vals:
            results[test_name] = statistics.mean(vals)
    return results


def run_tests_at_commit(sha, subject, root):
    subprocess.run(['git', 'checkout', sha], capture_output=True, cwd=root)
    patch_performance_tests(os.path.join(root, PERF_TEST_PATH))
    try:
        r = subprocess.run(
            ['swift', 'test', '-c', 'release', '--filter', 'PerformanceTests'],
            capture_output=True, text=True, cwd=root, timeout=600
        )
        return parse_results(r.stdout + r.stderr)
    except subprocess.TimeoutExpired:
        print('  (timeout)', flush=True)
        return {}


def regression_analysis(commits, all_results, threshold, noise_floor):
    shas = [sha for sha, _ in commits]
    all_tests = set()
    for entry in all_results.values():
        all_tests.update(entry.get('results', {}).keys())

    regressions = []
    improvements = []

    for test in sorted(all_tests):
        prev_sha, prev_val = None, None
        for sha in shas:
            val = all_results.get(sha, {}).get('results', {}).get(test)
            if val is None:
                prev_sha, prev_val = sha, None
                continue
            if prev_val is not None and prev_val > noise_floor and val > noise_floor:
                pct = (val - prev_val) / prev_val
                entry = (test, prev_sha, sha, prev_val, val, pct)
                if pct > threshold:
                    regressions.append(entry)
                elif pct < -threshold:
                    improvements.append(entry)
            prev_sha, prev_val = sha, val

    return regressions, improvements


def print_entries(label, entries, all_results, worse_first=True):
    print(f'\n{label}')
    if not entries:
        print('  None')
        return
    for test, from_sha, to_sha, from_val, to_val, pct in sorted(
            entries, key=lambda x: -x[5] if worse_first else x[5]):
        fs = all_results[from_sha]['subject']
        ts = all_results[to_sha]['subject']
        sign = '+' if pct > 0 else ''
        print(f'\n  {"⚠️ " if pct > 0 else "✅ "}{test}: {sign}{pct*100:.1f}%')
        print(f'     {from_sha[:8]}  {from_val:.6f}s  →  {to_sha[:8]}  {to_val:.6f}s')
        print(f'     From: {fs}')
        print(f'     To:   {ts}')


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--base', default='master',
                        help='Base branch to compare against (default: master)')
    parser.add_argument('--threshold', type=float, default=0.20,
                        help='Regression threshold 0–1 (default: 0.20 = 20%%)')
    parser.add_argument('--noise-floor', type=float, default=0.0005,
                        help='Minimum mean time in seconds to include in analysis (default: 0.0005)')
    parser.add_argument('--output', default=None,
                        help='Save raw results JSON to this path')
    args = parser.parse_args()

    root = get_repo_root()
    original_branch = get_current_branch()
    commits = get_commits(args.base)

    if not commits:
        print(f'No commits found between {args.base} and HEAD.')
        sys.exit(0)

    print(f'Testing {len(commits)} commits (base: {args.base})', flush=True)

    all_results = {}
    try:
        for i, (sha, subject) in enumerate(commits):
            print(f'\n[{i+1}/{len(commits)}] {sha[:8]}: {subject}', flush=True)
            results = run_tests_at_commit(sha, subject, root)
            all_results[sha] = {'subject': subject, 'results': results}
            for test, avg in sorted(results.items()):
                print(f'  {test}: {avg:.6f}s', flush=True)
    finally:
        ref = original_branch if original_branch != 'HEAD' else commits[-1][0]
        subprocess.run(['git', 'checkout', ref], capture_output=True, cwd=root)

    if args.output:
        with open(args.output, 'w') as f:
            json.dump({'commits': [sha for sha, _ in commits],
                       'data': all_results}, f, indent=2)
        print(f'\nRaw results saved to {args.output}')

    regressions, improvements = regression_analysis(
        commits, all_results, args.threshold, args.noise_floor)

    threshold_pct = int(args.threshold * 100)
    print(f'\n\n=== REGRESSIONS (>{threshold_pct}% slower, commit-to-commit) ===')
    print_entries(f'Regressions:', regressions, all_results, worse_first=True)
    print(f'\n=== IMPROVEMENTS (>{threshold_pct}% faster, commit-to-commit) ===')
    print_entries(f'Improvements:', improvements, all_results, worse_first=False)
    print('\nDone.')


if __name__ == '__main__':
    main()
