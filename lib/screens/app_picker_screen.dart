import 'package:flutter/material.dart';
import 'package:profiler_blocker/profiler_blocker.dart';

import '../data/app_groups.dart';
import '../models/profile.dart';
import '../state/app_state.dart';

/// Android: choose which installed apps a profile blocks.
/// Pops with the selected package set when saved.
class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({
    super.key,
    required this.state,
    required this.kind,
    required this.initial,
  });

  final AppState state;
  final ProfileKind kind;
  final Set<String> initial;

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  late final Set<String> _selected = {...widget.initial};
  String _query = '';
  AppGroup? _filter;
  bool _onlySelected = false;

  List<InstalledApp> get _apps => widget.state.installedApps;

  void _addGroup(AppGroup g) {
    final pkgs = suggestPackages({g}, _apps);
    setState(() {
      final allIn = pkgs.every(_selected.contains);
      if (allIn) {
        _selected.removeAll(pkgs);
      } else {
        _selected.addAll(pkgs);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggested = defaultGroupsFor(widget.kind);
    final q = _query.toLowerCase();
    final visible = _apps.where((a) {
      if (_onlySelected && !_selected.contains(a.packageName)) return false;
      if (_filter != null && !groupsOf(a).contains(_filter)) return false;
      if (q.isEmpty) return true;
      return a.label.toLowerCase().contains(q) ||
          a.packageName.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${_selected.length} selected'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: const Text('Done'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          if (widget.state.appsLoading && _apps.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search apps',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (suggested.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  const Text('Quick add: '),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final g in suggested)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: Text(g.label),
                              onPressed: () => _addGroup(g),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('Selected'),
                      selected: _onlySelected,
                      onSelected: (v) => setState(() => _onlySelected = v),
                    ),
                  ),
                  for (final g in AppGroup.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(g.label),
                        selected: _filter == g,
                        onSelected: (v) =>
                            setState(() => _filter = v ? g : null),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('No apps match'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final a = visible[i];
                        final on = _selected.contains(a.packageName);
                        final groups = groupsOf(a);
                        return CheckboxListTile(
                          value: on,
                          onChanged: (v) => setState(() => v == true
                              ? _selected.add(a.packageName)
                              : _selected.remove(a.packageName)),
                          secondary: a.icon == null
                              ? const CircleAvatar(child: Icon(Icons.android))
                              : Image.memory(a.icon!,
                                  width: 40, height: 40, gaplessPlayback: true),
                          title: Text(a.label),
                          subtitle: Text(
                            groups.isEmpty
                                ? a.packageName
                                : groups.map((g) => g.label).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
