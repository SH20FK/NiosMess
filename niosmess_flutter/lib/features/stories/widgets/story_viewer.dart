import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/story.dart';
import '../providers/stories_provider.dart';

/// Полноэкранный просмотрщик историй с поддержкой видео
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
  int _currentMediaIndex = 0;
  bool _isPaused = false;
  Timer? _timer;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _initializeCurrentStory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  StoryMedia get _currentMedia {
    final story = widget.stories[_currentIndex];
    if (story.media.isEmpty) {
      return const StoryMedia(
        id: '',
        type: StoryMediaType.image,
        url: '',
      );
    }
    return story.media[_currentMediaIndex.clamp(0, story.media.length - 1)];
  }

  void _initializeCurrentStory() {
    final media = _currentMedia;
    
    // Dispose previous video controller
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;

    if (media.type == StoryMediaType.video) {
      _initializeVideo(media);
    } else {
      _startProgress();
    }
    
    _markAsViewed();
  }

  Future<void> _initializeVideo(StoryMedia media) async {
    try {
      final controller = media.url.startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(media.url))
          : VideoPlayerController.file(File(media.url));

      _videoController = controller;
      
      await controller.initialize();
      
      if (!mounted) return;
      
      setState(() => _isVideoInitialized = true);
      
      // Set video duration for progress
      final duration = controller.value.duration;
      if (duration.inSeconds > 0) {
        _progressController.duration = duration;
      }
      
      controller.setLooping(false);
      controller.play();
      
      controller.addListener(_onVideoProgress);
      
      _progressController.forward().then((_) {
        if (!_isPaused && mounted) {
          _nextMediaOrStory();
        }
      });
    } catch (e) {
      debugPrint('Error initializing video: $e');
      // Fallback to image behavior
      _startProgress();
    }
  }

  void _onVideoProgress() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    
    if (duration.inMilliseconds > 0) {
      final progress = position.inMilliseconds / duration.inMilliseconds;
      _progressController.value = progress.clamp(0.0, 1.0);
    }
    
    if (_videoController!.value.isCompleted) {
      _nextMediaOrStory();
    }
  }

  void _startProgress() {
    _progressController.reset();
    _progressController.forward().then((_) {
      if (!_isPaused && mounted) {
        _nextMediaOrStory();
      }
    });
  }

  void _nextMediaOrStory() {
    final story = widget.stories[_currentIndex];
    
    // Check if there are more media items in current story
    if (_currentMediaIndex < story.media.length - 1) {
      setState(() => _currentMediaIndex++);
      _initializeCurrentStory();
    } else if (_currentIndex < widget.stories.length - 1) {
      // Move to next story
      setState(() {
        _currentIndex++;
        _currentMediaIndex = 0;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _initializeCurrentStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousMediaOrStory() {
    if (_currentMediaIndex > 0) {
      setState(() => _currentMediaIndex--);
      _initializeCurrentStory();
    } else if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _currentMediaIndex = 0;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _initializeCurrentStory();
    }
  }

  void _nextStory() {
    _nextMediaOrStory();
  }

  void _previousStory() {
    _previousMediaOrStory();
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    
    if (_isPaused) {
      _progressController.stop();
      _videoController?.pause();
    } else {
      _progressController.forward();
      _videoController?.play();
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
        onTapDown: (_) => _togglePause(),
        onLongPress: () => _togglePause(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Story content
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                final s = widget.stories[index];
                return _buildStoryContent(s);
              },
            ),

            // Progress indicators
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(
                  widget.stories.length,
                  (index) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildProgressIndicator(index),
                    ),
                  ),
                ),
              ),
            ),

            // Header with user info
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 16,
              right: 16,
              child: _buildHeader(story),
            ),

            // Navigation areas
            Row(
              children: [
                // Previous area
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: _previousStory,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
                // Pause area (center)
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _togglePause,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
                // Next area
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: _nextStory,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ],
            ),

            // Bottom controls
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: _buildBottomControls(theme),
            ),

            // Pause indicator
            if (_isPaused)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(Story story) {
    final media = _currentMedia;
    
    if (media.type == StoryMediaType.video) {
      if (!_isVideoInitialized || _videoController == null) {
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        );
      }
      
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    // Image story
    if (media.url.startsWith('http')) {
      return Image.network(
        media.url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
          );
        },
      );
    } else {
      return Image.file(
        File(media.url),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
          );
        },
      );
    }
  }

  Widget _buildProgressIndicator(int index) {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        double progress = 0;
        if (index < _currentIndex) {
          progress = 1;
        } else if (index == _currentIndex) {
          progress = _progressController.value;
        }
        
        return LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withOpacity(0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          minHeight: 2,
        );
      },
    );
  }

  Widget _buildHeader(Story story) {
    return Row(
      children: [
        // Avatar
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            image: story.avatarUrl != null
                ? DecorationImage(
                    image: NetworkImage(story.avatarUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: story.avatarUrl == null
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        
        // User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                story.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                _formatTime(story.createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        
        // Close button
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply field
        Container(
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
                      _sendReply(value);
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: () => _sendReply('❤️'),
                icon: const Icon(Icons.favorite_border, color: Colors.white),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Reaction bar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['❤️', '😂', '😮', '👏', '🔥'].map((emoji) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GestureDetector(
                onTap: () => _sendReply(emoji),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _sendReply(String text) {
    final story = widget.stories[_currentIndex];
    
    // TODO: Implement actual reply sending via API
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ответ отправлен: $text'),
        duration: const Duration(seconds: 1),
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
