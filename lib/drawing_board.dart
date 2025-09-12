import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/stroke.dart';

import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

class HistoryState {
  final bool canUndo;
  final bool canRedo;
  const HistoryState({required this.canUndo, required this.canRedo});
}

class DrawingController {
  VoidCallback? _onClear;
  VoidCallback? _onUndo;
  VoidCallback? _onRedo;

  final ValueNotifier<HistoryState> history =
  ValueNotifier<HistoryState>(const HistoryState(canUndo: false, canRedo: false));

  void _attach({
    required VoidCallback onClear,
    required VoidCallback onUndo,
    required VoidCallback onRedo,
  }) {
    _onClear = onClear;
    _onUndo = onUndo;
    _onRedo = onRedo;
  }

  void _setHistory(bool canUndo, bool canRedo) {
    history.value = HistoryState(canUndo: canUndo, canRedo: canRedo);
  }

  void clear() => _onClear?.call();
  void undo() => _onUndo?.call();
  void redo() => _onRedo?.call();
}

class DrawingBoard extends StatefulWidget {
  const DrawingBoard({
    super.key,
    required this.controller,
    required this.penType,
    required this.baseThickness,
    required this.color,
  });

  final DrawingController controller;
  final PenType penType;
  final double baseThickness;
  final Color color;

  @override
  State<DrawingBoard> createState() => _DrawingBoardState();
}

class _DrawingBoardState extends State<DrawingBoard> {
  final List<Stroke> _strokes = <Stroke>[];
  final List<Stroke> _redos = <Stroke>[];
  final Map<int, Stroke> _active = <int, Stroke>{};

  final Map<int, bool> _edgeBuzzed = <int, bool>{};

  // NEW
  final Map<int, math.Point<int>> _lastCell = <int, math.Point<int>>{};
  static const double _gridGap = 48.0;

  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(
      onClear: _handleClear,
      onUndo: _handleUndo,
      onRedo: _handleRedo,
    );
    _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _updateHistory();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _handleClear() {
    setState(() {
      _strokes.clear();
      _active.clear();
      _redos.clear();
      _edgeBuzzed.clear();
      _lastCell.clear();
    });
    _updateHistory();
  }

  void _handleUndo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _redos.add(_strokes.removeLast());
    });
    _updateHistory();
  }

  void _handleRedo() {
    if (_redos.isEmpty) return;
    setState(() {
      _strokes.add(_redos.removeLast());
    });
    _updateHistory();
  }

  void _updateHistory() {
    widget.controller._setHistory(_strokes.isNotEmpty, _redos.isNotEmpty);
  }

  static const double _minDistance = 0.8;

  bool _isInside(Offset p) {
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    return p.dx >= 0 && p.dy >= 0 && p.dx <= size.width && p.dy <= size.height;
  }

  math.Point<int> _cellOf(Offset p) {
    final ix = (p.dx / _gridGap).floor();
    final iy = (p.dy / _gridGap).floor();
    return math.Point<int>(ix, iy);
  }

  Future<void> _gridTickFeedback() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        if (await Vibration.hasAmplitudeControl() ?? false) {
          await Vibration.vibrate(duration: 18, amplitude: 120);
        } else {
          await Vibration.vibrate(duration: 18);
        }
      } else {
        await HapticFeedback.selectionClick();
      }
    } catch (_) {
      try { await HapticFeedback.lightImpact(); } catch(__) {}
    }
  }

  Future<void> _boundaryFeedback() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        if (await Vibration.hasAmplitudeControl() ?? false) {
          await Vibration.vibrate(duration: 110, amplitude: 255);
        } else {
          await Vibration.vibrate(duration: 110);
        }
      } else {
        try { await HapticFeedback.heavyImpact(); } catch (_) { await HapticFeedback.vibrate(); }
      }
    } catch (_) {}
    try {
      await _player.stop();
      // await _player.play(AssetSource('assets/beep.wav'));
    } catch (_){
      try { await SystemSound.play(SystemSoundType.alert); } catch(__){}
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    final device = e.kind;
    final isStylus = device == PointerDeviceKind.stylus || device == PointerDeviceKind.invertedStylus;

    if (_redos.isNotEmpty) {
      setState(() => _redos.clear());
    }
    _edgeBuzzed[e.pointer] = false;
    _lastCell[e.pointer] = _cellOf(e.localPosition);

    final base = widget.baseThickness;
    final thickness = switch (widget.penType) {
      PenType.pencil => base,
      PenType.marker => base * 2.0,
      PenType.fountain => base * (isStylus ? math.max(0.7, e.pressure) : 1.0),
    };

    final stroke = Stroke(
      points: [e.localPosition],
      segmentWidths: <double>[],
      color: widget.penType == PenType.marker
          ? widget.color.withOpacity(0.6)
          : widget.color,
      penType: widget.penType,
      baseWidth: thickness,
    );

    setState(() {
      _active[e.pointer] = stroke;
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    final stroke = _active[e.pointer];
    if (stroke == null) return;

    final last = stroke.points.isNotEmpty ? stroke.points.last : null;
    final current = e.localPosition;

    // grid cell crossing feedback
    final prevCell = _lastCell[e.pointer];
    final currCell = _cellOf(current);
    if (prevCell == null || prevCell != currCell) {
      _lastCell[e.pointer] = currCell;
      _gridTickFeedback();
    }

    // canvas boundary feedback
    final wasInside = last == null ? _isInside(current) : _isInside(last);
    final isInside = _isInside(current);
    if (wasInside && !isInside && (_edgeBuzzed[e.pointer] != true)) {
      _edgeBuzzed[e.pointer] = true;
      _boundaryFeedback();
    } else if (isInside) {
      _edgeBuzzed[e.pointer] = false;
    }

    if (last == null || (last - current).distance >= _minDistance) {
      double segWidth = stroke.baseWidth;
      if (stroke.penType == PenType.fountain) {
        final p = e.pressure;
        segWidth = math.max(0.5, stroke.baseWidth * (p.clamp(0.5, 2.0)));
      }
      stroke.points.add(current);
      if (stroke.points.length > 1) {
        stroke.segmentWidths.add(segWidth);
      }
      setState(() {});
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    final stroke = _active.remove(e.pointer);
    if (stroke == null) return;
    setState(() {
      _strokes.add(stroke);
    });
    _edgeBuzzed.remove(e.pointer);
    _lastCell.remove(e.pointer);
    _updateHistory();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _active.remove(e.pointer);
    _edgeBuzzed.remove(e.pointer);
    _lastCell.remove(e.pointer);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BoardPainter(
            strokes: _strokes,
            active: _active.values.toList(growable: false),
            bgColor: Theme.of(context).colorScheme.surfaceVariant,
            gridGap: _gridGap,
          ),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.strokes,
    required this.active,
    required this.bgColor,
    required this.gridGap,
  });

  final List<Stroke> strokes;
  final List<Stroke> active;
  final Color bgColor;
  final double gridGap;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..style = PaintingStyle.fill
      ..color = bgColor;
    canvas.drawRect(Offset.zero & size, bg);

    _drawLightGrid(canvas, size);

    for (final s in strokes) {
      _drawStroke(canvas, s);
    }
    for (final s in active) {
      _drawStroke(canvas, s);
    }
  }

  void _drawLightGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x11000000)
      ..strokeWidth = 1.0;
    final gap = gridGap;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawStroke(Canvas canvas, Stroke s) {
    if (s.points.length < 2) {
      final p = Paint()
        ..color = s.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.0, s.baseWidth / 2)
        ..style = PaintingStyle.stroke;
      canvas.drawPoints(PointMode.points, s.points, p);
      return;
    }

    final paint = Paint()
      ..color = s.color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    if (s.penType == PenType.marker) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    }

    for (int i = 0; i < s.points.length - 1; i++) {
      final a = s.points[i];
      final b = s.points[i + 1];
      final w = i < s.segmentWidths.length ? s.segmentWidths[i] : s.baseWidth;
      paint.strokeWidth = w;
      canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) {
    return true;
  }
}
