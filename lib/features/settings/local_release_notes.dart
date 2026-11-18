/// Release notes shipped with the current Android app version.
///
/// Keep this list factual and update it with each app release. Older release
/// history is intentionally not reconstructed.
abstract final class LocalReleaseNotes {
  static const version = '1.0.0';
  static const entries = <String>[
    'Check Accessibility, app-version, and floating-counter setup in Help & Feedback.',
    'Review a local diagnostic summary before copying it for support.',
    'Support email opens your email app; Rooko does not send it for you.',
  ];

  static List<String> forVersion(String versionName) =>
      versionName == version ? entries : const <String>[];
}
