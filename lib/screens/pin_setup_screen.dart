import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/pin_pad.dart';

/// Create (or change) the parent PIN: enter, then confirm.
/// Calls [onDone] with the confirmed PIN.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.onDone, this.isChange = false});

  final Future<void> Function(String pin) onDone;
  final bool isChange;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;
  String? _error;
  int _round = 0; // rebuilds PinPad between steps

  Future<void> _onPin(String pin, VoidCallback clear) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
        _round++;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = "PINs didn't match — start again";
        _round++;
      });
      return;
    }
    await widget.onDone(pin);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: widget.isChange ? AppBar(title: const Text('Change PIN')) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (!widget.isChange) ...[
                  const Icon(Icons.shield_rounded, size: 56),
                  const SizedBox(height: 12),
                  Text('Welcome to Profiler', style: t.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Set a parent PIN. It’s needed to leave the Kid profile '
                    'or change settings while a locked profile is on. '
                    'Fingerprint / Face unlock works too.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                ],
                Text(
                  _first == null
                      ? 'Choose a ${AuthService.pinLength}-digit PIN'
                      : 'Enter it again to confirm',
                  style: t.titleMedium,
                ),
                const SizedBox(height: 16),
                PinPad(
                  key: ValueKey(_round),
                  length: AuthService.pinLength,
                  errorText: _error,
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
