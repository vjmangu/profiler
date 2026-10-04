import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An app installed on the device (Android only — iOS never exposes this).
class InstalledApp {
  final String packageName;
  final String label;

  /// Android ApplicationInfo.category (0 game, 1 audio, 2 video, 3 image,
  /// 4 social, 5 news, 6 maps, 7 productivity), or -1 if undefined.
  final int category;
  final bool isSystem;
  final Uint8List? icon;

  const InstalledApp({
    required this.packageName,
    required this.label,
    this.category = -1,
    this.isSystem = false,
    this.icon,
  });

  factory InstalledApp.fromMap(Map<dynamic, dynamic> m) => InstalledApp(
        packageName: m['package'] as String,
        label: (m['label'] as String?) ?? m['package'] as String,
        category: (m['category'] as int?) ?? -1,
        isSystem: (m['isSystem'] as bool?) ?? false,
        icon: m['icon'] as Uint8List?,
      );
}

/// Thin wrapper over the native blocking engine.
class ProfilerBlocker {
  static const MethodChannel _ch = MethodChannel('profiler_blocker');

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Launchable apps on the device. Empty on iOS.
  static Future<List<InstalledApp>> getInstalledApps() async {
    if (!isAndroid) return const [];
    final raw = await _ch.invokeListMethod<Map<dynamic, dynamic>>(
            'getInstalledApps') ??
        const [];
    final apps = raw.map(InstalledApp.fromMap).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return apps;
  }

  /// Android: is the accessibility service on? iOS: is Screen Time approved?
  static Future<bool> isServiceEnabled() async =>
      await _ch.invokeMethod<bool>('isServiceEnabled') ?? false;

  /// Android: opens Accessibility settings. iOS: asks for Screen Time access.
  static Future<void> requestPermission() =>
      _ch.invokeMethod<void>('requestPermission');

  /// Push the full profile configuration to the native side, which enforces
  /// it even while this app is closed.
  static Future<void> syncConfig(Map<String, dynamic> config) =>
      _ch.invokeMethod<void>('syncConfig', {'json': jsonEncode(config)});

  /// iOS: shows Apple's app picker for [profileId]. Returns the number of
  /// apps/categories/sites selected, or null if cancelled.
  static Future<int?> pickApps(String profileId) =>
      _ch.invokeMethod<int>('pickApps', {'profileId': profileId});

  /// iOS: number of items currently selected for [profileId].
  static Future<int> selectionCount(String profileId) async =>
      await _ch.invokeMethod<int>('selectionCount', {'profileId': profileId}) ??
      0;

  /// iOS: forget the saved selection for a deleted profile.
  static Future<void> clearProfile(String profileId) =>
      _ch.invokeMethod<void>('clearProfile', {'profileId': profileId});
}
