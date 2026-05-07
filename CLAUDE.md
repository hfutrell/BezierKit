# Claude Code Guidelines for BezierKit

## Testing requirements

All tests must pass before opening a pull request, unless the user has explicitly stated otherwise.

To run the test suite:
```
swift test --enable-test-discovery
```

On macOS you can also run:
```
swift test --enable-test-discovery --enable-code-coverage
```

If Swift is not available in your local environment, push to the branch and verify CI (GitHub Actions) passes before considering a PR ready.

## Branch policy

Development happens on feature branches. The target release branch for any PR is specified at session start. Do not push directly to `main`.
