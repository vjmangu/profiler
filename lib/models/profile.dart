import 'package:flutter/material.dart';

enum ProfileKind { kid, focus, work, custom }

extension ProfileKindX on ProfileKind {
  IconData get icon => switch (this) {
        ProfileKind.kid => Icons.child_care_rounded,
        ProfileKind.focus => Icons.center_focus_strong_rounded,
        ProfileKind.work => Icons.work_rounded,
        ProfileKind.custom => Icons.tune_rounded,
      };

  Color get color => switch (this) {
        ProfileKind.kid => const Color(0xFFF59E0B),
        ProfileKind.focus => const Color(0xFF8B5CF6),
        ProfileKind.work => const Color(0xFF0EA5E9),
        ProfileKind.custom => const Color(0xFF10B981),
      };

  String get tagline => switch (this) {
        ProfileKind.kid => 'Blocks messaging, calls, banking & email',
        ProfileKind.focus => 'Blocks social media',
        ProfileKind.work => 'Blocks distractions during work hours',
        ProfileKind.custom => 'Your own rules',
      };
}

/// A weekly time window. Days use ISO numbering: 1 = Monday … 7 = Sunday.
/// Minutes are minutes after midnight. If [endMinute] <= [startMinute] the
/// window runs overnight into the next day.
class ProfileSchedule {
  final Set<int> days;
  final int startMinute;
  final int endMinute;

  const ProfileSchedule({
    required this.days,
    required this.startMinute,
    required this.endMinute,
  });

  static const workDefault = ProfileSchedule(
    days: {1, 2, 3, 4, 5},
    startMinute: 9 * 60,
    endMinute: 17 * 60,
  );

  bool get overnight => endMinute <= startMinute;

  bool isActiveAt(DateTime t) {
    if (days.isEmpty) return false;
    final m = t.hour * 60 + t.minute;
    final dow = t.weekday;
    if (!overnight) {
      return days.contains(dow) && m >= startMinute && m < endMinute;
    }
    final prev = dow == 1 ? 7 : dow - 1;
    return (days.contains(dow) && m >= startMinute) ||
        (days.contains(prev) && m < endMinute);
  }

  /// When the window that is active at [t] ends.
  DateTime windowEndAfter(DateTime t) {
    final m = t.hour * 60 + t.minute;
    final today = DateTime(t.year, t.month, t.day);
    final endToday = today.add(Duration(minutes: endMinute));
    if (overnight && m >= startMinute) {
      return endToday.add(const Duration(days: 1));
    }
    return endToday;
  }

  ProfileSchedule copyWith({Set<int>? days, int? startMinute, int? endMinute}) =>
      ProfileSchedule(
        days: days ?? this.days,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
      );

  Map<String, dynamic> toJson() => {
        'days': (days.toList()..sort()),
        'start': startMinute,
        'end': endMinute,
      };

  factory ProfileSchedule.fromJson(Map<String, dynamic> j) => ProfileSchedule(
        days: ((j['days'] as List?) ?? const []).cast<int>().toSet(),
        startMinute: j['start'] as int,
        endMinute: j['end'] as int,
      );

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static String dayLetter(int d) => _dayLetters[d - 1];

  static String formatMinute(int m) {
    final h = m ~/ 60, mm = m % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final ap = h < 12 ? 'AM' : 'PM';
    return '$h12:${mm.toString().padLeft(2, '0')} $ap';
  }

  String describe() {
    final sorted = days.toList()..sort();
    String dayText;
    if (sorted.length == 7) {
      dayText = 'Every day';
    } else if (sorted.join() == '12345') {
      dayText = 'Weekdays';
    } else if (sorted.join() == '67') {
      dayText = 'Weekends';
    } else {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dayText = sorted.map((d) => names[d - 1]).join(', ');
    }
    return '$dayText · ${formatMinute(startMinute)} – ${formatMinute(endMinute)}';
  }
}

class Profile {
  final String id;
  final String name;
  final ProfileKind kind;

  /// Android package names to block.
  final Set<String> blockedPackages;

  /// iOS: how many apps/categories/sites are selected in the Screen Time
  /// picker (the tokens themselves live natively and are opaque).
  final int iosSelectionCount;

  final bool scheduleEnabled;
  final ProfileSchedule schedule;

  /// Leaving this profile (or editing settings while it's on) needs the
  /// parent PIN or biometrics.
  final bool requireAuthToExit;

  /// Also block Settings, Play Store and the package installer (Android) /
  /// prevent deleting apps (iOS), so the profile can't be switched off from
  /// outside the app.
  final bool tamperProtection;

  const Profile({
    required this.id,
    required this.name,
    required this.kind,
    this.blockedPackages = const {},
    this.iosSelectionCount = 0,
    this.scheduleEnabled = false,
    this.schedule = ProfileSchedule.workDefault,
    this.requireAuthToExit = false,
    this.tamperProtection = false,
  });

  Profile copyWith({
    String? name,
    Set<String>? blockedPackages,
    int? iosSelectionCount,
    bool? scheduleEnabled,
    ProfileSchedule? schedule,
    bool? requireAuthToExit,
    bool? tamperProtection,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        kind: kind,
        blockedPackages: blockedPackages ?? this.blockedPackages,
        iosSelectionCount: iosSelectionCount ?? this.iosSelectionCount,
        scheduleEnabled: scheduleEnabled ?? this.scheduleEnabled,
        schedule: schedule ?? this.schedule,
        requireAuthToExit: requireAuthToExit ?? this.requireAuthToExit,
        tamperProtection: tamperProtection ?? this.tamperProtection,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'blocked': blockedPackages.toList(),
        'iosCount': iosSelectionCount,
        'scheduleEnabled': scheduleEnabled,
        'schedule': schedule.toJson(),
        'requireAuth': requireAuthToExit,
        'tamper': tamperProtection,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: ProfileKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => ProfileKind.custom,
        ),
        blockedPackages:
            ((j['blocked'] as List?) ?? const []).cast<String>().toSet(),
        iosSelectionCount: (j['iosCount'] as int?) ?? 0,
        scheduleEnabled: (j['scheduleEnabled'] as bool?) ?? false,
        schedule: j['schedule'] == null
            ? ProfileSchedule.workDefault
            : ProfileSchedule.fromJson(
                Map<String, dynamic>.from(j['schedule'] as Map)),
        requireAuthToExit: (j['requireAuth'] as bool?) ?? false,
        tamperProtection: (j['tamper'] as bool?) ?? false,
      );
}
