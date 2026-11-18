# EntryOnboarding preference persistence boundary

Target: `analysis/brainpal/apk/com.brainrot.android/base.apk`

APK SHA-256: `1447f2dfe73e7b9253bda4693b404f6e335e4b2dbf9068cbd74c06a9ed18eaff`

Evidence type: static DEX/Smali inspection using Android SDK `apkanalyzer` 23.0 and the Android Studio JBR 25.0.3. This establishes declared Room schema and code paths, not that the writes executed on the RM or that any analytics request was transmitted.

## Verified local preference storage

- `UserPrefDatabase_Impl` exposes `user_pref_boolean` and `user_pref_string`. `ka.r` contains their Room DDL: the boolean table stores a text key and integer value; the string table stores a text key and text value. Both use `user_pref_key` as the primary key.
- The generated insertion adapter (`of.b`) contains `INSERT OR REPLACE INTO user_pref_boolean ...` and `INSERT OR REPLACE INTO user_pref_string ...`. Its write dispatch handles `UserPrefBoolean` and `UserPrefString` models.
- The boolean repository path `xc.w.a` builds a `UserPrefBoolean` and calls the `tc.k` DAO adapter. The string path `xc.d.a` calls `uc.g.e`, which builds `UserPrefString` and submits it to the Room adapter. This confirms that values sent through these wrappers have a local SQLite persistence path.

## Values written by EntryOnboarding completion

In `hi.l0.invokeSuspend`, after the final EntryOnboarding screen, the code calls the boolean wrapper with `vc.n.Z` and `true`. `vc.n.Z` maps to `br_onboarding_questions_done_v1`. The coroutine then calls `jg.n.a`.

`jg.n.a` reads `Ljg/l.e` (`Lng/p`), writes its enum name under `vc.r.X` (`br_entry_dream_path_v1`), and writes a serialized plan value under `vc.r.G` (`br_onboarding_plan_v1`). It does not read `Ljg/l.b` (the selected-option map) or `Ljg/l.d` (the derived EntryAnswers record).

The completion analytics event reads the last EntryAnswers group for the `limit` value and sends a JSON object containing only `limit`. The option-selection reducer `jg.n.c(Ljg/f)` updates the ViewModel selection map, derives EntryAnswers, and dispatches `ENTRY_ONBOARDING_OPTION_SELECTED` with screen/option/selected/picks fields. The inspected reducer does not write to Room.

Therefore, this trace confirms a Room write path for the completion flag and separate plan/path values, but does not show the individual EntryOnboarding picks (including Q1 `bored` and Q2 `3_6`) being written locally. No completion write was observed at runtime because the RM was left at the unanswered health question. Other untraced mechanisms are outside this bounded conclusion.

## Supporting extracts

All Smali extracts below were generated from the APK above with `apkanalyzer dex code --class <class> <apk>`.

- `../scratch/pref_db_impl.smali` — SHA-256 `3e9c174e9b4f994a457a7032974ad309e8267062be11e6f66ea0aaea18b82be0`
- `../scratch/pref_db_open_ka_r.smali` — SHA-256 `a5141ff3df2df7dd59b7cb40621f8cfd85088b7072b76fd2d48d4197f023d0ba`
- `../scratch/pref_insert_adapter_of_b.smali` — SHA-256 `c9db697c475a27586d314d2e8ba7d9410cf18571b5d3975a7c44bd7f751818f47`
- `../scratch/pref_query_dispatch_rj_x1.smali` — SHA-256 `4fc9f1c5ca0a503f24a1918ad6add2547868ef32b1a638485988400d7a622edb`
- `../scratch/pref_dao_tc_k.smali` — SHA-256 `73bb9f5f35eef0642564485830bb09e285151e74fd487db45982f1651706a861`
- `../scratch/pref_sql_tc_e.smali` — SHA-256 `7f27df72b1990919ae9c390a2d493162497e2b3cf17c4dd3f48d021ea0c23eb7`
- `../scratch/entry_uc_g.smali`, `entry_xc_w.smali`, and `entry_xc_d.smali` — repository wrapper paths described above.
- `../scratch/entry_hi_l0.smali`, `entry_jg_n.smali`, `entry_vc_n.smali`, and `pref_keys_vc_r.smali` — completion, reducer, and preference-key mappings.

The three field-reference scans cover `classes.dex`, `classes2.dex`, and `classes3.dex` extracted from this same base APK. They preserve direct DEX references to the ViewModel state fields; they do not rule out reflection or other indirect mechanisms.

- `apkanalyzer_entry_state_refs.json` (`Ljg/l;->b`, selection map) — SHA-256 `70fb88373fe3cc5c27976666ff1d4c6a647b42f19c0c514fbe98dd118cd7411a`
- `apkanalyzer_entry_answers_refs.json` (`Ljg/l;->d`, EntryAnswers) — SHA-256 `3e9e024c45e19919dbcd7369f823095498152fe92971f730db9d272494e84932`
- `apkanalyzer_entry_prefs_state_refs.json` (`Ljg/l;->e`, plan/path state) — SHA-256 `75ccbd6e6f003616e8f1826441802f04da5f0e9ec6e1b7d174e1f503ca1906ff`
