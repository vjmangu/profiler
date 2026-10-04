import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:profiler_blocker/profiler_blocker.dart';

import '../data/app_groups.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/profile_store.dart';

enum ActiveReason { manual, schedule }

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({ProfileStore? store, AuthService? auth})
      : store = store ?? ProfileStore(),
        auth = auth ?? AuthService();

  final ProfileStore store;
  final AuthService auth;

  bool loading = true;
  bool hasPin = false;
  bool serviceEnabled = false;
  List<Profile> profiles = [];
  String? manualActiveId;
  String? snoozedId;
  DateTime? snoozeUntil;
  bool _seeded = false;

  List<InstalledApp> installedApps = const [];
  bool appsLoading = false;

  Timer? _ticker;
  String? _lastEffectiveId;

  // ---------------------------------------------------------------- lifecycle

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    hasPin = await auth.hasPin();
    final s = await store.load();
    if (s == null || s.profiles.isEmpty) {
      profiles = _builtIns();
    } else {
      profiles = s.profiles;
      manualActiveId = s.manualActiveId;
      snoozedId = s.snoozedId;
      snoozeUntil = s.snoozeUntil;
      _seeded = s.seededSuggestions;
    }
    await refreshServiceStatus();
    loading = false;
    notifyListeners();

    unawaited(loadInstalledApps());
    _lastEffectiveId = effective?.id;
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) => _tick());
    await _persistAndSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshServiceStatus();
      _tick();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _tick() {
    final id = effective?.id;
    if (id != _lastEffectiveId) {
      _lastEffectiveId = id;
      _persistAndSync();
    }
    notifyListeners();
  }

  List<Profile> _builtIns() => [
        const Profile(
          id: 'kid',
          name: 'Kid',
          kind: ProfileKind.kid,
          requireAuthToExit: true,
          tamperProtection: true,
        ),
        const Profile(id: 'focus', name: 'Focus', kind: ProfileKind.focus),
        const Profile(
          id: 'work',
          name: 'Work',
          kind: ProfileKind.work,
          scheduleEnabled: true,
          schedule: ProfileSchedule.workDefault,
        ),
      ];

  Future<void> loadInstalledApps() async {
    if (!ProfilerBlocker.isAndroid) return;
    appsLoading = true;
    notifyListeners();
    try {
      installedApps = await ProfilerBlocker.getInstalledApps();
      // First run: pre-fill each built-in profile with sensible suggestions.
      if (!_seeded && installedApps.isNotEmpty) {
        profiles = [
          for (final p in profiles)
            p.blockedPackages.isEmpty
                ? p.copyWith(
                    blockedPackages: suggestPackages(
                        defaultGroupsFor(p.kind), installedApps))
                : p,
        ];
        _seeded = true;
        await _persistAndSync();
      }
    } catch (e) {
      debugPrint('getInstalledApps failed: $e');
    } finally {
      appsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshServiceStatus() async {
    try {
      serviceEnabled = await ProfilerBlocker.isServiceEnabled();
    } catch (_) {
      serviceEnabled = false;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ active state

  Profile? byId(String? id) {
    if (id == null) return null;
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool _isSnoozed(Profile p, DateTime now) =>
      p.id == snoozedId && snoozeUntil != null && now.isBefore(snoozeUntil!);

  /// The profile being enforced right now: a manually started one wins,
  /// otherwise the first profile whose schedule covers this moment.
  Profile? effectiveAt(DateTime now) {
    final manual = byId(manualActiveId);
    if (manual != null) return manual;
    for (final p in profiles) {
      if (p.scheduleEnabled &&
          p.schedule.isActiveAt(now) &&
          !_isSnoozed(p, now)) {
        return p;
      }
    }
    return null;
  }

  Profile? get effective => effectiveAt(DateTime.now());

  ActiveReason? get effectiveReason {
    final e = effective;
    if (e == null) return null;
    return e.id == manualActiveId ? ActiveReason.manual : ActiveReason.schedule;
  }

  /// Leaving the current state (or changing settings) needs the parent?
  bool get needsAuth => effective?.requireAuthToExit ?? false;

  int blockedCount(Profile p) => ProfilerBlocker.isIOS
      ? p.iosSelectionCount
      : p.blockedPackages.length;

  // ------------------------------------------------------------- mutations

  Future<void> activate(String id) async {
    manualActiveId = id;
    await _persistAndSync();
  }

  /// Stops whatever is active. A scheduled profile is snoozed until its
  /// current window ends, then resumes automatically next time.
  Future<void> stop() async {
    final e = effective;
    if (e == null) return;
    if (e.id == manualActiveId) {
      manualActiveId = null;
    } else {
      snoozedId = e.id;
      snoozeUntil = e.schedule.windowEndAfter(DateTime.now());
    }
    await _persistAndSync();
  }

  Future<void> upsert(Profile p) async {
    final i = profiles.indexWhere((x) => x.id == p.id);
    if (i == -1) {
      profiles = [...profiles, p];
    } else {
      profiles = [...profiles]..[i] = p;
    }
    await _persistAndSync();
  }

  Future<void> delete(String id) async {
    profiles = profiles.where((p) => p.id != id).toList();
    if (manualActiveId == id) manualActiveId = null;
    if (snoozedId == id) snoozedId = null;
    if (ProfilerBlocker.isIOS) {
      try {
        await ProfilerBlocker.clearProfile(id);
      } catch (_) {}
    }
    await _persistAndSync();
  }

  Future<void> setPin(String pin) async {
    await auth.setPin(pin);
    hasPin = true;
    notifyListeners();
  }

  String newId() => 'p${DateTime.now().microsecondsSinceEpoch}';

  // ------------------------------------------------------------------ sync

  Map<String, dynamic> nativeConfig() {
    final now = DateTime.now();
    final active = (snoozeUntil != null && now.isBefore(snoozeUntil!));
    return {
      'manualActiveId': manualActiveId,
      'effectiveId': effectiveAt(now)?.id,
      'snoozedId': active ? snoozedId : null,
      'snoozeUntil': active ? snoozeUntil!.millisecondsSinceEpoch : null,
      'profiles': [
        for (final p in profiles)
          {
            'id': p.id,
            'name': p.name,
            'blocked': p.blockedPackages.toList(),
            'tamperProtection': p.tamperProtection,
            'schedule': p.scheduleEnabled && p.schedule.days.isNotEmpty
                ? p.schedule.toJson()
                : null,
          },
      ],
    };
  }

  Future<void> _persistAndSync() async {
    _lastEffectiveId = effective?.id;
    notifyListeners();
    await store.save(StoredState(
      profiles: profiles,
      manualActiveId: manualActiveId,
      snoozedId: snoozedId,
      snoozeUntil: snoozeUntil,
      seededSuggestions: _seeded,
    ));
    try {
      await ProfilerBlocker.syncConfig(nativeConfig());
    } catch (e) {
      debugPrint('syncConfig failed: $e');
    }
  }
}
