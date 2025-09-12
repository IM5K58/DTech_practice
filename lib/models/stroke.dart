import 'dart:ui';

enum PenType { pencil, marker, fountain }

class Stroke {
  Stroke({
    required this.points,
    required this.segmentWidths,
    required this.color,
    required this.penType,
    required this.baseWidth,
  });

  final List<Offset> points;
  final List<double> segmentWidths; // points 사이사이의 두께
  final Color color;
  final PenType penType;
  final double baseWidth;
}
