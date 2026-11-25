import 'package:flutter_test/flutter_test.dart';
import 'package:rooko/core/models/creator_profile.dart';

void main() {
  group('CreatorProfile.normalizeHandle', () {
    test('normalizes a plain handle and a leading at sign', () {
      expect(CreatorProfile.normalizeHandle('  @Jane.Doe_01  '), 'jane.doe_01');
      expect(CreatorProfile.normalizeHandle('Jane.Doe_01'), 'jane.doe_01');
    });

    test('extracts a handle from supported Instagram profile links', () {
      expect(
        CreatorProfile.normalizeHandle(
          'https://www.instagram.com/Some.Creator/?igsh=example',
        ),
        'some.creator',
      );
      expect(
        CreatorProfile.normalizeHandle('instagram.com/another_creator/'),
        'another_creator',
      );
    });

    test(
      'rejects deceptive hosts, non-web schemes, and non-profile routes',
      () {
        for (final value in [
          'https://instagram.com.attacker.example/user',
          'https://instagram.com@attacker.example/user',
          'javascript:alert(1)',
          'https://www.instagram.com/explore/',
          'https://www.instagram.com/reel/ABC123/',
          'name/extra',
        ]) {
          expect(CreatorProfile.normalizeHandle(value), isNull, reason: value);
        }
      },
    );

    test(
      'rejects handles outside Instagram username characters and length',
      () {
        for (final value in [
          '@two words',
          '@bad-name',
          '@name!',
          '@two..dots',
          'abcdefghijklmnopqrstuvwxyz12345',
        ]) {
          expect(CreatorProfile.normalizeHandle(value), isNull, reason: value);
        }
      },
    );

    test('builds a fixed HTTPS profile link from a normalized handle', () {
      expect(
        CreatorProfile.profileUriFor('jane.doe'),
        Uri.parse('https://www.instagram.com/jane.doe/'),
      );
    });
  });
}
