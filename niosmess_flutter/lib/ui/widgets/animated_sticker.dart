import 'package:flutter/material.dart';

/// Виджет для анимированных стикеров
/// Поддерживает Lottie анимации и анимированные эмодзи
class AnimatedSticker extends StatefulWidget {
  final String stickerId;
  final double size;
  final VoidCallback? onTap;

  const AnimatedSticker({
    super.key,
    required this.stickerId,
    this.size = 120,
    this.onTap,
  });

  @override
  State<AnimatedSticker> createState() => _AnimatedStickerState();
}

class _AnimatedStickerState extends State<AnimatedSticker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward().then((_) => _controller.reverse());
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: _buildStickerContent(),
        ),
      ),
    );
  }

  Widget _buildStickerContent() {
    // TODO: Интеграция с Lottie
    // Сейчас используем простые эмодзи
    return Center(
      child: Text(
        _getEmojiForId(widget.stickerId),
        style: TextStyle(fontSize: widget.size * 0.8),
      ),
    );
  }

  String _getEmojiForId(String id) {
    // Маппинг ID на эмодзи (позже заменить на Lottie)
    const emojiMap = {
      'heart': '❤️',
      'fire': '🔥',
      'star': '⭐',
      'laugh': '😂',
      'love': '😍',
      'cool': '😎',
      'party': '🎉',
      'rocket': '🚀',
    };
    return emojiMap[id] ?? '😀';
  }
}

/// Панель выбора стикеров
class StickerPicker extends StatelessWidget {
  final ValueChanged<String> onStickerSelected;

  const StickerPicker({
    super.key,
    required this.onStickerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final stickers = [
      'heart',
      'fire',
      'star',
      'laugh',
      'love',
      'cool',
      'party',
      'rocket',
    ];

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Стикеры',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: stickers.length,
              itemBuilder: (context, index) {
                final stickerId = stickers[index];
                return AnimatedSticker(
                  stickerId: stickerId,
                  size: 60,
                  onTap: () => onStickerSelected(stickerId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Анимированная реакция (для сообщений)
class AnimatedReaction extends StatefulWidget {
  final String reaction;
  final VoidCallback? onComplete;

  const AnimatedReaction({
    super.key,
    required this.reaction,
    this.onComplete,
  });

  @override
  State<AnimatedReaction> createState() => _AnimatedReactionState();
}

class _AnimatedReactionState extends State<AnimatedReaction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _positionAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -30),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _positionAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Text(
        widget.reaction,
        style: const TextStyle(fontSize: 48),
      ),
    );
  }
}

/// Кастомный стикер-пак
class StickerPack {
  final String id;
  final String name;
  final String thumbnail;
  final List<String> stickerIds;
  final bool isPremium;

  const StickerPack({
    required this.id,
    required this.name,
    required this.thumbnail,
    required this.stickerIds,
    this.isPremium = false,
  });

  static List<StickerPack> get defaultPacks => [
        const StickerPack(
          id: 'emotions',
          name: 'Эмоции',
          thumbnail: '😀',
          stickerIds: ['laugh', 'love', 'cool'],
        ),
        const StickerPack(
          id: 'celebration',
          name: 'Праздник',
          thumbnail: '🎉',
          stickerIds: ['party', 'star', 'fire'],
        ),
        const StickerPack(
          id: 'actions',
          name: 'Действия',
          thumbnail: '👍',
          stickerIds: ['heart', 'rocket'],
          isPremium: true,
        ),
      ];
}

/// Менеджер стикеров
class StickerManager {
  static final StickerManager _instance = StickerManager._internal();
  factory StickerManager() => _instance;
  StickerManager._internal();

  final List<StickerPack> _installedPacks = StickerPack.defaultPacks;

  List<StickerPack> get installedPacks => _installedPacks;

  void installPack(StickerPack pack) {
    if (!_installedPacks.any((p) => p.id == pack.id)) {
      _installedPacks.add(pack);
    }
  }

  void uninstallPack(String packId) {
    _installedPacks.removeWhere((pack) => pack.id == packId);
  }

  StickerPack? getPackById(String id) {
    try {
      return _installedPacks.firstWhere((pack) => pack.id == id);
    } catch (e) {
      return null;
    }
  }
}
