import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rooko/features/settings/creator_shelf_repository.dart';
import 'package:rooko/features/settings/hashtag_shelf_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores normalized tags in a separate ordered preference', () async {
    SharedPreferences.setMockInitialValues({
      CreatorShelfRepository.storageKey: ['mkbhd'],
    });
    final repository = HashtagShelfRepository();

    await repository.save([
      '#Photography',
      'हिंदी_किताबें',
      'https://www.instagram.com/explore/tags/Coding/',
    ]);

    expect(await repository.load(), [
      'photography',
      'हिंदी_किताबें',
      'coding',
    ]);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList(HashtagShelfRepository.storageKey), [
      'photography',
      'हिंदी_किताबें',
      'coding',
    ]);
    expect(
      preferences.getStringList(CreatorShelfRepository.storageKey),
      ['mkbhd'],
    );
  });

  test('does not add case-insensitive duplicates', () async {
    final repository = HashtagShelfRepository();

    expect(await repository.add('#Hindi'), isTrue);
    expect(await repository.add('हिंदी'), isTrue);
    expect(await repository.add('#HINDI'), isFalse);
    expect(await repository.load(), ['hindi', 'हिंदी']);
  });

  test('edits and removes tags without changing other order', () async {
    final repository = HashtagShelfRepository();
    await repository.save(['first', 'middle', 'last']);

    await repository.replace('middle', '#renamed_tag');
    await repository.remove('first');

    expect(await repository.load(), ['renamed_tag', 'last']);
  });

  test('rejects invalid tags and duplicate replacements', () async {
    final repository = HashtagShelfRepository();
    await repository.save(['first', 'second']);

    expect(() => repository.add('two words'), throwsFormatException);
    expect(() => repository.replace('first', '#second'), throwsFormatException);
    expect(await repository.load(), ['first', 'second']);
  });
}
