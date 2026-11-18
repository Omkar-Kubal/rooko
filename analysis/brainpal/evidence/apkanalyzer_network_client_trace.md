# BrainPal stats client host and identity trace

## Scope

Static DEX inspection of the same `base.apk` identified in `FINDINGS.md` (SHA-256 `1447f2dfe73e7b9253bda4693b404f6e335e4b2dbf9068cbd74c06a9ed18eaff`). The APK was inspected with Android SDK `apkanalyzer` and Android Studio JBR 25.0.3. These extracts do not establish runtime execution or transmission and have no REA Evidence IDs.

## Host and client construction

- `BrainRotStatsApiService` is created by the stats Retrofit provider in `jc.y`. That provider obtains `AuthConfig`, calls `getServerBaseUrl()`, passes it to Retrofit, and creates `BrainRotStatsApiService`.
- The Dagger factory in the same class constructs `AuthConfig` with `https://api.brainpalapp.ai`. This resolves the APK's static stats host. A separate Retrofit provider in the same class also has the slash-terminated literal `https://api.brainpalapp.ai/` for another API client.
- The stats Retrofit provider wraps a base OkHttp client with a metadata interceptor and an interceptor that creates the `http_swr_cache` cache directory.
- The base client includes the auth interceptor. It reads `access_token` from the auth SharedPreferences and adds `Authorization: Bearer <access_token>`. On HTTP 401, the inspected path uses `refresh_token` and `AuthApiService`, saves the returned tokens, and retries with the refreshed access token.

## Request identity fields

The metadata interceptor adds:

- `android_device_id`: `hd.g.a()` returns the stored `app_instance_android_id` from `brain_rot_instance_prefs`. When absent, the code reads `Settings.Secure.ANDROID_ID` and stores it under that preference key.
- `br_user_id`: the auth library's current `AuthUserProfileInfo.brUserId`, when present.
- `br_app_id`: `com.brainrot.android`.
- `app_version`: `22.1.644`.
- `app_version_code`: `644`.

The auth preference factory attempts EncryptedSharedPreferences and includes a fallback to regular SharedPreferences after recovery failure. This is a declared fallback path; it was not observed on the RM.

## Limits

The static trace does not show that a request occurred, the RM's actual header values, request or response bodies, or whether server-side analytics ran. No decrypted traffic or packet capture was obtained in this pass.

## Supporting extracts

The focused outputs are in `scratch/`:

- `jc_y_full.smali` — SHA-256 `0725282f885ebdd827d00e267da8189058d1162ff7609520fe38a57b636ffbf8`
- `jc_z_full.smali` — SHA-256 `eecd408f94982003ea2fe69a2709a2bc68238c3183f8e8118141639c15711bbb`
- `gk_a_full.smali` — SHA-256 `477f4ea87474991bbd20b03eafd8fbc7e25219f3e8d172e823ca7056cce763df`
- `trace_ad_a.smali` — SHA-256 `5806fb7fcb3d8aa7ea07e0ec6636614e1d0ba7720c9f727a6fd0c6a3a6fdb491`
- `trace_ad_e.smali` — SHA-256 `c0361c6ba4301b6f24e4d726d765445d7376aa60cc0540c2a2b0771d600efedb`
- `trace_g_a.smali` — SHA-256 `1880b1b06cb1ac12044969963f53021d54d51809c84b380f95bbbc1a750c2c55`
- `trace_hd_g.smali` — SHA-256 `f49e34520ec17180295db4f0ab1389b23f1582a42b336b2c2b35e5f15ba53dc9`
- `trace_g_d.smali` — SHA-256 `724b0b6dfd90a2ab96d2c30975ee7d30612f2d22d733ffca5322e81ac17d2d42`

