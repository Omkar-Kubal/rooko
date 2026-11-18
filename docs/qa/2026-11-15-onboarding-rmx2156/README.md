# Onboarding preview on RMX2156

Target: RMX2156, Android 12, device `X4GEAYDMWGAUI7WG`.

The 2026-11-15 debug APK was installed with `adb install -r -d` over the existing app, preserving its data. The app launched in `com.appylab.syncscroll.MainActivity`. The current UI tree (`verify.xml`) contains the bold counter-preview heading, Instagram Reels and YouTube Shorts logo labels, and the `Get started` action. It does not contain the removed illustrative footer. `get-started.png` is the current screen capture. `first-page.png` records the previous button/footer version for comparison.

The preview is a simulation. No Instagram Reels or YouTube Shorts counting was tested during this check.

Title follow-up: `page-title.png` shows the shared 32 sp onboarding page-title treatment on RMX2156 after a fresh debug build and in-place install. `title-check.xml` confirms the title, both app-logo labels, and “Get started.” The illustrative footer remains absent.

Rook sequence follow-up: `rook-gathered.png` shows blurred Ready Rook inside the settled neutral dot ring with “Tap to continue.” `rook-revealed.png` shows the clear Ready Rook, a Reels/Shorts count explanation, and “Hi, Sync Scroll.” `rook-reveal.xml` confirms the revealed labels. `rook-gather-motion.mp4` records a cold launch of the gathering step for animation review. The final debug APK was installed in place again after the large-text scroll fix; the on-device presentation is unchanged by that fix at the RMX2156's normal text scale. The onboarding widget suite passed 15 tests, including reduced-motion, lifecycle pause, Back/draft, and 2× text at 360×640; targeted Flutter analysis found no issues. No live feed counting was tested.

The final gathering version extends the dots' starting positions toward the four viewport corners before they converge on Rook. `rook-gather-from-corners.mp4` records a cold launch of that final build. It was installed over the existing app on RMX2156, and a final UI-tree check found blurred Rook and “Tap to continue” in the foreground. The earlier motion clip remains as development evidence.
