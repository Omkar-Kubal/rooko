class SupportedApp {
  const SupportedApp({
    required this.id,
    required this.name,
    required this.iconAsset,
    required this.androidPackageName,
  });

  final String id;
  final String name;
  final String iconAsset;
  final String androidPackageName;

  static const all = <SupportedApp>[
    SupportedApp(
      id: 'youtube',
      name: 'YouTube Shorts',
      iconAsset: 'assets/supported-app-icons/youtube-shorts.png',
      androidPackageName: 'com.google.android.youtube',
    ),
    SupportedApp(
      id: 'instagram',
      name: 'Instagram',
      iconAsset: 'assets/supported-app-icons/instagram.png',
      androidPackageName: 'com.instagram.android',
    ),
  ];

  static SupportedApp? byId(String id) {
    for (final app in all) {
      if (app.id == id) return app;
    }
    return null;
  }
}
