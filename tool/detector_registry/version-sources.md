# Detector version source ledger

**Observed:** 2026-11-13 (UTC)  
**Purpose:** Record public evidence that an exact package/version string exists. This is a discovery catalog, not detector validation.

## Source limits

- Google Play listings confirm the official app identity and package, but their public web pages did not expose exact Android `versionName` history during this review: [YouTube on Google Play](https://play.google.com/store/apps/details?id=com.google.android.youtube), [Instagram on Google Play](https://play.google.com/store/apps/details?id=com.instagram.android).
- Exact version records below come from APKMirror and APKPure release pages. These third-party archives are useful for discovery and may omit staged rollouts, regional variants, beta channels, older records, or releases that were never submitted. This is not a complete historical registry; unknown versions remain unsupported.
- APK variants/build codes are not separate catalog records when the Android `versionName` is the same. The resolver compares the locally installed exact `versionName` and package.
- Every entry stays `catalogued` without a `profileId`. A release record proves only that the version was observed in a public archive. It does not prove that its Shorts/Reels layout is compatible or accurate. A `supported` mapping needs an exact-version profile and the full FR-010–021 evidence gate.

## YouTube

The archive's [YouTube release index](https://www.apkmirror.com/apk/google-inc/youtube/all-versions/) showed the recent entries below. Individual release pages are used as each registry entry's `sourceUrl`.

| Exact version | Evidence URL | Evidence note |
|---|---|---|
| `21.45.82` | https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-45-82-release/ | Also observed installed on RMX2156/API 31. |
| `21.44.539` | https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-44-539-release/ | Archive release page. |
| `21.44.535` | https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-44-535-release/ | Archive release page. |
| `21.43.525` | https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-43-525-release/ | Archive release page. |
| `21.43.526` | https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-43-526-release/ | Archive release page. |
| `21.44.534` | https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-44-534-release/ | Previously probed on RMX2156/API 31; remains unsupported. |
| `21.44.528` | https://apkpure.net/youtube-app/com.google.android.youtube/download/21.44.528 | Added from APKPure's package-specific versions index on Nov 13; exact detail page canonical URL and `softwareVersion` both report `21.44.528`. Catalogued only. |
| `21.43.527` | https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-43-527-release/ | Archive release page. |
| `21.42.243` | https://apkpure.net/youtube-app/com.google.android.youtube/download/21.42.243 | Added from APKPure's package-specific versions index on Nov 13; exact detail page canonical URL and `softwareVersion` both report `21.42.243`. Catalogued only. |
| `21.40.165` | https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-40-165-release/ | Previously used for a debug-only pilot; not release validation. |

## Instagram

The [Instagram versions index](https://apkpure.net/instagram-app/com.instagram.android/versions) displayed the versions below. Detail pages provide the version-specific links; the latest page currently uses a generic download route and was observed to report `455.0.0.51.72` on the observation date.

| Exact version | Evidence URL | Evidence note |
|---|---|---|
| `455.0.0.51.72` | https://www.apkmirror.com/apk/instagram/instagram-instagram/instagram-455-0-0-51-72-release/ | APKMirror's exact-version release page; APKPure's [package page](https://apkpure.net/instagram-app/com.instagram.android) independently reports package `com.instagram.android` and version `455.0.0.51.72` on Nov 12, 2026. Installed on RMX2156/API 31; remains catalogued only. |
| `454.0.0.54.77` | https://apkpure.net/instagram-app/com.instagram.android/download/454.0.0.54.77 | Previously probed on RMX2156/API 31; remains unsupported. |
| `453.0.0.57.79` | https://apkpure.net/instagram-app/com.instagram.android/download/453.0.0.57.79 | Versions index entry. |
| `452.1.0.53.64` | https://apkpure.net/instagram-app/com.instagram.android/download/452.1.0.53.64 | Versions index entry. |
| `453.0.0.55.79` | https://apkpure.net/instagram-app/com.instagram.android/download/453.0.0.55.79 | Versions index entry. |
| `452.0.0.48.64` | https://apkpure.net/instagram-app/com.instagram.android/download/452.0.0.48.64 | Versions index entry. |
| `451.0.0.53.80` | https://apkpure.net/instagram-app/com.instagram.android/download/451.0.0.53.80 | Versions index entry. |
| `450.0.0.50.77` | https://apkpure.net/instagram-app/com.instagram.android/download/450.0.0.50.77 | Versions index entry. |
| `449.0.0.52.84` | https://apkpure.net/instagram-app/com.instagram.android/download/449.0.0.52.84 | Versions index entry. |
| `374.0.0.43.67` | https://apkpure.net/instagram-app/com.instagram.android/download/374.0.0.43.67 | Older archived record. |

## QA-device cross-check

On 2026-11-12, RMX2156 reported YouTube `21.45.82` and Instagram `455.0.0.51.72`. YouTube's exact APKMirror release page and Instagram's exact APKMirror release page are in the catalog. APKPure independently confirms Instagram's package and installed version. Local package-manager discovery succeeds independently of registry membership; catalog membership still does not enable detection.

## Archive labels withheld from the exact-version catalog

The APKMirror URLs below expose archive release titles containing channel or variant labels. The available evidence does not establish that `-BETA` or `-SECONDARY` is part of Android's installed `PackageInfo.versionName`, so these labels are retained as source observations but are not sent as exact version keys:

- `21.45.82-SECONDARY`: https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-45-82-secondary-release/
- `21.45.82-BETA`: https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-45-82-beta-release/
- `21.45.80-BETA`: https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-45-80-beta-release/
- `21.44.534-SECONDARY`: https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-44-534-secondary-release/
- `21.44.534-BETA`: https://www.apkmirror.com/apk/google-inc/youtube/youtube-21-44-534-beta-release/

## Maintenance

Review archive and official app listing changes weekly and after target-app updates. Record the observation date, package, exact version, source URL, and any source disagreement before editing the catalog. Add newly discovered versions as `catalogued`; only change one to `supported` after its own FR-010–021 detector evidence and bounded remote profile are reviewed.
