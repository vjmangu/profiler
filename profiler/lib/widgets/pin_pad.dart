import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dots + numeric keypad. Calls [onComplete] once [length] digits are in.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.length,
    required this.onComplete,
    this.onBiometric,
    this.errorText,
    this.enabled = true,
  });

  final int length;
  final Future<void> Function(String pin, VoidCallback clear) onComplete;
  final VoidCallback? onBiometric;
  final String? errorText;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _clear() => setState(() => _pin = '');

  Future<void> _tap(String d) async {
    if (!widget.enabled || _pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == widget.length) {
      await widget.onComplete(_pin, _clear);
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? scheme.primary : Colors.transparent,
                border: Border.all(color: scheme.primary, width: 2),
              ),
            );
          }),
        ),
        SizedBox(
          height: 36,
          child: Center(
            child: Text(
              widget.errorText ?? '',
              style: TextStyle(color: scheme.error),
            ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _iconKey(
              widget.onBiometric == null ? null : Icons.fingerprint,
              widget.onBiometric,
            ),
            _key('0'),
            _iconKey(Icons.backspace_outlined, _back),
          ],
        ),
      ],
    );
  }

  Widget _key(String d) => Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 72,
          height: 72,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(shape: const CircleBorder()),
            onPressed: widget.enabled ? () => _tap(d) : null,
            child: Text(d, style: const TextStyle(fontSize: 26)),
          ),
        ),
      );

  Widget _iconKey(IconData? icon, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 72,
          height: 72,
          child: icon == null
              ? null
              : IconButton(
                  iconSize: 30,
                  onPressed: onTap,
                  icon: Icon(icon),
                ),
        ),
      );
}
