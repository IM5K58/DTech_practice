import 'package:flutter/material.dart';
import '../models/stroke.dart';

class PenPaletteResult {
  PenPaletteResult({
    required this.type,
    required this.thickness,
    required this.color,
  });

  final PenType type;
  final double thickness;
  final Color color;
}

class PenPaletteSheet extends StatefulWidget {
  const PenPaletteSheet({
    super.key,
    required this.initialType,
    required this.initialThickness,
    required this.initialColor,
  });

  final PenType initialType;
  final double initialThickness;
  final Color initialColor;

  @override
  State<PenPaletteSheet> createState() => _PenPaletteSheetState();
}

class _PenPaletteSheetState extends State<PenPaletteSheet> {
  late PenType _type;
  late double _thickness;
  late Color _color;

  static const _colors = <Color>[
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.pink,
    Colors.orange,
    Colors.amber,
    Colors.yellow,
    Colors.lime,
    Colors.green,
    Colors.teal,
    Colors.cyan,
    Colors.lightBlue,
    Colors.blue,
    Colors.indigo,
    Colors.deepPurple,
    Colors.purple,
    Colors.brown,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _thickness = widget.initialThickness.clamp(1.0, 40.0);
    _color = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('펜 선택', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _PenTypeChip(
                  label: '연필',
                  selected: _type == PenType.pencil,
                  icon: Icons.edit_outlined,
                  onTap: () => setState(() => _type = PenType.pencil),
                ),
                _PenTypeChip(
                  label: '마커',
                  selected: _type == PenType.marker,
                  icon: Icons.brush_outlined,
                  onTap: () => setState(() => _type = PenType.marker),
                ),
                _PenTypeChip(
                  label: '만년필',
                  selected: _type == PenType.fountain,
                  icon: Icons.create_outlined,
                  onTap: () => setState(() => _type = PenType.fountain),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('두께: ${_thickness.toStringAsFixed(1)}'),
            Slider(
              min: 1.0,
              max: 40.0,
              value: _thickness,
              onChanged: (v) => setState(() => _thickness = v),
            ),
            const SizedBox(height: 8),
            Text('색상'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((c) {
                final selected = _color.value == c.value;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? cs.primary : cs.outlineVariant,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      PenPaletteResult(
                        type: _type,
                        thickness: _thickness,
                        color: _color,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('적용'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PenTypeChip extends StatelessWidget {
  const _PenTypeChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}
