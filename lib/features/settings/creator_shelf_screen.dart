import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_typography.dart';
import '../../core/models/creator_profile.dart';
import 'creator_shelf_repository.dart';

typedef InstagramProfileOpener = Future<bool> Function(String handle);
typedef CreatorProfileBrowserOpener = Future<bool> Function(Uri uri);

class CreatorShelfScreen extends StatefulWidget {
  const CreatorShelfScreen({
    super.key,
    required this.openInstagramProfile,
    this.openInBrowser,
    this.repository,
  });

  final InstagramProfileOpener openInstagramProfile;
  final CreatorProfileBrowserOpener? openInBrowser;
  final CreatorShelfRepository? repository;

  @override
  State<CreatorShelfScreen> createState() => _CreatorShelfScreenState();
}

class _CreatorShelfScreenState extends State<CreatorShelfScreen> {
  late final CreatorShelfRepository _repository =
      widget.repository ?? CreatorShelfRepository();
  List<String> _handles = const [];
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadHandles();
  }

  Future<void> _loadHandles() async {
    try {
      final handles = await _repository.load();
      if (!mounted) return;
      setState(() {
        _handles = handles;
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

  Future<void> _openEditor({String? existingHandle}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CreatorEditorDialog(
        existingHandle: existingHandle,
        onSave: (handle) async {
          final wasSaved = existingHandle == null
              ? await _repository.add(handle)
              : await _repository.replace(existingHandle, handle);
          if (!wasSaved) {
            throw const FormatException('That creator is already saved.');
          }
        },
      ),
    );
    if (saved == true) await _loadHandles();
  }

  Future<void> _removeCreator(String handle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove creator?'),
        content: Text('@$handle will be removed from your shelf.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('creator-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.remove(handle);
      await _loadHandles();
    } catch (_) {
      _showMessage('Couldn’t remove this creator. Try again.');
    }
  }

  Future<void> _openCreator(String handle) async {
    var opened = false;
    try {
      opened = await widget.openInstagramProfile(handle);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) await _showProfileFallback(handle);
  }

  Future<void> _showProfileFallback(String handle) async {
    final profileUri = CreatorProfile.profileUriFor(handle);
    var browserUnavailable = false;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
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
              Text(
                'Instagram couldn’t open this profile',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.x2),
              SelectableText(
                profileUri.toString(),
                key: const ValueKey('creator-profile-link'),
                style: AppTypography.body,
              ),
              if (browserUnavailable) ...[
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'No browser could open this link. You can copy it instead.',
                  style: AppTypography.supporting,
                ),
              ],
              const SizedBox(height: AppSpacing.x3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('creator-open-browser'),
                  onPressed: () async {
                    var opened = false;
                    try {
                      opened = widget.openInBrowser == null
                          ? await launchUrl(
                              profileUri,
                              mode: LaunchMode.inAppBrowserView,
                            )
                          : await widget.openInBrowser!(profileUri);
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
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(text: profileUri.toString()),
                    );
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                      _showMessage('Profile link copied.');
                    }
                  } catch (_) {
                    if (sheetContext.mounted) {
                      setSheetState(() => browserUnavailable = true);
                    }
                  }
                },
                child: const Text('Copy link'),
              ),
            ],
          ),
        ),
      ),
    );
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
        title: Text('Creator shelf', style: AppTypography.pageTitle),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading saved creators',
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
                        'Saved creators are unavailable right now.',
                        style: AppTypography.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      FilledButton(
                        onPressed: () {
                          setState(() => _loading = true);
                          _loadHandles();
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
                    'Save Instagram profiles you want to revisit.',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'Your list stays on this device. Instagram controls what appears after a profile opens.',
                    style: AppTypography.supporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      key: const ValueKey('creator-add-button'),
                      onPressed: () => _openEditor(),
                      icon: const AppIcon(icon: AppIcons.add),
                      label: const Text('Add creator'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  if (_handles.isEmpty)
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
                              icon: AppIcons.creatorGroup,
                              size: AppIconSizes.large,
                            ),
                            const SizedBox(height: AppSpacing.x3),
                            Text(
                              'No creators saved yet.',
                              key: const ValueKey('creator-empty-state'),
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
                          for (var index = 0; index < _handles.length; index++)
                            Column(
                              children: [
                                if (index > 0)
                                  const Divider(height: 1, indent: 72),
                                _creatorTile(_handles[index]),
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

  Widget _creatorTile(String handle) => ListTile(
    key: ValueKey('creator-open-$handle'),
    contentPadding: const EdgeInsetsDirectional.only(
      start: AppSpacing.x4,
      end: AppSpacing.x1,
    ),
    onTap: () => _openCreator(handle),
    leading: Image.asset(
      'assets/supported-app-icons/instagram.png',
      width: 32,
      height: 32,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
    title: Text('@$handle', style: AppTypography.cardTitle),
    subtitle: const Text('Instagram profile'),
    trailing: PopupMenuButton<_CreatorAction>(
      key: ValueKey('creator-options-$handle'),
      tooltip: 'Creator options for @$handle',
      icon: AppIcon(
        icon: AppIcons.more,
        semanticLabel: 'Creator options for @$handle',
      ),
      onSelected: (action) {
        switch (action) {
          case _CreatorAction.edit:
            _openEditor(existingHandle: handle);
          case _CreatorAction.remove:
            _removeCreator(handle);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          key: ValueKey('creator-action-edit'),
          value: _CreatorAction.edit,
          child: Text('Edit'),
        ),
        PopupMenuItem(
          key: ValueKey('creator-action-remove'),
          value: _CreatorAction.remove,
          child: Text('Remove'),
        ),
      ],
    ),
  );
}

enum _CreatorAction { edit, remove }

class _CreatorEditorDialog extends StatefulWidget {
  const _CreatorEditorDialog({required this.onSave, this.existingHandle});

  final String? existingHandle;
  final Future<void> Function(String handle) onSave;

  @override
  State<_CreatorEditorDialog> createState() => _CreatorEditorDialogState();
}

class _CreatorEditorDialogState extends State<_CreatorEditorDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.existingHandle ?? '',
  );
  String? _errorMessage;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final handle = CreatorProfile.normalizeHandle(_controller.text);
    if (handle == null) {
      setState(
        () => _errorMessage = 'Enter a valid Instagram handle or profile link.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSave(handle);
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
          _errorMessage = 'Couldn’t save this creator. Try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existingHandle == null ? 'Add creator' : 'Edit creator',
      style: AppTypography.sectionTitle,
    ),
    content: TextField(
      key: const ValueKey('creator-handle-field'),
      controller: _controller,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Instagram handle or profile link',
        hintText: '@creator',
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
        key: const ValueKey('creator-save-button'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}
