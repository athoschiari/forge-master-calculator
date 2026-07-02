import 'package:flutter/material.dart';

/// A single-select dropdown that also lets you type to filter the options.
/// Click the field or press the down arrow while focused to open the full
/// list; typing narrows it down by label. Thin wrapper around [DropdownMenu]
/// shared by every dropdown in the app so they all behave the same way.
class SearchableDropdown<T> extends StatelessWidget {
  const SearchableDropdown({
    super.key,
    required this.value,
    required this.entries,
    required this.onChanged,
    this.label,
    this.width,
  });

  final T value;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T> onChanged;
  final Widget? label;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T>(
      initialSelection: value,
      label: label,
      width: width,
      enableFilter: true,
      requestFocusOnTap: true,
      dropdownMenuEntries: entries,
      onSelected: (v) {
        if (v == null && null is! T) return;
        onChanged(v as T);
      },
    );
  }
}
