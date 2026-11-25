import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/creator_profile.dart';

/// Persists normalized creator handles in the Android app's private settings.
class CreatorShelfRepository {
  CreatorShelfRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static const storageKey = 'rooko_creator_shelf_handles';

  final Future<SharedPreferences> Function() _preferencesProvider;

  Future<List<String>> load() async {
    final preferences = await _preferencesProvider();
    final storedHandles = preferences.getStringList(storageKey) ?? const [];
    final handles = <String>[];
    final seen = <String>{};
    for (final value in storedHandles) {
      final normalized = CreatorProfile.normalizeHandle(value);
      if (normalized != null && seen.add(normalized)) handles.add(normalized);
    }
    return handles;
  }

  Future<void> save(List<String> handles) async {
    final normalized = <String>[];
    final seen = <String>{};
    for (final value in handles) {
      final handle = CreatorProfile.normalizeHandle(value);
      if (handle == null) {
        throw FormatException(
          'Enter a valid Instagram handle or profile link.',
        );
      }
      if (seen.add(handle)) normalized.add(handle);
    }
    final preferences = await _preferencesProvider();
    final saved = await preferences.setStringList(storageKey, normalized);
    if (!saved) throw StateError('Creator shelf could not be saved.');
  }

  Future<bool> add(String value) async {
    final handle = _requireHandle(value);
    final handles = await load();
    if (handles.contains(handle)) return false;
    handles.add(handle);
    await save(handles);
    return true;
  }

  Future<bool> replace(String existingValue, String replacementValue) async {
    final existing = _requireHandle(existingValue);
    final replacement = _requireHandle(replacementValue);
    final handles = await load();
    final index = handles.indexOf(existing);
    if (index < 0) return false;
    if (replacement != existing && handles.contains(replacement)) {
      throw FormatException('That creator is already saved.');
    }
    handles[index] = replacement;
    await save(handles);
    return true;
  }

  Future<bool> remove(String value) async {
    final handle = _requireHandle(value);
    final handles = await load();
    if (!handles.remove(handle)) return false;
    await save(handles);
    return true;
  }

  String _requireHandle(String value) {
    final handle = CreatorProfile.normalizeHandle(value);
    if (handle == null) {
      throw FormatException('Enter a valid Instagram handle or profile link.');
    }
    return handle;
  }
}
