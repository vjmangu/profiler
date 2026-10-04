import 'package:flutter/material.dart';
import 'package:profiler_blocker/profiler_blocker.dart';

import '../models/profile.dart';
import '../state/app_state.dart';
import '../widgets/permission_disclosure.dart';
import 'lock_screen.dart';
import 'pin_setup_screen.dart';
import 'profile_editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  /// Runs [action] only after the parent verifies, when a locked profile is on.
  Future<void> _guarded(
    BuildContext context,
    String reason,
    Future<void> Function() action,
  ) async {
    if (state.needsAuth) {
      final ok = await LockScreen.verify(context, state.auth, reason: reason);
      if (!ok) return;
    }
    await action();
  }

  Future<void> _activate(BuildContext context, Profile p) => _guarded(
        context,
        'Verify to switch to ${p.name}',
        () => state.activate(p.id),
      );

  Future<void> _stop(BuildContext context) => _guarded(
        context,
        'Verify to turn off ${state.effective?.name ?? 'this profile'}',
        state.stop,
      );

  Future<void> _edit(BuildContext context, Profile? p) => _guarded(
        context,
        'Verify to change profile settings',
        () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileEditorScreen(
            state: state,
            profile: p ??
                Profile(
                  id: state.newId(),
                  name: 'New profile',
                  kind: ProfileKind.custom,
                ),
            isNew: p == null,
          ),
        )),
      );

  Future<void> _changePin(BuildContext context) async {
    final ok = await LockScreen.verify(context, state.auth,
        reason: 'Enter your current PIN');
    if (!ok || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => PinSetupScreen(
        isChange: true,
        onDone: (pin) async {
          await state.setPin(pin);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final active = state.effective;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiler'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'pin') _changePin(context);
              if (v == 'perm') requestBlockingPermission(context, state);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pin', child: Text('Change parent PIN')),
              PopupMenuItem(value: 'perm', child: Text('Blocking permission')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New profile'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await state.refreshServiceStatus();
          await state.loadInstalledApps();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (!state.serviceEnabled) _PermissionCard(state: state),
            _ActiveCard(
              state: state,
              active: active,
              onStop: () => _stop(context),
            ),
            const SizedBox(height: 20),
            Text('Profiles', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final p in state.profiles)
              _ProfileTile(
                profile: p,
                isActive: p.id == active?.id,
                blockedCount: state.blockedCount(p),
                onTap: () => _edit(context, p),
                onActivate: () => _activate(context, p),
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final android = ProfilerBlocker.isAndroid;
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Blocking is off',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              android
                  ? 'Turn on “Profiler” under Settings › Accessibility › '
                      'Installed apps. If it’s greyed out, open App info › ⋮ › '
                      'Allow restricted settings first.'
                  : 'Allow Screen Time access so Profiler can block apps.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => requestBlockingPermission(context, state),
              child: Text(android ? 'Open settings' : 'Allow access'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.state,
    required this.active,
    required this.onStop,
  });

  final AppState state;
  final Profile? active;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = active;
    if (p == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Icon(Icons.lock_open_rounded, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No profile on', style: t.titleLarge),
                  const Text('All apps are available. Tap a profile to start.'),
                ],
              ),
            ),
          ]),
        ),
      );
    }
    final color = p.kind.color;
    final scheduled = state.effectiveReason == ActiveReason.schedule;
    final sub = scheduled
        ? 'On by schedule until '
            '${ProfileSchedule.formatMinute(p.schedule.endMinute)}'
        : 'Turned on manually';
    return Card(
      color: color.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color,
                child: Icon(p.kind.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.name} is on', style: t.titleLarge),
                    Text(sub),
                  ],
                ),
              ),
              if (p.requireAuthToExit) const Icon(Icons.lock_rounded),
            ]),
            const SizedBox(height: 12),
            Text('${state.blockedCount(p)} apps blocked'
                '${p.tamperProtection ? ' · tamper protection on' : ''}'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(scheduled ? 'Pause until schedule ends' : 'Turn off'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.blockedCount,
    required this.onTap,
    required this.onActivate,
  });

  final Profile profile;
  final bool isActive;
  final int blockedCount;
  final VoidCallback onTap;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final lines = <String>[
      p.kind.tagline,
      '$blockedCount apps blocked',
      if (p.scheduleEnabled) p.schedule.describe(),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: p.kind.color,
          child: Icon(p.kind.icon, color: Colors.white),
        ),
        title: Row(children: [
          Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
          if (p.requireAuthToExit) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock_rounded, size: 16),
          ],
        ]),
        subtitle: Text(lines.join('\n')),
        isThreeLine: true,
        trailing: isActive
            ? const Chip(label: Text('On'))
            : FilledButton.tonal(
                onPressed: onActivate,
                child: const Text('Start'),
              ),
      ),
    );
  }
}
