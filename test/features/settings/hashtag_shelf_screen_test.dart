import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rooko/core/design_system/app_theme.dart';
import 'package:rooko/features/settings/hashtag_shelf_repository.dart';
import 'package:rooko/features/settings/hashtag_shelf_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('adds a normalized Unicode tag and stores it locally', (
    tester,
  ) async {
    await _pumpShelf(tester);

    expect(find.text('No hashtags saved yet.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hashtag-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hashtag-field')),
      '#हिंदी_किताबें',
    );
    await tester.tap(find.byKey(const ValueKey('hashtag-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('#हिंदी_किताबें'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList(HashtagShelfRepository.storageKey), [
      'हिंदी_किताबें',
    ]);
  });

  testWidgets('rejects a deceptive tag link and keeps the editor open', (
    tester,
  ) async {
    await _pumpShelf(tester);
    await tester.tap(find.byKey(const ValueKey('hashtag-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hashtag-field')),
      'https://instagram.com.evil.example/explore/tags/photography/',
    );
    await tester.tap(find.byKey(const ValueKey('hashtag-save-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid Instagram hashtag or tag search link.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('rejects a duplicate after normalization', (tester) async {
    SharedPreferences.setMockInitialValues({
      HashtagShelfRepository.storageKey: ['photography'],
    });
    await _pumpShelf(tester);
    await tester.tap(find.byKey(const ValueKey('hashtag-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hashtag-field')),
      '#PHOTOGRAPHY',
    );
    await tester.tap(find.byKey(const ValueKey('hashtag-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('That hashtag is already saved.'), findsOneWidget);
    expect(find.text('#photography'), findsOneWidget);
  });

  testWidgets('edits and removes a saved hashtag in place', (tester) async {
    SharedPreferences.setMockInitialValues({
      HashtagShelfRepository.storageKey: ['one', 'two', 'three'],
    });
    await _pumpShelf(tester);

    await tester.tap(find.byKey(const ValueKey('hashtag-options-two')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hashtag-field')),
      '#renamed_tag',
    );
    await tester.tap(find.byKey(const ValueKey('hashtag-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('#renamed_tag'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList(HashtagShelfRepository.storageKey), [
      'one',
      'renamed_tag',
      'three',
    ]);

    await tester.tap(find.byKey(const ValueKey('hashtag-options-renamed_tag')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hashtag-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('#renamed_tag'), findsNothing);
    expect(find.text('#one'), findsOneWidget);
    expect(find.text('#three'), findsOneWidget);
  });

  testWidgets('opens a saved hashtag in Instagram', (tester) async {
    String? openedTag;
    SharedPreferences.setMockInitialValues({
      HashtagShelfRepository.storageKey: ['photography'],
    });
    await _pumpShelf(
      tester,
      openInstagramHashtag: (tag) async {
        openedTag = tag;
        return true;
      },
    );

    await tester.tap(find.byKey(const ValueKey('hashtag-open-photography')));
    await tester.pumpAndSettle();

    expect(openedTag, 'photography');
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('offers manual search, browser, and copy after handoff failure', (
    tester,
  ) async {
    var manualSearchOpened = false;
    Uri? browserUri;
    SharedPreferences.setMockInitialValues({
      HashtagShelfRepository.storageKey: ['photography'],
    });
    await _pumpShelf(
      tester,
      openInstagramHashtag: (_) async => false,
      openInstagramApp: () async {
        manualSearchOpened = true;
        return true;
      },
      openInBrowser: (uri) async {
        browserUri = uri;
        return true;
      },
    );

    await tester.tap(find.byKey(const ValueKey('hashtag-open-photography')));
    await tester.pumpAndSettle();
    expect(find.text('#photography'), findsOneWidget);
    expect(
      find.text('Instagram controls these results and later scrolling.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('hashtag-manual-search')));
    await tester.pumpAndSettle();
    expect(manualSearchOpened, isTrue);

    await tester.tap(find.byKey(const ValueKey('hashtag-open-photography')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hashtag-open-browser')));
    await tester.pumpAndSettle();
    expect(
      browserUri,
      Uri.parse('https://www.instagram.com/explore/tags/photography/'),
    );
  });

  testWidgets('explains when manual search and browser both fail', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      HashtagShelfRepository.storageKey: ['photography'],
    });
    await _pumpShelf(
      tester,
      openInstagramHashtag: (_) async => false,
      openInstagramApp: () async => false,
      openInBrowser: (_) async => false,
    );

    await tester.tap(find.byKey(const ValueKey('hashtag-open-photography')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hashtag-manual-search')));
    await tester.pumpAndSettle();
    expect(find.text('Instagram could not be opened.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hashtag-open-browser')));
    await tester.pumpAndSettle();
    expect(find.text('No browser could open this tag link.'), findsOneWidget);
    expect(find.text('Copy hashtag'), findsOneWidget);
  });

  testWidgets('copies a hashtag from the row menu', (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    SharedPreferences.setMockInitialValues({
      HashtagShelfRepository.storageKey: ['photography'],
    });
    await _pumpShelf(tester);

    await tester.tap(find.byKey(const ValueKey('hashtag-options-photography')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy hashtag'));
    await tester.pumpAndSettle();

    expect(copiedText, '#photography');
    expect(find.text('Hashtag copied.'), findsOneWidget);
  });

  testWidgets('fallback remains usable at 200% text in each theme', (
    tester,
  ) async {
    for (final theme in [AppTheme.light, AppTheme.dark, AppTheme.amoledBlack]) {
      SharedPreferences.setMockInitialValues({
        HashtagShelfRepository.storageKey: ['photography'],
      });
      await _pumpShelf(
        tester,
        theme: theme,
        textScaler: TextScaler.linear(2),
        openInstagramHashtag: (_) async => false,
        openInstagramApp: () async => false,
      );

      await tester.tap(find.byKey(const ValueKey('hashtag-open-photography')));
      await tester.pumpAndSettle();
      final manualSearch = find.byKey(const ValueKey('hashtag-manual-search'));
      expect(manualSearch, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(manualSearch);
      await tester.tap(manualSearch);
      await tester.pumpAndSettle();
      expect(find.text('Instagram could not be opened.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

Future<void> _pumpShelf(
  WidgetTester tester, {
  Future<bool> Function(String tag)? openInstagramHashtag,
  Future<bool> Function()? openInstagramApp,
  Future<bool> Function(Uri uri)? openInBrowser,
  HashtagShelfRepository? repository,
  ThemeData? theme,
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      builder: (context, child) => textScaler == null
          ? child!
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: HashtagShelfScreen(
        openInstagramHashtag: openInstagramHashtag ?? (_) async => true,
        openInstagramApp: openInstagramApp ?? () async => true,
        openInBrowser: openInBrowser,
        repository: repository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
