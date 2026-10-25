# PR #40 follow-up validation — 2026-10-25

Status: complete client builds successfully; the latest visual refinements are awaiting an authenticated UI pass. The PR remains closed until that pass and replacement Before/After captures are complete.

## Completed checks

- The baseline PR head `a190a124` reproduces 44 expected failures in the native search-flow harness: cramped input, stale or narrow result geometry, initial-placement animation and saved-tag margins. Unrelated failures fail the baseline run.
- The patched source passes 117 native search-flow checks. Coverage includes input/request/response, six width changes, short windows, Previous/Next, refocusing, selecting a sender and dispatching the filtered query, cancellation, full-chat-width results, unchanged composer suggestion width, above/below popup placement, saved-tag row insets and initial/replacement slot layout.
- Six existing XCTest cases and 410 lower-level header/translation/description assertions pass. Their plain-SearchView checks are not end-to-end search tests.
- A complete Debug arm64 `Telegram.app` build succeeds with the actual native dependencies, including MTProtoEngineFFI, wallet_engineFFI, WebRTC and TDLib. No dependency implementation is replaced with a stub.
- The preceding `0a84ecd2` client was run with an authenticated isolated test account. The user exercised search and returned a video showing real results, navigation, Saved Messages and pin/no-pin layouts. That feedback prompted the current result-width, tag-margin and animation changes; the preceding video's behavior is not treated as verification of these new changes.

Environment: Apple Silicon, macOS 27.0.1, Xcode 27.1, Telegram 13.1.0 (283357).

## Full build

```sh
xcodebuild -workspace Telegram-Mac.xcworkspace -scheme Telegram \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/telegram-pr40-client-build -jobs 4 \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES MACOSX_DEPLOYMENT_TARGET=12.0 \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO \
  INDEX_ENABLE_DATA_STORE=NO GCC_GENERATE_DEBUGGING_SYMBOLS=NO \
  SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO COMPILATION_CACHE_ENABLE_CACHING=NO build
```

The initial missing-binary-artifact blocker is resolved. Pinned native dependencies and their shared headers were built locally. Xcode 27 compatibility adjustments and a local account-storage-root override were used only for the validation environment and are not part of the feature patch. This is an unsigned native arm64 Debug build, not a universal release/archive or App Store validation.

The component harness uses controlled backend/domain models and result rows; see README.md for exact extraction boundaries. Actual saved-tag/Premium rendering, real-server pagination and the calendar flow still require the latest full-client UI pass. Public Before/After captures must exclude account details and private chat content.
