# Detector profile fixtures

Profiles are exact-version only. A fixture must describe structural signals without feed text, descriptions, media, screenshots, OCR, audio, or raw item tokens. Record the package and version, Android API and device family, feed marker IDs, transition event/source, identity evidence, and positive and negative cases. Assign a revision before linking it from `AppDetectorProfile` and the validation matrix.

No app/version has a complete structural fixture yet. The historical Instagram `454.0.0.54.77` observation found `clips_viewer_view_pager` but no independently revalidated item identity or feed-entry signal, so it is disabled for new counts. Prior estimated aggregates remain readable. YouTube and the other onboarding apps have no eligible profile. Synthetic unit fixtures test state-machine behavior, not third-party app accuracy.
