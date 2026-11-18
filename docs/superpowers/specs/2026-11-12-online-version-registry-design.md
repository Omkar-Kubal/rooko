# Signed remote detector profiles and version registry

## Intent

Resolve the target app version installed on the user's device to a signed, validated detector profile from the shared internet registry. A profile is bounded data that configures detector strategies already implemented in Kotlin; it is not executable logic. This avoids rebuilding Sync Scroll to map a newly validated app version or to update resource-ID configuration. Version discovery is local; registry requests contain no app/device identifiers or installed versions.

## Goals and limits

- Exact package/version entries can identify known, supported, disabled, or unvalidated app releases.
- A version maps to a stable ID for a signed profile definition. Multiple versions may share that ID only after per-version evidence passes the detector gate.
- Only a verified, unexpired registry may resolve support; unknown, catalogued-only, expired, invalid, or unknown-profile mappings fail closed.
- The registry can be fetched over HTTPS and cached as a signed envelope. Profiles contain only bounded exact Android resource IDs and enum values selecting built-in detector strategies; no code, text selectors, or feed-content rules are allowed.
- Current production profiles are empty. This work must not turn any historical or current YouTube/Instagram version into supported without the accuracy evidence.

## Approaches

1. **Signed remote profiles selecting fixed app strategies — selected by the user.** Exact versions map to shared, bounded configuration in the signed registry. It enables compatible, validated releases to be added without an APK update while retaining fixed Kotlin behavior.
2. **Ship every profile definition in the APK.** Rejected for this requirement because new version mappings and resource-ID changes would wait for an app update.
3. **Download executable detector code or content selectors.** Rejected because it would permit arbitrary runtime behavior, could read feed content, and would bypass app review.

## Registry behavior

The signed envelope contains base64 payload bytes and an ECDSA/SHA-256 signature. Payload schema v2 is UTF-8 JSON with a monotonically increasing sequence, issue/expiry timestamps, exact package/version records, and shared profile definitions. Profiles contain a stable ID, an allowlisted package, the fixed strategy ID `accessibility_structure_v1`, bounded lists of exact `package:id/resource_name` markers, one allowlisted identity strategy, and an optional exact identity-node ID. Every supported exact-version entry also carries signed validation summary values: report ID, at least 200 transitions, at least 100 stationary/non-feed cases, at least three device families, precision ≥98%, recall ≥90%, and zero stationary repeats. The publisher and Android parser reject mappings below these thresholds. The parser rejects arbitrary class names, text, regular expressions, traversal paths, thresholds that change detector behavior, executable payloads, unknown strategies, excessive list sizes, malformed IDs, and profiles for other packages. Verification happens before parsing trusted fields or caching. Schema v1 remains readable for compatibility but can only reference APK-bundled profiles. HTTPS uses a fixed build-configured endpoint, no redirects, a 15-second overall request deadline, bounded response size, and sends only a generic request for the whole registry. The registry host can still receive the client's IP address and ordinary network metadata; the in-app privacy notice says so.

Cache the full signed envelope and highest accepted sequence in app preferences. Verify the cached signature and expiry on each read. A still-valid cache works offline. A failed refresh does not replace it; an expired cache resolves no profiles. Refresh on app/service startup, then no more than once per 15 minutes, with the Accessibility service checking periodically while it remains connected. Reject lower sequence numbers and changed payloads reusing a sequence. Validate package IDs against the app's allowlist and accept only profiles whose bounded structure passes the installed parser.

Profiles configure only existing detector code. The installed version is bound to a shared profile at runtime; observations and deadline checks continue to compare against the exact locally installed version. Catalog status is separate from detector support. The publishing gate requires an exact-version profile and accuracy evidence for every supported mapping. A signed config is not evidence by itself and must not enable counting without the FR-010–021 gate. New, incompatible app behavior still requires a Sync Scroll code update to add a safe built-in strategy.

## Deployment state (2026-11-12)

Sequence 1 is publicly deployed at https://syncscroll-detector-registry-20261112.soham-badame-7297.chatgpt.site/sync-scroll/v1/registry.json and the endpoint/public-key pin are configured in Android Gradle properties. The v1 18-entry payload is catalogued-only and expires 2026-12-12. The v2 publisher/client extension supports signed remote profile data; no production profile is currently published. A live request and RMX2156 cache acceptance are recorded in qa/2026-11-12-detector-registry-live/README.md.

The host is a public Codex Sites hostname, not a project-controlled domain. Static request-log retention has not been verified. The P-256 private key is DPAPI-protected for the current Windows user, with no separately verified backup or formally named custodian. The 18 entries are a partial archive snapshot. Production detector profiles remain empty until per-version accuracy evidence passes; the current installed YouTube and Instagram versions therefore remain unavailable for counting.

## Acceptance map

| Requirement | Acceptance evidence |
| --- | --- |
| PR-17 / FR-010 | Exact installed version resolves only when a signed record maps to a profile definition and every mapped version passed validation; compatible versions can share a profile ID |
| FR-018 | Valid v1/v2 signature/schema/sequence accepted; invalid, expired, malformed, rollback, unsafe configuration, and unknown profile data fail closed |
| FR-018 | Offline uses only unexpired verified cache; refresh failure leaves valid cache intact |
| Privacy | Registry request contains no app/device/version/usage identifiers |
| Existing detector gate | Current empty production profile list leaves YouTube and Instagram unsupported |

Implementation plan: [signed remote detector profile plan](../plans/2026-11-13-signed-remote-detector-profiles.md).
