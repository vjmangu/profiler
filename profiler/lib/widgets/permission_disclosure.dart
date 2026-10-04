import 'package:flutter/material.dart';
import 'package:profiler_blocker/profiler_blocker.dart';

import '../state/app_state.dart';

/// Google Play requires a prominent, in-app disclosure with an affirmative
/// consent tap before sending users to enable an AccessibilityService that
/// isn't an accessibility tool. Always go through this, never straight to
/// settings.
Future<void> requestBlockingPermission(
  BuildContext context,
  AppState state,
) async {
  if (ProfilerBlocker.isAndroid) {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.accessibility_new_rounded),
        title: const Text('Profiler uses the Accessibility service'),
        content: const SingleChildScrollView(
          child: Text(
            'To block apps, Profiler uses Android’s Accessibility service to '
            'see which app is opening on screen.\n\n'
            '• What it reads: only the name (package) of the app in the '
            'foreground. It does not read screen content, typing, messages '
            'or passwords.\n'
            '• How it’s used: if that app is blocked by the active profile, '
            'Profiler sends you to the home screen and shows a “blocked” '
            'notice.\n'
            '• Sharing: nothing leaves your phone. Profiler has no servers, '
            'accounts, ads or analytics.\n\n'
            'You can turn this off any time in Settings › Accessibility.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No thanks'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Agree & continue'),
          ),
        ],
      ),
    );
    if (agreed != true) return;
  }
  await ProfilerBlocker.requestPermission();
  await state.refreshServiceStatus();
}
