/// A normalized Instagram hashtag destination.
abstract final class InstagramHashtag {
  static const int maxCodePoints = 100;
  static const Set<String> _instagramHosts = {
    'instagram.com',
    'www.instagram.com',
    'm.instagram.com',
  };
  static final RegExp _tagPattern = RegExp(
    r'^[\p{L}\p{M}\p{N}_]+$',
    unicode: true,
  );

  /// Returns a lowercase tag without its leading `#`, or null when invalid.
  static String? normalize(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;

    final urlTag = _tagFromUrl(value);
    if (urlTag != null) {
      value = urlTag;
    } else if (_looksLikeInstagramUrl(value)) {
      return null;
    }

    if (value.startsWith('#')) value = value.substring(1);
    final normalized = value.toLowerCase();
    if (normalized.runes.length > maxCodePoints ||
        !_tagPattern.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  /// Builds the canonical HTTPS Instagram hashtag search URI.
  static Uri searchUriFor(String tag) {
    final normalized = normalize(tag);
    if (normalized == null) {
      throw ArgumentError.value(tag, 'tag', 'Invalid Instagram hashtag');
    }
    return Uri.https(
      'www.instagram.com',
      '/explore/tags/$normalized/',
    );
  }

  static String? _tagFromUrl(String value) {
    var candidate = value;
    final lowercase = candidate.toLowerCase();
    if (_instagramHosts.any((host) => lowercase.startsWith('$host/'))) {
      candidate = 'https://$candidate';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme) return null;
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        !_instagramHosts.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }

    final segments = uri.pathSegments;
    if (segments.length != 4 ||
        segments[0] != 'explore' ||
        segments[1] != 'tags' ||
        segments[3].isNotEmpty) {
      return null;
    }
    return segments[2];
  }

  static bool _looksLikeInstagramUrl(String value) {
    final lowercase = value.toLowerCase();
    return lowercase.contains('://') ||
        _instagramHosts.any((host) => lowercase.startsWith('$host/'));
  }
}
