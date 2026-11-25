/// A locally saved Instagram profile destination.
abstract final class CreatorProfile {
  static final RegExp _handlePattern = RegExp(r'^[a-zA-Z0-9._]{1,30}$');
  static const Set<String> _reservedPaths = {
    'accounts',
    'direct',
    'explore',
    'p',
    'reel',
    'reels',
    'stories',
    'tags',
    'tv',
  };

  /// Returns a canonical handle or null for an invalid or non-profile value.
  static String? normalizeHandle(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('@')) {
      value = value.substring(1);
    } else {
      final lowerValue = value.toLowerCase();
      final isInstagramHost = <String>[
        'instagram.com/',
        'www.instagram.com/',
        'm.instagram.com/',
      ].any(lowerValue.startsWith);
      if (isInstagramHost) value = 'https://$value';

      final looksLikeUrl = value.contains('://');
      if (looksLikeUrl) {
        final uri = Uri.tryParse(value);
        if (uri == null ||
            (uri.scheme != 'https' && uri.scheme != 'http') ||
            !_isInstagramHost(uri.host) ||
            uri.userInfo.isNotEmpty ||
            uri.hasPort ||
            uri.hasFragment) {
          return null;
        }
        final segments = uri.pathSegments;
        final profileSegments = segments.isNotEmpty && segments.last.isEmpty
            ? segments.take(segments.length - 1).toList()
            : segments;
        if (profileSegments.length != 1) return null;
        value = profileSegments.single;
      }
    }

    if (!_handlePattern.hasMatch(value) ||
        value.startsWith('.') ||
        value.endsWith('.') ||
        value.contains('..') ||
        _reservedPaths.contains(value.toLowerCase())) {
      return null;
    }
    return value.toLowerCase();
  }

  static Uri profileUriFor(String handle) {
    final normalized = normalizeHandle(handle);
    if (normalized == null) {
      throw ArgumentError.value(handle, 'handle', 'Invalid Instagram handle');
    }
    return Uri.https('www.instagram.com', '/$normalized/');
  }

  static bool _isInstagramHost(String host) => const {
    'instagram.com',
    'www.instagram.com',
    'm.instagram.com',
  }.contains(host.toLowerCase());
}
