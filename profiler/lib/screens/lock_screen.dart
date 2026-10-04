import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/pin_pad.dart';

/// Asks for the parent PIN or biometrics. Returns true when verified.
/// Usage: `final ok = await LockScreen.verify(context, auth, reason: '...')`.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.auth, required this.reason});

  final AuthService auth;
  final String reason;

  static Future<bool> verify(
    BuildContext context,
    AuthService auth, {
    required String reason,
  }) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LockScreen(auth: auth, reason: reason),
      ),
    );
    return ok ?? false;
  }

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _bio = false;
  String? _error;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
    _refreshLockout();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<void> _initBiometrics() async {
    final available = await widget.auth.biometricsAvailable();
    if (!mounted) return;
    setState(() => _bio = available);
    if (available) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final ok = await widget.auth.authenticateBiometric(widget.reason);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  void _refreshLockout() {
    _lockTimer?.cancel();
    final left = widget.auth.lockoutRemaining;
    if (left == null) return;
    setState(() => _error = 'Too many tries. Wait ${left.inSeconds + 1}s');
    _lockTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (widget.auth.lockoutRemaining == null) {
        setState(() => _error = null);
      } else {
        _refreshLockout();
      }
    });
  }

  Future<void> _onPin(String pin, VoidCallback clear) async {
    final ok = await widget.auth.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    clear();
    setState(() => _error = 'Wrong PIN');
    _refreshLockout();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.auth.lockoutRemaining != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Icon(Icons.lock_rounded, size: 48),
                const SizedBox(height: 12),
                Text('Parent PIN',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(widget.reason, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                PinPad(
                  length: AuthService.pinLength,
                  enabled: !locked,
                  errorText: _error,
                  onBiometric: _bio ? _tryBiometric : null,
                  onComplete: _onPin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
