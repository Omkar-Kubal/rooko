import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rooko/core/design_system/app_theme.dart';
import 'package:rooko/features/settings/creator_shelf_repository.dart';
import 'package:rooko/features/settings/creator_shelf_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('adds a normalized handle to the empty shelf and persists it', (
    tester,
  ) async {
    await _pumpShelf(tester);

    expect(find.text('No creators saved yet.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('creator-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('creator-handle-field')),
      '@Jane.Doe',
    );
    await tester.tap(find.byKey(const ValueKey('creator-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('@jane.doe'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList(CreatorShelfRepository.storageKey), [
      'jane.doe',
    ]);
  });

  testWidgets(
    'shows an error for an invalid handle and leaves the editor open',
    (tester) async {
      await _pumpShelf(tester);
      await tester.tap(find.byKey(const ValueKey('creator-add-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('creator-handle-field')),
        'https://instagram.com.evil.example/person',
      );
      await tester.tap(find.byKey(const ValueKey('creator-save-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a valid Instagram handle or profile link.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

  testWidgets('rejects a case-insensitive duplicate handle', (tester) async {
    SharedPreferences.setMockInitialValues({
      CreatorShelfRepository.storageKey: ['creator'],
    });
    await _pumpShelf(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('creator-handle-field')),
      '@CREATOR',
    );
    await tester.tap(find.byKey(const ValueKey('creator-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('That creator is already saved.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('creator-open-creator')),
        matching: find.text('@creator'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('edits a saved creator and removes it after confirmation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      CreatorShelfRepository.storageKey: ['before'],
    });
    await _pumpShelf(tester);
    await tester.tap(find.byKey(const ValueKey('creator-options-before')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('creator-handle-field')),
      'after',
    );
    await tester.tap(find.byKey(const ValueKey('creator-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('@after'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('creator-options-after')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('No creators saved yet.'), findsOneWidget);
  });

  testWidgets('opens the saved handle and offers browser fallback on failure', (
    tester,
  ) async {
    String? openedHandle;
    Uri? browserUri;
    SharedPreferences.setMockInitialValues({
      CreatorShelfRepository.storageKey: ['creator'],
    });
    await _pumpShelf(
      tester,
      openInstagramProfile: (handle) async {
        openedHandle = handle;
        return false;
      },
      openInBrowser: (uri) async {
        browserUri = uri;
        return true;
      },
    );
    await tester.tap(find.byKey(const ValueKey('creator-open-creator')));
    await tester.pumpAndSettle();

    expect(openedHandle, 'creator');
    expect(find.text('https://www.instagram.com/creator/'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('creator-open-browser')));
    await tester.pumpAndSettle();
    expect(browserUri, Uri.parse('https://www.instagram.com/creator/'));
  });

  testWidgets('shows the link and copy option when no browser can open it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      CreatorShelfRepository.storageKey: ['creator'],
    });
    await _pumpShelf(
      tester,
      openInstagramProfile: (_) async => false,
      openInBrowser: (_) async => false,
    );
    await tester.tap(find.byKey(const ValueKey('creator-open-creator')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-open-browser')));
    await tester.pumpAndSettle();

    expect(find.text('https://www.instagram.com/creator/'), findsOneWidget);
    expect(
      find.text('No browser could open this link. You can copy it instead.'),
      findsOneWidget,
    );
    expect(find.text('Copy link'), findsOneWidget);
  });
}

Future<void> _pumpShelf(
  WidgetTester tester, {
  Future<bool> Function(String handle)? openInstagramProfile,
  Future<bool> Function(Uri uri)? openInBrowser,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: CreatorShelfScreen(
        openInstagramProfile: openInstagramProfile ?? (_) async => true,
        openInBrowser: openInBrowser,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
