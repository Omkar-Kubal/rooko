import 'package:url_launcher/url_launcher.dart';

typedef PrivacyPolicyLauncher = Future<bool> Function(Uri uri);

final Uri publicPrivacyPolicyUri = Uri.parse(
  'https://sites.google.com/view/rooko/home',
);

Future<bool> launchPublicPrivacyPolicy(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
