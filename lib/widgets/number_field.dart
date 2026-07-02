import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/parser.dart';
import '../utils/formatting.dart';

/// Text field for numeric input that understands the game's k/m/b shorthand
/// (e.g. "1.05m"). Reports the parsed raw value through [onChanged].
class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowShorthand = true,
    this.suffix,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  /// When true the field accepts k/m/b suffixes; when false it is a plain
  /// number (used for percentages and levels).
  final bool allowShorthand;
  final String? suffix;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _display(widget.value));
  }

  @override
  void didUpdateWidget(NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only overwrite when the external value diverges from what is typed, so the
    // caret is not reset while editing.
    final parsed = _parse(_controller.text);
    if (parsed != widget.value && !_controller.value.composing.isValid) {
      _controller.text = _display(widget.value);
    }
  }

  String _display(double value) {
    if (value == 0) return '';
    if (widget.allowShorthand) return formatCompact(value);
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  double _parse(String text) {
    if (widget.allowShorthand) return Parser.parseAmount(text) ?? 0;
    return double.tryParse(text.replaceAll(',', '.')) ?? 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,kmbKMB %]')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
      ),
      onChanged: (text) => widget.onChanged(_parse(text)),
    );
  }
}
