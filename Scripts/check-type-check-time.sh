#!/usr/bin/env bash
#
# Fails if any function body or expression in the BezierKit library exceeds the
# Swift type-checking time budget. Guards against reintroducing type-inference
# hot spots — chiefly un-annotated arithmetic over CGPoint's operator overloads,
# which can push a single expression into the hundreds of milliseconds and make
# the file stutter in the editor (SourceKit re-type-checks live on every
# keystroke). Fix a flagged site by giving the expression explicit type
# annotations so the solver stops exploring the operator overloads.
#
# The budget is wall-clock, so it is machine-dependent. Run it locally (not in
# CI, whose hosted runners have unreliable build times). The default sits
# between the library's current worst legitimate body (~85ms) and the
# operator-overload hot-spot class it guards against (~160ms and up), so it
# catches regressions without flagging today's code. Override with
# TYPE_CHECK_LIMIT_MS, and re-calibrate if the host is much slower/faster.

set -euo pipefail

LIMIT_MS="${TYPE_CHECK_LIMIT_MS:-120}"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
LOG="$BUILD_DIR/build.log"

echo "Type-checking BezierKit with a ${LIMIT_MS}ms per-body/expression budget…"

# Fresh build path forces a full compile so every body is type-checked (and thus
# timed) rather than served from the incremental cache.
status=0
swift build --build-path "$BUILD_DIR/.build" \
  -Xswiftc -Xfrontend -Xswiftc -warn-long-function-bodies="$LIMIT_MS" \
  -Xswiftc -Xfrontend -Xswiftc -warn-long-expression-type-checking="$LIMIT_MS" \
  > "$LOG" 2>&1 || status=$?

if [ "$status" -ne 0 ]; then
  echo "swift build failed:"
  cat "$LOG"
  exit "$status"
fi

# Keep only the warning lines (drop the source-caret continuation lines) and dedupe.
violations="$(grep "to type-check" "$LOG" | grep -v '^[[:space:]]*|' | sort -u || true)"

if [ -n "$violations" ]; then
  echo "FAIL: BezierKit type-checking budget (${LIMIT_MS}ms) exceeded:"
  echo "$violations"
  echo
  echo "Give the flagged expression explicit type annotations (e.g. 'let p: CGPoint = a - b',"
  echo "or collapse a chained .map/.filter into one closure with an annotated result) so the"
  echo "type checker stops inferring intermediate types through CGPoint's operator overloads."
  exit 1
fi

echo "OK — no function body or expression exceeded ${LIMIT_MS}ms."
