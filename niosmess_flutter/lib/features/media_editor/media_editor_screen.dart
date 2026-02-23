import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

/// Экран редактирования медиа (фото/видео)
/// Поддерживает: фильтры, кроп, рисование, текст, стикеры
class MediaEditorScreen extends StatefulWidget {
  final XFile imageFile;

  const MediaEditorScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  late File _currentImage;
  final GlobalKey _globalKey = GlobalKey();

  // Режимы редактирования
  EditorMode _mode = EditorMode.none;

  // Для рисования
  final List<DrawnLine> _lines = [];
  DrawnLine? _currentLine;
  Color _selectedColor = Colors.red;
  double _strokeWidth = 3.0;

  // Для текста
  final List<TextItem> _textItems = [];
  TextItem? _editingText;

  // Для стикеров
  final List<StickerItem> _stickers = [];

  // Фильтр
  ImageFilter? _currentFilter;

  @override
  void initState() {
    super.initState();
    _currentImage = File(widget.imageFile.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Редактор',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _saveImage,
          ),
        ],
      ),
      body: Column(
        children: [
          // Рабочая область
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _globalKey,
                child: Stack(
                  children: [
                    // Изображение с фильтром
                    _buildImageWithFilter(),

                    // Рисунки
                    ..._buildDrawnLines(),

                    // Текстовые элементы
                    ..._buildTextItems(),

                    // Стикеры
                    ..._buildStickers(),

                    // Холст для рисования
                    if (_mode == EditorMode.draw)
                      GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: DrawingPainter(
                            lines: [..._lines, if (_currentLine != null) _currentLine!],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Панель инструментов
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildImageWithFilter() {
    return ColorFiltered(
      colorFilter: _currentFilter?.matrix ?? const ColorFilter.mode(
        Colors.transparent,
        BlendMode.multiply,
      ),
      child: Image.file(_currentImage),
    );
  }

  List<Widget> _buildDrawnLines() {
    return [
      CustomPaint(
        size: Size.infinite,
        painter: DrawingPainter(lines: _lines),
      ),
    ];
  }

  List<Widget> _buildTextItems() {
    return _textItems.map((textItem) {
      return Positioned(
        left: textItem.position.dx,
        top: textItem.position.dy,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              textItem.position += details.delta;
            });
          },
          onDoubleTap: () {
            setState(() {
              _editingText = textItem;
            });
            _showTextEditDialog(textItem);
          },
          child: Transform.rotate(
            angle: textItem.rotation,
            child: Transform.scale(
              scale: textItem.scale,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: textItem.hasBackground
                    ? BoxDecoration(
                        color: textItem.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Text(
                  textItem.text,
                  style: TextStyle(
                    color: textItem.color,
                    fontSize: textItem.fontSize,
                    fontWeight: textItem.isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: textItem.isItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildStickers() {
    return _stickers.map((sticker) {
      return Positioned(
        left: sticker.position.dx,
        top: sticker.position.dy,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              sticker.position += details.delta;
            });
          },
          child: Transform.scale(
            scale: sticker.scale,
            child: Text(
              sticker.emoji,
              style: const TextStyle(fontSize: 48),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Основные инструменты
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildToolButton(
                icon: Icons.filter,
                label: 'Фильтры',
                isActive: _mode == EditorMode.filter,
                onTap: () => setState(() => _mode = EditorMode.filter),
              ),
              _buildToolButton(
                icon: Icons.brush,
                label: 'Рисовать',
                isActive: _mode == EditorMode.draw,
                onTap: () => setState(() => _mode = EditorMode.draw),
              ),
              _buildToolButton(
                icon: Icons.text_fields,
                label: 'Текст',
                isActive: _mode == EditorMode.text,
                onTap: () {
                  setState(() => _mode = EditorMode.text);
                  _showTextEditDialog(null);
                },
              ),
              _buildToolButton(
                icon: Icons.emoji_emotions,
                label: 'Стикеры',
                isActive: _mode == EditorMode.sticker,
                onTap: () => setState(() => _mode = EditorMode.sticker),
              ),
              _buildToolButton(
                icon: Icons.crop,
                label: 'Кроп',
                isActive: _mode == EditorMode.crop,
                onTap: () => setState(() => _mode = EditorMode.crop),
              ),
            ],
          ),

          // Дополнительные опции в зависимости от режима
          if (_mode == EditorMode.draw) _buildDrawOptions(),
          if (_mode == EditorMode.filter) _buildFilterOptions(),
          if (_mode == EditorMode.sticker) _buildStickerOptions(),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? Colors.blue : Colors.white,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.blue : Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawOptions() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final color in [
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.purple,
                  Colors.white,
                  Colors.black,
                ])
                  GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == color ? Colors.blue : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: _lines.isEmpty
                ? null
                : () => setState(() => _lines.removeLast()),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOptions() {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _buildFilterPreview('Нет', null),
          _buildFilterPreview('Grayscale', ImageFilter.grayscale()),
          _buildFilterPreview('Sepia', ImageFilter.sepia()),
          _buildFilterPreview('Invert', ImageFilter.invert()),
          _buildFilterPreview('Vintage', ImageFilter.vintage()),
        ],
      ),
    );
  }

  Widget _buildFilterPreview(String name, ImageFilter? filter) {
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = filter),
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _currentFilter == filter ? Colors.blue : Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerOptions() {
    final emojis = ['😀', '😍', '🎉', '❤️', '👍', '🔥', '✨', '💯'];
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: emojis.map((emoji) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _stickers.add(
                  StickerItem(
                    emoji: emoji,
                    position: const Offset(100, 100),
                  ),
                );
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showTextEditDialog(TextItem? existingText) {
    final controller = TextEditingController(text: existingText?.text ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить текст'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Введите текст...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  if (existingText != null) {
                    existingText.text = controller.text;
                  } else {
                    _textItems.add(
                      TextItem(
                        text: controller.text,
                        position: const Offset(100, 100),
                        color: Colors.white,
                      ),
                    );
                  }
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  // Рисование
  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentLine = DrawnLine(
        points: [details.localPosition],
        color: _selectedColor,
        width: _strokeWidth,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentLine = DrawnLine(
        points: [..._currentLine!.points, details.localPosition],
        color: _selectedColor,
        width: _strokeWidth,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _lines.add(_currentLine!);
      _currentLine = null;
    });
  }

  // Сохранение
  Future<void> _saveImage() async {
    try {
      final boundary =
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // TODO: Сохранить файл
      Navigator.pop(context, pngBytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    }
  }
}

// Модели данных
enum EditorMode { none, filter, draw, text, sticker, crop }

class DrawnLine {
  final List<Offset> points;
  final Color color;
  final double width;

  DrawnLine({required this.points, required this.color, required this.width});
}

class TextItem {
  String text;
  Offset position;
  Color color;
  double fontSize;
  bool isBold;
  bool isItalic;
  bool hasBackground;
  Color backgroundColor;
  double rotation;
  double scale;

  TextItem({
    required this.text,
    required this.position,
    required this.color,
    this.fontSize = 24.0,
    this.isBold = false,
    this.isItalic = false,
    this.hasBackground = false,
    this.backgroundColor = Colors.black,
    this.rotation = 0.0,
    this.scale = 1.0,
  });
}

class StickerItem {
  final String emoji;
  Offset position;
  double scale;

  StickerItem({
    required this.emoji,
    required this.position,
    this.scale = 1.0,
  });
}

class ImageFilter {
  final ColorFilter? matrix;
  final String name;

  ImageFilter({this.matrix, required this.name});

  factory ImageFilter.grayscale() {
    return ImageFilter(
      name: 'Grayscale',
      matrix: ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]),
    );
  }

  factory ImageFilter.sepia() {
    return ImageFilter(
      name: 'Sepia',
      matrix: ColorFilter.matrix([
        0.393, 0.769, 0.189, 0, 0,
        0.349, 0.686, 0.168, 0, 0,
        0.272, 0.534, 0.131, 0, 0,
        0, 0, 0, 1, 0,
      ]),
    );
  }

  factory ImageFilter.invert() {
    return ImageFilter(
      name: 'Invert',
      matrix: ColorFilter.matrix([
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]),
    );
  }

  factory ImageFilter.vintage() {
    return ImageFilter(
      name: 'Vintage',
      matrix: ColorFilter.matrix([
        0.6, 0.3, 0.1, 0, 0,
        0.2, 0.7, 0.1, 0, 0,
        0.2, 0.3, 0.5, 0, 0,
        0, 0, 0, 1, 0,
      ]),
    );
  }
}

// Painter для рисунков
class DrawingPainter extends CustomPainter {
  final List<DrawnLine> lines;

  DrawingPainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.width
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < line.points.length - 1; i++) {
        canvas.drawLine(line.points[i], line.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}
