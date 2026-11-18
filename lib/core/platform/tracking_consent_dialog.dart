import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';

Future<bool> showTrackingConsentDisclosure(BuildContext context) async {
  var acknowledged = false;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Tracking access'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rooko uses Accessibility signals to recognize '
                    'short-form feeds in the apps you select and count '
                    'when an item changes. On Instagram and YouTube, it may '
                    'briefly read short visible labels and hash them in '
                    'memory to estimate item changes. It also measures '
                    'approximate observed time while a recognized selected '
                    'feed is in the foreground, using only app identity and '
                    'feed-marker IDs for time checks. Brief changes between '
                    'checks may be missed, and this does not establish '
                    'playback or attention. It does not save labels, messages, '
                    'images, audio, or video. Count and time totals stay on '
                    'this device. Overlay access is not needed for time '
                    'measurement. You can turn access off in Android Settings.',
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: acknowledged,
                    onChanged: (value) =>
                        setDialogState(() => acknowledged = value ?? false),
                    title: const Text(
                      'I understand how this access will be used.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: acknowledged
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ) ??
      false;
}
