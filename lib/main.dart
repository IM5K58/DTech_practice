import 'package:flutter/material.dart';
import 'dart:ui';
import 'drawing_board.dart';
import 'models/stroke.dart';
import 'widgets/pen_palette.dart';

void main() {
  runApp(const DrawingApp());
}

class DrawingApp extends StatelessWidget {
  const DrawingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SoriCanvas',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final drawingController = DrawingController();

  // 펜 선택 상태
  PenType _penType = PenType.pencil;
  double _thickness = 6.0;
  Color _color = Colors.black;

  void _openPenPalette() async {
    final result = await showModalBottomSheet<PenPaletteResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => PenPaletteSheet(
        initialType: _penType,
        initialThickness: _thickness,
        initialColor: _color,
      ),
    );

    if (result != null) {
      setState(() {
        _penType = result.type;
        _thickness = result.thickness;
        _color = result.color;
      });
    }
  }

  void _clearAll() {
    drawingController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoriCanvas'),
        actions: [
          // Undo / Redo 상태에 따라 버튼 활성/비활성
          ValueListenableBuilder<HistoryState>(
            valueListenable: drawingController.history,
            builder: (context, hist, _) {
              return Row(
                children: [
                  IconButton(
                    tooltip: '실행 취소 (Undo)',
                    onPressed: hist.canUndo ? drawingController.undo : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: '다시 실행 (Redo)',
                    onPressed: hist.canRedo ? drawingController.redo : null,
                    icon: const Icon(Icons.redo),
                  ),
                ],
              );
            },
          ),
          IconButton(
            tooltip: '펜 선택',
            onPressed: _openPenPalette,
            icon: const Icon(Icons.brush_outlined),
          ),
          IconButton(
            tooltip: '전체 지우기',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 화면을 꽉 채우지 않는 4:3 직사각형
          const padding = 16.0;
          final maxWidth = constraints.maxWidth - padding * 2;
          final maxHeight = constraints.maxHeight - padding * 2 - 12;

          // 4:3 비율 박스 크기 계산
          double width = maxWidth;
          double height = width * 3 / 4;
          if (height > maxHeight) {
            height = maxHeight;
            width = height * 4 / 3;
          }

          return Center(
            child: Container(
              width: width,
              height: height,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: Offset(0, 6),
                    color: Color(0x1A000000),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: DrawingBoard(
                    controller: drawingController,
                    penType: _penType,
                    baseThickness: _thickness,
                    color: _color,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
