import 'package:flutter/material.dart';
import 'package:profiler_blocker/profiler_blocker.dart';

import '../models/profile.dart';
import '../state/app_state.dart';
import 'app_picker_screen.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({
    super.key,
    required this.state,
    required this.profile,
    this.isNew = false,
  });

  final AppState state;
  final Profile profile;
  final bool isNew;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late Profile _p = widget.profile;
  late final _name = TextEditingController(text: widget.profile.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickApps() async {
    if (ProfilerBlocker.isIOS) {
      try {
        final count = await ProfilerBlocker.pickApps(_p.id);
        if (count != null) setState(() => _p = _p.copyWith(iosSelectionCount: count));
      } catch (e) {
        _snack('Screen Time access is needed first.');
      }
      return;
    }
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(
          state: widget.state,
          kind: _p.kind,
          initial: _p.blockedPackages,
        ),
      ),
    );
    if (result != null) setState(() => _p = _p.copyWith(blockedPackages: result));
  }

  Future<void> _pickTime(bool start) async {
    final m = start ? _p.schedule.startMinute : _p.schedule.endMinute;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (t == null) return;
    final v = t.hour * 60 + t.minute;
    setState(() => _p = _p.copyWith(
          schedule: start
              ? _p.schedule.copyWith(startMinute: v)
              : _p.schedule.copyWith(endMinute: v),
        ));
  }

  void _toggleDay(int d) {
    final days = {..._p.schedule.days};
    if (!days.remove(d)) days.add(d);
    setState(() => _p = _p.copyWith(schedule: _p.schedule.copyWith(days: days)));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Give the profile a name');
      return;
    }
    if (_p.scheduleEnabled && _p.schedule.days.isEmpty) {
      _snack('Pick at least one day for the schedule');
      return;
    }
    if (_p.scheduleEnabled &&
        _p.schedule.startMinute == _p.schedule.endMinute) {
      _snack('Start and end time can’t be the same');
      return;
    }
    await widget.state.upsert(_p.copyWith(name: name));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete “${_p.name}”?'),
        content: const Text('Its blocked-app list and schedule will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.state.delete(_p.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ios = ProfilerBlocker.isIOS;
    final count = ios ? _p.iosSelectionCount : _p.blockedPackages.length;
    final s = _p.schedule;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New profile' : 'Edit ${widget.profile.name}'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _p.kind.color,
              child: Icon(_p.kind.icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Profile name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Text('What to block', style: t.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: Text(ios ? 'Choose apps & categories' : 'Blocked apps'),
              subtitle: Text(count == 0
                  ? 'Nothing selected yet'
                  : '$count ${ios ? 'items' : 'apps'} selected'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickApps,
            ),
          ),
          const SizedBox(height: 24),
          Text('Schedule', style: t.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.schedule_rounded),
                title: const Text('Turn on automatically'),
                subtitle: Text(_p.scheduleEnabled
                    ? s.describe()
                    : 'Only when you start it manually'),
                value: _p.scheduleEnabled,
                onChanged: (v) =>
                    setState(() => _p = _p.copyWith(scheduleEnabled: v)),
              ),
              if (_p.scheduleEnabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(ProfileSchedule.dayLetter(d)),
                          selected: s.days.contains(d),
                          showCheckmark: false,
                          onSelected: (_) => _toggleDay(d),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Starts'),
                  trailing: Text(ProfileSchedule.formatMinute(s.startMinute),
                      style: t.titleMedium),
                  onTap: () => _pickTime(true),
                ),
                ListTile(
                  title: const Text('Ends'),
                  subtitle: s.overnight ? const Text('Next day') : null,
                  trailing: Text(ProfileSchedule.formatMinute(s.endMinute),
                      style: t.titleMedium),
                  onTap: () => _pickTime(false),
                ),
                if (ios)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'iOS requires windows of at least 15 minutes.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ]),
          ),
          const SizedBox(height: 24),
          Text('Protection', style: t.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.lock_rounded),
                title: const Text('Require PIN / biometrics to exit'),
                subtitle: const Text(
                    'Also needed to edit profiles while this one is on'),
                value: _p.requireAuthToExit,
                onChanged: (v) =>
                    setState(() => _p = _p.copyWith(requireAuthToExit: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.shield_rounded),
                title: const Text('Tamper protection'),
                subtitle: Text(ios
                    ? 'Prevents deleting apps while on'
                    : 'Also blocks Settings, Play Store and uninstalling '
                        'while on'),
                value: _p.tamperProtection,
                onChanged: (v) =>
                    setState(() => _p = _p.copyWith(tamperProtection: v)),
              ),
            ]),
          ),
          if (!widget.isNew) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete profile'),
            ),
          ],
        ],
      ),
    );
  }
}
