import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

class StoredState {
  final List<Profile> profiles;
  final String? manualActiveId;
  final String? snoozedId;
  final DateTime? snoozeUntil;
  final bool seededSuggestions;

  const StoredState({
    required this.profiles,
    this.manualActiveId,
    this.snoozedId,
    this.snoozeUntil,
    this.seededSuggestions = false,
  });
}

/// Persists profiles and the active-profile state on the Dart side.
class ProfileStore {
  static const _key = 'profiler.state.v1';

  Future<StoredState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return StoredState(
      profiles: ((j['profiles'] as List?) ?? const [])
          .map((e) => Profile.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      manualActiveId: j['manualActiveId'] as String?,
      snoozedId: j['snoozedId'] as String?,
      snoozeUntil: j['snoozeUntil'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(j['snoozeUntil'] as int),
      seededSuggestions: (j['seeded'] as bool?) ?? false,
    );
  }

  Future<void> save(StoredState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'profiles': s.profiles.map((p) => p.toJson()).toList(),
        'manualActiveId': s.manualActiveId,
        'snoozedId': s.snoozedId,
        'snoozeUntil': s.snoozeUntil?.millisecondsSinceEpoch,
        'seeded': s.seededSuggestions,
      }),
    );
  }
}
