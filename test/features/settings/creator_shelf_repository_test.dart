import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rooko/features/settings/creator_shelf_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores only normalized handles and preserves list order', () async {
    final repository = CreatorShelfRepository();

    await repository.save(['@Zed', 'https://instagram.com/Ada/?source=copy']);

    expect(await repository.load(), ['zed', 'ada']);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList(CreatorShelfRepository.storageKey), [
      'zed',
      'ada',
    ]);
  });

  test('does not add duplicate handles after normalization', () async {
    final repository = CreatorShelfRepository();

    expect(await repository.add('@Jane'), isTrue);
    expect(await repository.add('@JANE'), isFalse);
    expect(await repository.load(), ['jane']);
    expect(await repository.add('@alex'), isTrue);
    expect(await repository.load(), ['jane', 'alex']);
  });

  test(
    'replaces and removes handles without reordering other entries',
    () async {
      final repository = CreatorShelfRepository();
      await repository.save(['first', 'middle', 'last']);

      await repository.replace('middle', '@renamed.creator');
      await repository.remove('first');

      expect(await repository.load(), ['renamed.creator', 'last']);
    },
  );

  test('rejects invalid values and duplicate replacements', () async {
    final repository = CreatorShelfRepository();
    await repository.save(['first', 'second']);

    expect(() => repository.add('not a handle'), throwsFormatException);
    expect(() => repository.replace('first', 'second'), throwsFormatException);
    expect(await repository.load(), ['first', 'second']);
  });
}
