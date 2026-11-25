import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_typography.dart';
import '../../core/models/instagram_hashtag.dart';
import 'hashtag_shelf_repository.dart';

typedef InstagramHashtagOpener = Future<bool> Function(String tag);
typedef InstagramAppOpener = Future<bool> Function();
typedef HashtagBrowserOpener = Future<bool> Function(Uri uri);

class HashtagShelfScreen extends StatefulWidget {
  const HashtagShelfScreen({
    super.key,
    required this.openInstagramHashtag,
    required this.openInstagramApp,
    this.openInBrowser,
    this.repository,
  });

  final InstagramHashtagOpener openInstagramHashtag;
  final InstagramAppOpener openInstagramApp;
  final HashtagBrowserOpener? openInBrowser;
  final HashtagShelfRepository? repository;

  @override
  State<HashtagShelfScreen> createState() => _HashtagShelfScreenState();
}

class _HashtagShelfScreenState extends State<HashtagShelfScreen> {
  late final HashtagShelfRepository _repository =
      widget.repository ?? HashtagShelfRepository();
  List<String> _tags = const [];
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await _repository.load();
      if (!mounted) return;
      setState(() {
        _tags = tags;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _openEditor({String? existingTag}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _HashtagEditorDialog(
        existingTag: existingTag,
        onSave: (tag) async {
          final wasSaved = existingTag == null
              ? await _repository.add(tag)
              : await _repository.replace(existingTag, tag);
          if (!wasSaved) {
            throw const FormatException('That hashtag is already saved.');
          }
        },
      ),
    );
    if (saved == true) await _loadTags();
  }

  Future<void> _removeTag(String tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove hashtag?'),
        content: Text('#$tag will be removed from your shelf.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('hashtag-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.remove(tag);
      await _loadTags();
    } catch (_) {
      _showMessage('Couldn’t remove this hashtag. Try again.');
    }
  }

  Future<void> _openTag(String tag) async {
    var opened = false;
    try {
      opened = await widget.openInstagramHashtag(tag);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) await _showFallback(tag);
  }

  Future<void> _showFallback(String tag) async {
    var instagramUnavailable = false;
    var browserUnavailable = false;
    final searchUri = InstagramHashtag.searchUriFor(tag);

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x2,
              AppSpacing.x4,
              AppSpacing.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Open #$tag manually', style: AppTypography.sectionTitle),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Instagram controls these results and later scrolling.',
                  style: AppTypography.supporting,
                ),
                if (instagramUnavailable) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'Instagram could not be opened.',
                    style: AppTypography.supporting,
                  ),
                ],
                if (browserUnavailable) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'No browser could open this tag link.',
                    style: AppTypography.supporting,
                  ),
                ],
                const SizedBox(height: AppSpacing.x4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('hashtag-manual-search'),
                    onPressed: () async {
                      var opened = false;
                      try {
                        opened = await widget.openInstagramApp();
                      } catch (_) {
                        opened = false;
                      }
                      if (!sheetContext.mounted) return;
                      if (opened) {
                        Navigator.pop(sheetContext);
                        if (mounted) {
                          _showMessage('Search Instagram for #$tag.');
                        }
                      } else {
                        setSheetState(() => instagramUnavailable = true);
                      }
                    },
                    child: const Text('Open Instagram'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const ValueKey('hashtag-open-browser'),
                    onPressed: () async {
                      var opened = false;
                      try {
                        opened = widget.openInBrowser == null
                            ? await launchUrl(
                                searchUri,
                                mode: LaunchMode.inAppBrowserView,
                              )
                            : await widget.openInBrowser!(searchUri);
                      } catch (_) {
                        opened = false;
                      }
                      if (!sheetContext.mounted) return;
                      if (opened) {
                        Navigator.pop(sheetContext);
                      } else {
                        setSheetState(() => browserUnavailable = true);
                      }
                    },
                    child: const Text('Open in browser'),
                  ),
                ),
                TextButton(
                  key: const ValueKey('hashtag-copy-fallback'),
                  onPressed: () async {
                    final copied = await _copyTag(tag);
                    if (!sheetContext.mounted) return;
                    if (copied) Navigator.pop(sheetContext);
                  },
                  child: const Text('Copy hashtag'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _copyTag(String tag) async {
    try {
      await Clipboard.setData(ClipboardData(text: '#$tag'));
      _showMessage('Hashtag copied.');
      return true;
    } catch (_) {
      _showMessage('Couldn’t copy this hashtag. Try again.');
      return false;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const AppIcon(
            icon: AppIcons.back,
            semanticLabel: 'Back',
            size: AppIconSizes.large,
          ),
        ),
        title: Text('Hashtag shelf', style: AppTypography.pageTitle),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading saved hashtags',
                ),
              )
            : _loadFailed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Saved hashtags are unavailable right now.',
                        style: AppTypography.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      FilledButton(
                        onPressed: () {
                          setState(() => _loading = true);
                          _loadTags();
                        },
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x3,
                  AppSpacing.x4,
                  AppSpacing.x8,
                ),
                children: [
                  Text(
                    'Save Instagram hashtags you want to revisit.',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'Your list stays on this device. Instagram controls the results and later scrolling.',
                    style: AppTypography.supporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      key: const ValueKey('hashtag-add-button'),
                      onPressed: () => _openEditor(),
                      icon: const AppIcon(icon: AppIcons.add),
                      label: const Text('Add hashtag'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  if (_tags.isEmpty)
                    Card(
                      color: colors.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.x6),
                        child: Column(
                          children: [
                            const AppIcon(
                              icon: AppIcons.hashtag,
                              size: AppIconSizes.large,
                            ),
                            const SizedBox(height: AppSpacing.x3),
                            Text(
                              'No hashtags saved yet.',
                              key: const ValueKey('hashtag-empty-state'),
                              style: AppTypography.cardTitle,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      color: colors.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: Column(
                        children: [
                          for (var index = 0; index < _tags.length; index++)
                            Column(
                              children: [
                                if (index > 0)
                                  const Divider(height: 1, indent: 72),
                                _hashtagTile(_tags[index]),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _hashtagTile(String tag) => ListTile(
    key: ValueKey('hashtag-open-$tag'),
    contentPadding: const EdgeInsetsDirectional.only(
      start: AppSpacing.x4,
      end: AppSpacing.x1,
    ),
    onTap: () => _openTag(tag),
    leading: const AppIcon(
      icon: AppIcons.hashtag,
      size: AppIconSizes.large,
      semanticLabel: 'Instagram hashtag',
    ),
    title: Text('#$tag', style: AppTypography.cardTitle),
    subtitle: const Text('Instagram tag search'),
    trailing: PopupMenuButton<_HashtagAction>(
      key: ValueKey('hashtag-options-$tag'),
      tooltip: 'Options for #$tag',
      icon: AppIcon(icon: AppIcons.more, semanticLabel: 'Options for #$tag'),
      onSelected: (action) {
        switch (action) {
          case _HashtagAction.copy:
            _copyTag(tag);
          case _HashtagAction.edit:
            _openEditor(existingTag: tag);
          case _HashtagAction.remove:
            _removeTag(tag);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          key: ValueKey('hashtag-action-copy'),
          value: _HashtagAction.copy,
          child: Text('Copy hashtag'),
        ),
        PopupMenuItem(
          key: ValueKey('hashtag-action-edit'),
          value: _HashtagAction.edit,
          child: Text('Edit'),
        ),
        PopupMenuItem(
          key: ValueKey('hashtag-action-remove'),
          value: _HashtagAction.remove,
          child: Text('Remove'),
        ),
      ],
    ),
  );
}

enum _HashtagAction { copy, edit, remove }

class _HashtagEditorDialog extends StatefulWidget {
  const _HashtagEditorDialog({required this.onSave, this.existingTag});

  final String? existingTag;
  final Future<void> Function(String tag) onSave;

  @override
  State<_HashtagEditorDialog> createState() => _HashtagEditorDialogState();
}

class _HashtagEditorDialogState extends State<_HashtagEditorDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.existingTag == null ? '' : '#${widget.existingTag}',
  );
  String? _errorMessage;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tag = InstagramHashtag.normalize(_controller.text);
    if (tag == null) {
      setState(
        () => _errorMessage =
            'Enter a valid Instagram hashtag or tag search link.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSave(tag);
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Couldn’t save this hashtag. Try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existingTag == null ? 'Add hashtag' : 'Edit hashtag',
      style: AppTypography.sectionTitle,
    ),
    content: TextField(
      key: const ValueKey('hashtag-field'),
      controller: _controller,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Instagram hashtag or tag search link',
        hintText: 'photography',
        errorText: _errorMessage,
      ),
      onSubmitted: (_) {
        if (!_saving) _save();
      },
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('hashtag-save-button'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}
