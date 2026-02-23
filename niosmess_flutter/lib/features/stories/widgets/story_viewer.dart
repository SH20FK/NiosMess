import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/story.dart';
import '../providers/stories_provider.dart';

/// Полноэкранный просмотрщик историй
class StoryViewer extends ConsumerStatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const StoryViewer({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends ConsumerState<StoryViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentIndex = 0;
  bool _isPaused = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // 5 секунд на историю
    );

    _startProgress();
    _markAsViewed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startProgress() {
    _progressController.reset();
    _progressController.forward().then((_) {
      if (!_isPaused && mounted) {
        _nextStory();
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startProgress();
      _markAsViewed();
    } else {
      // Закрыть просмотрщик
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startProgress();
    }
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _progressController.stop();
    } else {
      _progressController.forward();
    }
  }

  void _markAsViewed() {
    final story = widget.stories[_currentIndex];
    ref.read(storiesProvider.notifier).markAsViewed(story.id);
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          // Левая половина - предыдущая, правая - следующая
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _previousStory();
          } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
            _nextStory();
          } else {
            _togglePause();
          }
        },
        child: Stack(
          children: [
            // Фоновое изображение/видео
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                final storyMedia = widget.stories[index].media.first;
                return _buildMediaContent(storyMedia);
              },
            ),

            // Индикаторы прогресса сверху
            SafeArea(
              child: Column(
                children: [
                  _buildProgressBars(),
                  _buildHeader(story, theme),
                ],
              ),
            ),

            // Поле ответа снизу
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: _buildReplyField(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(StoryMedia media) {
    if (media.type == StoryMediaType.image) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            media.url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
          ),
          if (media.text != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Text(
                media.text!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    } else {
      // TODO: Реализовать видео плеер
      return const Center(
        child: Text(
          'Видео контент',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
  }

  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(
          widget.stories.length,
          (index) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: LinearProgressIndicator(
                value: index < _currentIndex
                    ? 1.0
                    : index == _currentIndex
                        ? _progressController.value
                        : 0.0,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Story story, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Аватар
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              Icons.person,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),

          // Имя и время
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatTime(story.createdAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Кнопка паузы
          if (_isPaused)
            const Icon(
              Icons.pause,
              color: Colors.white,
              size: 24,
            ),

          const SizedBox(width: 8),

          // Кнопка закрытия
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ответить...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    // TODO: Отправить ответ
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ответ отправлен!')),
                    );
                  }
                },
              ),
            ),
            IconButton(
              onPressed: () {
                // TODO: Отправить реакцию сердечком
              },
              icon: const Icon(Icons.favorite_border, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else {
      return '${dateTime.day}.${dateTime.month}';
    }
  }
}
