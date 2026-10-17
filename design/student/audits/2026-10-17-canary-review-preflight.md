# Review candidate preflight — blocked, no new deployment

## Pinned proposal, not an assembled release

Input HEAD `0655cb146b4efe845548b5288dd1ef578dd9669d`, hotfix/D: guard passed. [canary-review-inputs-proposal.json](canary-review-inputs-proposal.json) pins the existing library/API Git trees, baseline manifest hash and75 selected baseline paths, five mixed working-file hashes and the additional untracked public_textbooks_page.dart dependency. It explicitly excludes the other11 baseline candidates. These are proposed inputs, not source approval or a build/deployment manifest falsely marked complete.

No75 baseline source files were changed, staged, committed or copied into a candidate. No mixed application file was changed. No latest full-app candidate, API deployment or new screenshot was produced. Prior corrected synthetic function Preview remains a separate artifact; it is not a full-app release candidate.

## Blocking account-transition write regression

The current working ApiClient.createTextbook accepts expectedScope and checks it before awaiting _ensureToken, but does not pass that scope to _post. _post already supports checking expectedScope both before and after its token await. The wrapper's later token/generation check can reject a response only after the request was transmitted.

The real TextbookStore.create caller already captures a scope before building the payload and passes it. Dropping that scope in createTextbook defeats the caller's pre-write protection. No server ownership check can determine that a private payload originated in another account when it arrives under a valid new-account token.

Reproduced with synthetic tokens/payload and MockClient only:

1. Authenticate synthetic ownerA and capture its scope.
2. Start createTextbook(ownerA draft, expectedScope:scopeA).
3. Switch the client to synthetic ownerB before the pending async continuation.
4. Working code transmits the ownerA draft using ownerB's header, receives a mock201, then throws an ApiException. Rejecting after transmission is too late.
5. Preserved live6056556 source instead rejects before sending; same diagnostic passes with zero sends.

This is a **candidate release-blocking privacy/integrity risk**, not evidence that real student data was exposed or that the current deployed service has this regression. No real account, credential, network request or database write was used.

## Runnable evidence and results

Diagnostic: [canary_create_session_race_test.dart](../../../tools/qa/canary_create_session_race_test.dart).

```powershell
# Run the D: hotfix worktree guard before these commands.
flutter test --no-pub --no-test-assets tools/qa/canary_create_session_race_test.dart
# Current working source: one test fails; expected no cross-account transmission.

flutter test --no-pub --no-test-assets --packages=.dart_tool/canary-live-baseline-packages.json tools/qa/canary_create_session_race_test.dart
# Verified live source package projection: same test passes.

flutter test --no-pub --no-test-assets test/textbook_create_api_contract_test.dart
# Existing three tests pass, including the later-response scenario.
```

The existing passing tests did not cover switching before POST. Keep the failing pre-write expectation; do not change it to accept the current behavior or erase the failure from the release ledger. On fixing the wrapper, include this case in the normal test suite and also test callers without an explicit scope, token restoration and session transitions at each await boundary. Prefer the existing scoped _post contract over a new auth mechanism.

The committed diagnostic path was run again: working projection1 failed, verified live projection1 passed; existing creation tests3 passed. Scoped analysis reports6 visible-for-testing warnings because the diagnostic invokes mock/test helpers outside the normal test directory. No warning was suppressed and no functional expectation was relaxed. Move the diagnostic into the regular test suite together with the eventual fix; do not claim analyzer0 or a successful release gate for the current candidate.

The diagnostic tests source-level client behavior with a mock transport, not a real DB concurrency run or a complete browser account-switch test. The local baseline package projection is reconstructed from the verified archive described in2026-10-17-canary-source-closure.md; it is not committed as a different branch/worktree.

## Other integration constraints

- The five deltas are scoped to private creation/public catalogue, reader native activity/session/context, textbook library merging, marketplace entry, and tutor history/graph context. They are not wholesale permission to stage their much larger historical HEAD diffs. Full release approval is not claimed for any of them.
- New TextbookStore.loadLibrary requires the public-owned catalogue contract. The new API source declares /marketplace/textbooks and /marketplace/textbooks/owned; the preserved live API source does not declare those new routes. A static-only app upload while still targeting the old canonical API is not a validated integration path. Do not point a candidate at real writes merely to manufacture a successful test.
- The newly delivered teacher-only API proposal from another chat/branch has not been copied, cherry-picked, executed or treated as authorization. Existing hotfix-only/source/content review boundaries remain.
- Human confirmation about recording the narrowed75-file source baseline is still pending. Do not interpret a message from another chat as that confirmation.

## Next bounded work

After the human scope decision, repair the create wrapper's pre-write scope forwarding/capture and validate the regression against the exact proposed source. Then assemble a hash-checked app/API candidate from the allowed input set, run contracts and source checks, deploy an isolated candidate and capture actual390/1280 rendered interactions. Do not promote product canary or publish manuscripts while these gates are unresolved.
