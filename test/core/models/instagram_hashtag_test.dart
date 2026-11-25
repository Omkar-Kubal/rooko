import 'package:flutter_test/flutter_test.dart';
import 'package:rooko/core/models/instagram_hashtag.dart';

void main() {
  group('InstagramHashtag.normalize', () {
    test('accepts plain tags, one hash, and Unicode scripts', () {
      expect(InstagramHashtag.normalize('  Photography  '), 'photography');
      expect(InstagramHashtag.normalize('#MKBHD'), 'mkbhd');
      expect(InstagramHashtag.normalize('#हिंदी_किताबें'), 'हिंदी_किताबें');
      expect(InstagramHashtag.normalize('100DaysOfCode'), '100daysofcode');
    });

    test('extracts a tag from an exact Instagram tag search URL', () {
      expect(
        InstagramHashtag.normalize(
          'https://www.instagram.com/explore/tags/किताबें/',
        ),
        'किताबें',
      );
      expect(
        InstagramHashtag.normalize(
          'https://instagram.com/explore/tags/photography/',
        ),
        'photography',
      );
    });

    test('rejects deceptive URLs and non-tag routes', () {
      for (final value in [
        'https://instagram.com.evil.example/explore/tags/photography/',
        'https://instagram.com@evil.example/explore/tags/photography/',
        'javascript:alert(1)',
        'https://www.instagram.com/explore/tags/',
        'https://www.instagram.com/explore/tags/one/two/',
        'https://www.instagram.com/explore/tags/photography',
        'https://www.instagram.com/explore/tags/photography/?x=1',
      ]) {
        expect(InstagramHashtag.normalize(value), isNull, reason: value);
      }
    });

    test('rejects spaces, unsupported punctuation, and more than 100 code points', () {
      for (final value in [
        '#two words',
        '#bad-name',
        '#name!',
        '#\\name',
        'a' * 101,
      ]) {
        expect(InstagramHashtag.normalize(value), isNull, reason: value);
      }
      expect(InstagramHashtag.normalize('a' * 100), 'a' * 100);
    });
  });

  test('builds an encoded HTTPS tag search link', () {
    final uri = InstagramHashtag.searchUriFor('हिंदी_किताबें');

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.instagram.com');
    expect(uri.pathSegments, ['explore', 'tags', 'हिंदी_किताबें', '']);
    expect(uri.toString(), contains('%E0%A4'));
  });
}
