// Unit tests for the scheduling / profile rules. (Named widget_test.dart so
// `flutter create` doesn't generate its default counter-app test here.)
import 'package:flutter_test/flutter_test.dart';
import 'package:profiler/data/app_groups.dart';
import 'package:profiler/models/profile.dart';
import 'package:profiler_blocker/profiler_blocker.dart';

void main() {
  group('ProfileSchedule', () {
    const work = ProfileSchedule.workDefault; // Mon–Fri 9:00–17:00

    test('active inside weekday hours', () {
      // 2026-10-05 is a Monday.
      expect(work.isActiveAt(DateTime(2026, 10, 5, 9, 0)), isTrue);
      expect(work.isActiveAt(DateTime(2026, 10, 5, 16, 59)), isTrue);
    });

    test('inactive outside hours and on weekends', () {
      expect(work.isActiveAt(DateTime(2026, 10, 5, 8, 59)), isFalse);
      expect(work.isActiveAt(DateTime(2026, 10, 5, 17, 0)), isFalse);
      expect(work.isActiveAt(DateTime(2026, 10, 3, 12, 0)), isFalse); // Sat
    });

    test('overnight window spills into the next day', () {
      const night = ProfileSchedule(
          days: {5}, startMinute: 22 * 60, endMinute: 6 * 60); // Fri 10pm–6am
      expect(night.isActiveAt(DateTime(2026, 10, 9, 23, 0)), isTrue); // Fri
      expect(night.isActiveAt(DateTime(2026, 10, 10, 5, 0)), isTrue); // Sat am
      expect(night.isActiveAt(DateTime(2026, 10, 10, 7, 0)), isFalse);
      expect(night.isActiveAt(DateTime(2026, 10, 9, 5, 0)), isFalse); // Fri am
    });

    test('window end for pause', () {
      expect(work.windowEndAfter(DateTime(2026, 10, 5, 10, 30)),
          DateTime(2026, 10, 5, 17, 0));
      const night =
          ProfileSchedule(days: {5}, startMinute: 1320, endMinute: 360);
      expect(night.windowEndAfter(DateTime(2026, 10, 9, 23, 0)),
          DateTime(2026, 10, 10, 6, 0));
    });

    test('describe', () {
      expect(work.describe(), 'Weekdays · 9:00 AM – 5:00 PM');
    });
  });

  group('Profile JSON', () {
    test('round-trips', () {
      const p = Profile(
        id: 'kid',
        name: 'Kid',
        kind: ProfileKind.kid,
        blockedPackages: {'com.whatsapp'},
        requireAuthToExit: true,
        tamperProtection: true,
      );
      final back = Profile.fromJson(p.toJson());
      expect(back.kind, ProfileKind.kid);
      expect(back.blockedPackages, {'com.whatsapp'});
      expect(back.requireAuthToExit, isTrue);
      expect(back.tamperProtection, isTrue);
    });
  });

  group('App groups', () {
    const apps = [
      InstalledApp(packageName: 'com.whatsapp', label: 'WhatsApp'),
      InstalledApp(packageName: 'com.example.mybank', label: 'My Bank'),
      InstalledApp(packageName: 'com.instagram.android', label: 'Instagram'),
      InstalledApp(packageName: 'com.example.game', label: 'Puzzle', category: 0),
      InstalledApp(packageName: 'com.example.notes', label: 'Notes'),
    ];

    test('kid suggestions: messaging + banking, not social or games', () {
      final s = suggestPackages(defaultGroupsFor(ProfileKind.kid), apps);
      expect(s, containsAll(['com.whatsapp', 'com.example.mybank']));
      expect(s, isNot(contains('com.instagram.android')));
      expect(s, isNot(contains('com.example.game')));
    });

    test('focus suggestions: social only', () {
      final s = suggestPackages(defaultGroupsFor(ProfileKind.focus), apps);
      expect(s, {'com.instagram.android'});
    });

    test('work suggestions include games and social', () {
      final s = suggestPackages(defaultGroupsFor(ProfileKind.work), apps);
      expect(s, containsAll(['com.instagram.android', 'com.example.game']));
      expect(s, isNot(contains('com.example.notes')));
    });
  });
}
