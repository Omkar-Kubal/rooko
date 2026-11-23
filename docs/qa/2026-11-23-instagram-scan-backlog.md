# Instagram Reels scan backlog — 2026-11-23

## Device result before the fix

- Device: OPPO CPH2565, Android 15. Target: Instagram `456.1.0.56.78`. Rooko: debug `1.0.0`.
- The user confirmed ten visibly changed Reels. Today stayed at Instagram 8 and combined 17 (YouTube 9): zero increments for that session. The earlier uninstrumented ten-change session went from Instagram 7 to 8.
- The bounded, debug-only category trace recognized the Instagram feed 133 times and found its item node 133 times. It queued 130 item scans and dropped 114 pending scans. Only two available hashes and one estimator candidate appeared before the 32 KiB trace cap. The trace also recorded 81 root-package changes; those need a separate source-level diagnosis if the revised scanner still misses items.
- The trace contains only static categories and allowlisted app/version names. No labels, hashes, item IDs, counts, or timestamps were written. The marker and generated trace files were removed from the phone.

## Root cause and change

The Accessibility callback submitted a new background label scan for nearly every Reels event. A single worker processed snapshots in FIFO order while up to eight older nodes waited. During the user run, the queue repeatedly overflowed, so the worker rarely reached a current item key before the feed changed. This is a demonstrated upstream loss point; the capped trace cannot assign each of the ten missed Reels to it individually.

The scanner now keeps one active scan and one coalesced request. After completion it reads the current feed and item node again, instead of processing an old queued node. Feed recognition still draws the overlay before label processing. Label inspection and hashing remain off the Accessibility event thread, and the current feed is revalidated before a key reaches the estimator. Consent, app selection, and version gates remain in place.

## Follow-up runs and confirmation scheduling

- The first user-confirmed ten-Reel run on the coalesced-scan build moved Instagram 8→13 (5/10). A second ten-Reel run on the same installed build moved 13→13 (0/10). Rook stayed visible. This confirms that coalescing alone did not solve the undercount.
- A diagnostic build was installed in place. The next user-confirmed ten-Reel run moved Instagram 13→18 (5/10), with Rook visible. Its debug-only aggregate contained 475 feed recognitions, 474 found item nodes, 458 queued scans, 16 hashes, seven candidates, five counts, and two stationary outcomes. Eighteen root-package changes and two feed revalidation failures were also recorded. The summary contained only allowlisted app/version and static category totals; the marker and file were removed afterward.
- The service cancelled a pending 150 ms candidate recheck at the start of every estimated scan. It also ran the feed and item root queries on every routine Instagram event, despite hundreds of events per short session. The revised implementation preserves the earliest scheduled check through event bursts and rate-limits routine scans to one per 250 ms. Scroll and window state events remain immediate; definite feed exits cancel pending checks. This is a source-level fix for demonstrated pressure and cancellation, not yet a measured accuracy result.
- Three `EstimatedScanFlowTest` regression cases cover event bursts, surviving confirmation, and cancellation on exit. The full Android suite passed 157 tests with zero failures/errors/skips; `:app:assembleDebug` succeeded with `org.sqlite.tmpdir` pointed to a workspace temp directory after a host KSP temp-dir error. The APK was installed without clearing data.
- On this revised build the user entered Reels from Instagram Home and confirmed ten visibly changed Reels. Today moved Instagram 18→29 and combined 27→38 (YouTube remained 9). The 11-count increase matches one eligible Reel on entry plus ten changed Reels. The user confirmed Rook stayed visible throughout. The category-only trace showed 177 feed recognitions, 175 item nodes, 99 available hashes, 14 candidates, 11 counted outcomes, one duplicate, and 73 stationary outcomes. No additional count appeared during a brief stationary observation; this is not the full 100-case stationary corpus. The trace marker/file and temporary Today UI dump were removed. Accessibility and overlay permissions remained on; the crash buffer had no Rooko fatal entry.

## Checks and open gate

| Requirement | Acceptance behavior | Evidence | Result | Follow-up |
| --- | --- | --- | --- | --- |
| FR-005, FR-017 | Selected Instagram Reels produce estimated count events without retaining feed content. | User-confirmed 10-change OPPO runs; category-only traces; Today counts. | Earlier builds undercounted. Current build recorded 11/11 eligible items in one run, including the entry Reel. | Repeat on other sessions, versions, and devices; inspect false positives and negatives. |
| FR-017 | Ten distinct settled item keys yield ten estimated events with no stationary repeats. | `DebugEventEstimateTest.tenDistinctSettledReelsProduceTenEstimatedEvents`. | Passed. | Device item signals still require validation. |
| FR-050 | Background item scanning leaves immediate overlay recognition intact. | `CoalescedItemScanRequestsTest`, `EstimatedScanFlowTest`, Android unit suite, and user-confirmed OPPO run. | Rook stayed visible during the revised build's 10-change run; initial draw timing not remeasured. | Measure first appearance and repeat continuity on other devices. |
| FR-010, FR-021 | Detector accuracy meets the multi-device release gate. | One OPPO version and two short user-labelled sessions. | Open. | Version corpus across three device families is still required. |

`CoalescedItemScanRequestsTest` failed before implementation with the missing coordinator and passed after implementation. The full Android unit suite passed 154 tests, with zero failures, errors, or skips. `flutter build apk --debug --no-pub` succeeded. The APK was installed on CPH2565 using `adb install -r` without clearing app data; Today remained at combined 17, Instagram 8, YouTube 9, and Android reported the Accessibility service enabled and bound. This does not establish post-fix live counting accuracy.
