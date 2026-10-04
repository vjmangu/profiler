import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Parent PIN (salted SHA-256 in the Keychain/Keystore) + biometrics.
class AuthService {
  static const pinLength = 4;
  static const _maxAttempts = 5;
  static const _lockout = Duration(seconds: 30);

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _localAuth = LocalAuthentication();

  int _failed = 0;
  DateTime? _lockedUntil;

  Future<bool> hasPin() async => (await _secure.read(key: 'pin_hash')) != null;

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await _secure.write(key: 'pin_salt', value: salt);
    await _secure.write(key: 'pin_hash', value: _hash(pin, salt));
  }

  /// Remaining lockout, or null if PIN entry is allowed.
  Duration? get lockoutRemaining {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    if (left.isNegative) {
      _lockedUntil = null;
      return null;
    }
    return left;
  }

  Future<bool> verifyPin(String pin) async {
    if (lockoutRemaining != null) return false;
    final salt = await _secure.read(key: 'pin_salt');
    final hash = await _secure.read(key: 'pin_hash');
    if (salt == null || hash == null) return false;
    final ok = _hash(pin, salt) == hash;
    if (ok) {
      _failed = 0;
    } else if (++_failed >= _maxAttempts) {
      _failed = 0;
      _lockedUntil = DateTime.now().add(_lockout);
    }
    return ok;
  }

  Future<bool> biometricsAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics &&
          (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
