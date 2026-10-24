# PR #40 follow-up validation — 2026-10-25

Status: not ready for full-client review. The PR remains closed.

- Baseline: PR head a190a124. The new native search-flow harness reproduces 23 geometry/viewport failures. At a 742 pt pane width, the group-search text viewport is 95 pt. After width changes, the popup retains its previous x/width, overlaps the new header position or extends beyond the chat.
- Patched source: 101 native search-flow checks pass. This includes input/request/response, resizing, short windows, Previous/Next, refocusing, selecting a sender and dispatching the filtered query, cancellation, and above/below popup placement with an oversized requested height.
- Existing focused checks: six XCTest cases and 410 lower-level header/translation/description assertions pass. Their plain-SearchView checks are not end-to-end search tests.
- Native UI smoke: typed a query through the actual text field, observed the request and result list, used Previous twice and observed message IDs 1 and 2, and opened the sender selector. This used the generated generic-data fixture, not Telegram.app.
- Modified production Swift files pass syntax parsing. `git diff --check` passes.

Environment: macOS 27.0.1, Xcode 27.1. App version/build: N/A for the component executable. Search backend/domain models and result rows are controlled; no account or network operations are performed. See README.md for exact extraction and coverage boundaries.

A separate real-client build was attempted with:

```sh
xcodebuild -workspace Telegram-Mac.xcworkspace -scheme Telegram -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/telegram-pr40-client-build CODE_SIGNING_ALLOWED=NO build
```

It stopped during package resolution, before client compilation:

```text
local binary target 'MTProtoEngineFFI' ... MTProtoEngineFFI.xcframework ... does not contain a binary artifact.
local binary target 'wallet_engineFFI' ... wallet_engineFFI.xcframework ... does not contain a binary artifact.
```

No full-client build, authenticated search test or replacement live-app Before/After capture was obtained. The confirmation checkbox must remain unchecked until that verification is completed. Passing these native checks alone is insufficient to request review again.
