# Firestore Rules regression checks (development only)

These tests use the **local** official Firestore emulator with the fixed project
`demo-quickfix-validation`. They refuse missing/non-local emulator hosts and do not
read production credentials or enable the real quote feature flag. Fixture quote
flags exist only in the isolated emulator database.

Requirements: Node >=24.12 (Firebase test SDK requirement), Java 21, npm.

```sh
cd validation/firestore
npm ci
npm test
```

The package/lockfile contains development-only test tools, not mobile or server
runtime dependencies. CI installs them in a separate job. The real application
rules are compiled, not copied into a mock interpreter. Tests cover both allowed
and denied paths, and negative assertions require permission-denied (not arbitrary
SDK errors). No successful compile/test result is implied merely by adding this
harness: inspect the current CI run and its diagnostic check.

Coverage includes role/trust-field escalation, private address/proof/payout data,
owner assignment/worker status transitions, chat bootstrap and receiver-only read
state, pending withdrawal/selection, weighted review proof, scoped receipts/reports,
private payout revision, fresh-login cleanup/stale-session recreation, de-identified
history, default-off quotes/exact-pin privacy/selection, and bidirectional dispute
report links. This is a regression suite, not an independent financial audit or a
blanket security certification.
