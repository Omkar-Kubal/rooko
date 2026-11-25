import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/instagram_hashtag.dart';

/// Persists normalized Instagram hashtags in private app preferences.
class HashtagShelfRepository {
  HashtagShelfRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static const storageKey = 'rooko_instagram_hashtag_shelf_tags';

  final Future<SharedPreferences> Function() _preferencesProvider;

  Future<List<String>> load() async {
    final preferences = await _preferencesProvider();
    final storedTags = preferences.getStringList(storageKey) ?? const [];
    final tags = <String>[];
    final seen = <String>{};
    for (final value in storedTags) {
      final normalized = InstagramHashtag.normalize(value);
      if (normalized != null && seen.add(normalized)) tags.add(normalized);
    }
    return tags;
  }

  Future<void> save(List<String> values) async {
    final tags = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final tag = _requireTag(value);
      if (seen.add(tag)) tags.add(tag);
    }
    final preferences = await _preferencesProvider();
    final saved = await preferences.setStringList(storageKey, tags);
    if (!saved) throw StateError('Hashtag shelf could not be saved.');
  }

  Future<bool> add(String value) async {
    final tag = _requireTag(value);
    final tags = await load();
    if (tags.contains(tag)) return false;
    tags.add(tag);
    await save(tags);
    return true;
  }

  Future<bool> replace(String existingValue, String replacementValue) async {
    final existing = _requireTag(existingValue);
    final replacement = _requireTag(replacementValue);
    final tags = await load();
    final index = tags.indexOf(existing);
    if (index < 0) return false;
    if (replacement != existing && tags.contains(replacement)) {
      throw FormatException('That hashtag is already saved.');
    }
    tags[index] = replacement;
    await save(tags);
    return true;
  }

  Future<bool> remove(String value) async {
    final tag = _requireTag(value);
    final tags = await load();
    if (!tags.remove(tag)) return false;
    await save(tags);
    return true;
  }

  String _requireTag(String value) {
    final tag = InstagramHashtag.normalize(value);
    if (tag == null) {
      throw FormatException('Enter a valid Instagram hashtag.');
    }
    return tag;
  }
}
