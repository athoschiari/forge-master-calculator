import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/stats.dart';
import 'number_field.dart';

/// Editable list of up to [maxCount] substats: each row is a type dropdown plus
/// a value field. Reports the current list through [onChanged]. Shared by the
/// gear, pet and mount editors.
class SubstatEditor extends StatelessWidget {
  const SubstatEditor({
    super.key,
    required this.substats,
    required this.onChanged,
    this.maxCount = 2,
  });

  final List<Substat> substats;
  final ValueChanged<List<Substat>> onChanged;
  final int maxCount;

  void _update(int index, Substat value) {
    final next = [...substats];
    next[index] = value;
    onChanged(next);
  }

  void _add() {
    onChanged([
      ...substats,
      const Substat(type: SubstatType.damage, value: 0),
    ]);
  }

  void _remove(int index) {
    final next = [...substats]..removeAt(index);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < substats.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<SubstatType>(
                    initialValue: substats[i].type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Substat'),
                    items: [
                      for (final t in SubstatType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (t) {
                      if (t != null) {
                        _update(i, substats[i].copyWith(type: t));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: NumberField(
                    label: 'Value',
                    value: substats[i].value,
                    allowShorthand: false,
                    suffix: substats[i].type.isPercent ? '%' : null,
                    onChanged: (v) => _update(i, substats[i].copyWith(value: v)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _remove(i),
                ),
              ],
            ),
          ),
        if (substats.length < maxCount)
          TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add substat'),
          ),
      ],
    );
  }
}
