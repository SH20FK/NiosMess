import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/storage/chat_media_cache.dart';
import 'package:pulse_flutter/core/utils/file_opener.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/screens/media_viewer_screen.dart';
import 'package:pulse_flutter/widgets/chat/ws_cached_image.dart';
import 'package:pulse_flutter/widgets/voice_message_player.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSharedMediaTabView extends ConsumerStatefulWidget {
  const ProfileSharedMediaTabView({
    required this.chatId,
    super.key,
  });

  final int? chatId;

  static bool isPureImage(
    String type,
    String msgType,
    String name,
    String urlLower,
  ) =>
      _ProfileSharedMediaTabViewState._isPureImage(
        type,
        msgType,
        name,
        urlLower,
      );

  static bool isPureVideo(
    String type,
    String msgType,
    String name,
    String urlLower,
  ) =>
      _ProfileSharedMediaTabViewState._isPureVideo(
        type,
        msgType,
        name,
        urlLower,
      );

  @override
  ConsumerState<ProfileSharedMediaTabView> createState() =>
      _ProfileSharedMediaTabViewState();
}

class _ProfileSharedMediaTabViewState
    extends ConsumerState<ProfileSharedMediaTabView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static final RegExp _urlRegExp = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  static const int _kBatchSize = 12;
  bool _isHistoryLoading = false;
  final Set<int> _loadedGroups = <int>{};
  bool _isBatchProcessing = false;
  List<ApiMessage> _cachedMediaMessages = const <ApiMessage>[];

  @override
  void initState() {
    super.initState();
    final int? cid = widget.chatId;
    if (cid != null && cid > 0) {
      _cachedMediaMessages = ChatMediaCache.getCachedMediaSync(cid);
    }
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllChatMedia();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileSharedMediaTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId) {
      final int? cid = widget.chatId;
      if (cid != null && cid > 0) {
        _cachedMediaMessages = ChatMediaCache.getCachedMediaSync(cid);
      } else {
        _cachedMediaMessages = const <ApiMessage>[];
      }
      _loadedGroups.clear();
      _isBatchProcessing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAllChatMedia();
      });
    }
  }

  Future<void> _loadAllChatMedia() async {
    final int? cid = widget.chatId;
    if (cid == null || cid <= 0 || _isHistoryLoading) return;
    _isHistoryLoading = true;

    try {
      // 1. Instantly check local persistent cache to display existing media in ~0-2ms
      try {
        final List<ApiMessage> cached = await ChatMediaCache.getCachedMedia(cid);
        if (cached.isNotEmpty && mounted) {
          setState(() {
            _cachedMediaMessages = cached;
          });
          final List<_SharedMediaItem> cachedMedia = _extractPhotosAndVideos(cached);
          if (cachedMedia.isNotEmpty) {
            _startGroupedBatchPipeline(cachedMedia);
          }
        }
      } catch (_) {}

      // 2. Fetch full history batch in 1 single WebSocket roundtrip (up to 300 messages)
      final int added = await ref
          .read(chatMessagesProvider(cid).notifier)
          .loadOlder(pageSize: 300);

      if (mounted) {
        final List<ApiMessage> messages =
            ref.read(chatMessagesProvider(cid)).value ?? const <ApiMessage>[];
        await ChatMediaCache.saveMediaMessages(cid, messages);
        final List<ApiMessage> updated = await ChatMediaCache.getCachedMedia(cid);
        if (mounted) {
          setState(() {
            _cachedMediaMessages = updated;
          });
          final List<_SharedMediaItem> allMedia = _extractPhotosAndVideos(updated);
          _startGroupedBatchPipeline(allMedia);
        }
      }

      // 3. If there are 280+ messages (full page), eagerly fetch another 300 older in the background
      if (added >= 280 && mounted) {
        await ref
            .read(chatMessagesProvider(cid).notifier)
            .loadOlder(pageSize: 300);
        if (mounted) {
          final List<ApiMessage> messages =
              ref.read(chatMessagesProvider(cid)).value ?? const <ApiMessage>[];
          await ChatMediaCache.saveMediaMessages(cid, messages);
          final List<ApiMessage> updated = await ChatMediaCache.getCachedMedia(cid);
          if (mounted) {
            setState(() {
              _cachedMediaMessages = updated;
            });
            final List<_SharedMediaItem> allMedia = _extractPhotosAndVideos(updated);
            _startGroupedBatchPipeline(allMedia);
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isHistoryLoading = false;
        });
      }
    }
  }

  void _startGroupedBatchPipeline(List<_SharedMediaItem> media) {
    if (media.isEmpty || _isBatchProcessing) return;
    _isBatchProcessing = true;

    Future<void>.microtask(() async {
      try {
        final int totalGroups = (media.length / _kBatchSize).ceil();
        final wsClient = ref.read(webSocketClientProvider);

        for (int g = 0; g < totalGroups; g++) {
          if (!mounted) break;
          if (_loadedGroups.contains(g)) continue;

          final int start = g * _kBatchSize;
          final int end = (start + _kBatchSize).clamp(0, media.length);

          final List<String> groupPaths = <String>[];
          final Map<String, Uint8List?> groupKeys = <String, Uint8List?>{};

          for (int i = start; i < end; i++) {
            final item = media[i];
            if (!item.isVideo && item.mediaUrl.isNotEmpty) {
              groupPaths.add(item.mediaUrl);
              if (item.e2eeFileKey != null && item.e2eeFileKey!.isNotEmpty) {
                try {
                  groupKeys[item.mediaUrl] = base64Decode(item.e2eeFileKey!);
                } catch (_) {}
              }
            }
          }

          if (groupPaths.isNotEmpty) {
            await WsMediaFetcher.prefetchBatch(
              filePaths: groupPaths,
              wsClient: wsClient,
              e2eeFileKeys: groupKeys,
              concurrency: 8,
            );
          }

          _loadedGroups.add(g);
          if (mounted) {
            setState(() {});
          }

          // Small 16ms yield between groups to ensure 120 FPS frame budget
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
      } finally {
        _isBatchProcessing = false;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static bool _isPureImage(
    String type,
    String msgType,
    String name,
    String urlLower,
  ) =>
      FileTypeDetector.isPureImage(
        mediaType: type,
        msgType: msgType,
        fileName: name,
        url: urlLower,
      );

  static bool _isPureVideo(
    String type,
    String msgType,
    String name,
    String urlLower,
  ) =>
      FileTypeDetector.isPureVideo(
        mediaType: type,
        msgType: msgType,
        fileName: name,
        url: urlLower,
      );

  List<_SharedMediaItem> _extractPhotosAndVideos(List<ApiMessage> messages) {
    final List<_SharedMediaItem> list = <_SharedMediaItem>[];
    for (final m in messages) {
      final raw = (m.mediaUrl ?? '').trim();
      if (raw.isEmpty) continue;
      final msgType = m.msgType.toLowerCase();
      if (msgType == 'voice' ||
          msgType == 'circle_video' ||
          msgType == 'video_note' ||
          msgType == 'round_video') {
        continue;
      }
      final urls = raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      for (final url in urls) {
        final type = (m.mediaType ?? '').toLowerCase();
        final name = (m.mediaName ?? '').toLowerCase();
        final urlLower = url.toLowerCase();

        final bool isVideo = _isPureVideo(type, msgType, name, urlLower);
        final bool isPhoto = !isVideo && _isPureImage(type, msgType, name, urlLower);

        if (isVideo || isPhoto) {
          list.add(
            _SharedMediaItem(
              message: m,
              mediaUrl: url,
              isVideo: isVideo,
              e2eeFileKey: m.e2eeFileKey,
              duration: m.mediaDuration,
              mediaName: m.mediaName,
            ),
          );
        }
      }
    }
    return list;
  }

  bool _isVoiceOrVideoNote(ApiMessage m) {
    final type = (m.mediaType ?? '').toLowerCase();
    final msgType = m.msgType.toLowerCase();
    final name = (m.mediaName ?? '').toLowerCase();

    return msgType == 'voice' ||
        msgType == 'circle_video' ||
        msgType == 'video_note' ||
        msgType == 'round_video' ||
        type.startsWith('audio/') ||
        name.endsWith('.ogg') ||
        name.endsWith('.mp3') ||
        name.endsWith('.m4a') ||
        name.endsWith('.opus');
  }

  bool _isFile(ApiMessage m) {
    if ((m.mediaUrl ?? '').isEmpty) return false;
    if (_isVoiceOrVideoNote(m)) return false;
    final type = (m.mediaType ?? '').toLowerCase();
    final name = (m.mediaName ?? '').toLowerCase();
    final msgType = m.msgType.toLowerCase();
    final urlLower = (m.mediaUrl ?? '').toLowerCase();

    // If it is pure image or pure video, it belongs in Media tab, not in Files tab
    if (_isPureImage(type, msgType, name, urlLower) ||
        _isPureVideo(type, msgType, name, urlLower)) {
      return false;
    }
    return true;
  }

  bool _hasLink(ApiMessage m) {
    return _urlRegExp.hasMatch(m.content);
  }

  Widget _buildContent(
    List<ApiMessage> messages,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final List<_SharedMediaItem> photosAndVideos = _extractPhotosAndVideos(messages);
    final List<ApiMessage> voiceAndVideoNotes =
        messages.where(_isVoiceOrVideoNote).toList(growable: false);
    final List<ApiMessage> files = messages.where(_isFile).toList(growable: false);
    final List<ApiMessage> links = messages.where(_hasLink).toList(growable: false);

    if (photosAndVideos.isNotEmpty && !_isBatchProcessing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startGroupedBatchPipeline(photosAndVideos);
      });
    }

    final Widget currentTabView;
    switch (_tabController.index) {
      case 0:
        currentTabView = _buildMediaGrid(photosAndVideos, scheme, textTheme);
        break;
      case 1:
        currentTabView = _buildVoiceList(voiceAndVideoNotes, scheme, textTheme);
        break;
      case 2:
        currentTabView = _buildFilesList(files, scheme, textTheme);
        break;
      case 3:
        currentTabView = _buildLinksList(links, scheme, textTheme);
        break;
      default:
        currentTabView = _buildMediaGrid(photosAndVideos, scheme, textTheme);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ── Material 3 Expressive Horizontal Pill Bar ──
        _buildPillBar(
          scheme: scheme,
          textTheme: textTheme,
          mediaCount: photosAndVideos.length,
          voiceCount: voiceAndVideoNotes.length,
          filesCount: files.length,
          linksCount: links.length,
        ),
        const SizedBox(height: 12),

        // ── Active Tab View with Smooth Transition (Unified Scrolling) ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: M3SpringCurves.snappy,
          switchOutCurve: Curves.easeInQuad,
          child: KeyedSubtree(
            key: ValueKey<int>(_tabController.index),
            child: currentTabView,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    if (widget.chatId == null) {
      // While resolving the chatId, show an elegant shimmer grid rather than empty placeholder
      return _buildShimmerGrid(scheme);
    }
    if (widget.chatId! <= 0) {
      return _buildNoChatPlaceholder(scheme, textTheme);
    }

    final AsyncValue<List<ApiMessage>> messagesAsync =
        ref.watch(chatMessagesProvider(widget.chatId!));

    return messagesAsync.when(
      loading: () => _cachedMediaMessages.isNotEmpty
          ? _buildContent(_cachedMediaMessages, scheme, textTheme)
          : _buildShimmerGrid(scheme),
      error: (Object err, StackTrace? _) => _cachedMediaMessages.isNotEmpty
          ? _buildContent(_cachedMediaMessages, scheme, textTheme)
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Center(
                child: Text(
                  'Не удалось загрузить медиафайлы',
                  style: textTheme.bodyMedium?.copyWith(color: scheme.error),
                ),
              ),
            ),
      data: (List<ApiMessage> messages) {
        final Map<int, ApiMessage> byId = <int, ApiMessage>{};
        for (final ApiMessage m in _cachedMediaMessages) {
          byId[m.id] = m;
        }
        for (final ApiMessage m in messages) {
          if (ChatMediaCache.isMediaMessage(m)) {
            byId[m.id] = m;
          }
        }
        final List<ApiMessage> allMessages = byId.values.toList()
          ..sort((ApiMessage a, ApiMessage b) => b.sentAt.compareTo(a.sentAt));

        return _buildContent(allMessages, scheme, textTheme);
      },
    );
  }

  Widget _buildShimmerGrid(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.0,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fade(begin: 0.4, end: 0.85, duration: 800.ms);
        },
      ),
    );
  }

  Widget _buildPillBar({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required int mediaCount,
    required int voiceCount,
    required int filesCount,
    required int linksCount,
  }) {
    final tabs = [
      (icon: Icons.photo_library_rounded, label: 'Медиа', count: mediaCount),
      (icon: Icons.mic_rounded, label: 'Голосовые', count: voiceCount),
      (icon: Icons.insert_drive_file_rounded, label: 'Файлы', count: filesCount),
      (icon: Icons.link_rounded, label: 'Ссылки', count: linksCount),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (index) {
          final isSelected = _tabController.index == index;
          final tab = tabs[index];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _tabController.animateTo(index);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary.withValues(alpha: 0.28)
                          : scheme.outlineVariant.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 17,
                        color: isSelected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.label,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 13,
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      if (tab.count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.primary.withValues(alpha: 0.18)
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${tab.count}',
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: isSelected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNoChatPlaceholder(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.perm_media_outlined,
            size: 40,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'Медиафайлы отсутствуют',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Начните диалог, чтобы обмениваться фотографиями, голосовыми сообщениями и файлами.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _openGallery(int initialIndex, List<_SharedMediaItem> allItems) {
    if (initialIndex < 0 || initialIndex >= allItems.length) return;
    HapticFeedback.lightImpact();

    final List<MediaViewerItem> playlist = allItems.map((item) {
      return MediaViewerItem(
        url: item.mediaUrl,
        mediaType: item.isVideo ? MediaType.video : MediaType.image,
        title: item.mediaName ?? (item.isVideo ? 'Видео' : 'Фото'),
        e2eeFileKey: item.e2eeFileKey,
        mediaName: item.mediaName,
      );
    }).toList(growable: false);

    final _SharedMediaItem current = allItems[initialIndex];
    final String typeParam = current.isVideo ? 'video' : 'image';
    final String titleParam = Uri.encodeComponent(
      current.mediaName ?? (current.isVideo ? 'Видео' : 'Фото'),
    );

    context.push(
      '/media-viewer?url=${Uri.encodeComponent(current.mediaUrl)}&type=$typeParam&title=$titleParam',
      extra: <String, dynamic>{
        'playlist': playlist,
        'initialIndex': initialIndex,
        'e2eeKey': current.e2eeFileKey,
      },
    );
  }

  // ── Tab 1: Photos & Videos Grid with Decryption & Caching ──────────
  Widget _buildMediaGrid(
    List<_SharedMediaItem> items,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Нет фото и видео',
        subtitle: 'Отправленные в чат изображения и видео появятся здесь',
        scheme: scheme,
        textTheme: textTheme,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width > 1050
            ? 6
            : width > 750
                ? 5
                : width > 480
                    ? 4
                    : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final url = item.mediaUrl;
            final isVideo = item.isVideo;

            return RepaintBoundary(
              child: _MediaGridTileWrapper(
                onTap: () => _openGallery(index, items),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: isVideo
                      ? _SharedMediaVideoTile(
                          item: item,
                          scheme: scheme,
                          textTheme: textTheme,
                        )
                      : WsCachedImage(
                          key: ValueKey('img_$url'),
                          mediaUrl: url,
                          chatId: widget.chatId ?? 0,
                          isE2ee: item.message.isE2ee,
                          e2eeFileKey: item.e2eeFileKey,
                          memCacheWidth: 280,
                          memCacheHeight: 280,
                          fit: BoxFit.cover,
                          placeholder: (ctx) => Container(
                            color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                            child: Center(
                              child: Icon(
                                Icons.photo_outlined,
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                                size: 24,
                              ),
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .fade(begin: 0.45, end: 0.85, duration: 750.ms),
                          errorWidget: (ctx, err) => Container(
                            color: scheme.surfaceContainerHigh,
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                              size: 28,
                            ),
                          ),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Tab 2: Voice & Video Notes with Working Player ─────────────────
  Widget _buildVoiceList(
    List<ApiMessage> items,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mic_none_rounded,
        title: 'Нет голосовых сообщений',
        subtitle: 'Голосовые и видео-кружки появятся здесь',
        scheme: scheme,
        textTheme: textTheme,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final m = items[index];
        final isRoundVideo = m.msgType == 'circle_video' ||
            m.msgType == 'video_note' ||
            m.msgType == 'round_video';

        if (isRoundVideo) {
          final dateText = DateFormat('d MMM, HH:mm').format(m.sentAt);
          final durationText = m.mediaDuration != null
              ? _formatDuration(m.mediaDuration!)
              : '0:30';

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                M3Container(
                  Shapes.circle,
                  width: 46,
                  height: 46,
                  color: scheme.primaryContainer,
                  child: Center(
                    child: Icon(
                      Icons.videocam_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Видеосообщение ($durationText)',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateText,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if ((m.mediaUrl ?? '').isNotEmpty) {
                      context.push(
                        '/media-viewer?url=${Uri.encodeComponent(m.mediaUrl!)}&type=video&title=${Uri.encodeComponent("Видеосообщение")}',
                        extra: m.e2eeFileKey,
                      );
                    }
                  },
                ),
              ],
            ),
          );
        }

        // Voice Message with Audio Player
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mic_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('d MMMM, HH:mm').format(m.sentAt),
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              VoiceMessagePlayer(
                audioUrl: m.mediaUrl ?? '',
                durationSeconds: m.mediaDuration ?? 30,
                isMine: false,
                scheme: scheme,
                chatId: widget.chatId ?? 0,
                wsClient: ref.read(webSocketClientProvider),
                e2eeFileKey: m.e2eeFileKey,
                isE2ee: m.isE2ee,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 3: Files & Documents with Telegram-style Download ──────────
  Widget _buildFilesList(
    List<ApiMessage> items,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.insert_drive_file_outlined,
        title: 'Нет файлов',
        subtitle: 'Документы, архивы и файлы появятся здесь',
        scheme: scheme,
        textTheme: textTheme,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _SharedFileTile(
          message: items[index],
          chatId: widget.chatId ?? 0,
        );
      },
    );
  }

  // ── Tab 4: Links List ─────────────────────────────────────────────
  Widget _buildLinksList(
    List<ApiMessage> items,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.link_rounded,
        title: 'Нет ссылок',
        subtitle: 'Ссылки из переписки будут отображаться здесь',
        scheme: scheme,
        textTheme: textTheme,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final m = items[index];
        final match = _urlRegExp.firstMatch(m.content);
        final url = match?.group(0) ?? '';
        final domain = Uri.tryParse(url)?.host ?? url;
        final dateText = DateFormat('d MMM, HH:mm').format(m.sentAt);

        return InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            final uri = Uri.tryParse(url);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                M3Container(
                  Shapes.c9_sided_cookie,
                  width: 44,
                  height: 44,
                  color: scheme.tertiaryContainer,
                  child: Center(
                    child: Icon(
                      Icons.link_rounded,
                      color: scheme.onTertiaryContainer,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain.isEmpty ? url : domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateText,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 250.ms);
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _SharedFileTile extends ConsumerStatefulWidget {
  const _SharedFileTile({
    required this.message,
    required this.chatId,
  });

  final ApiMessage message;
  final int chatId;

  @override
  ConsumerState<_SharedFileTile> createState() => _SharedFileTileState();
}

class _SharedFileTileState extends ConsumerState<_SharedFileTile> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _localPath;

  Future<void> _startDownload() async {
    if (_isDownloading) return;
    final fileName = widget.message.mediaName ?? 'Документ';
    if (_localPath != null) {
      FileOpener.openFile(
        context: context,
        filePath: _localPath!,
        fileName: fileName,
      );
      return;
    }

    final url = widget.message.mediaUrl ?? '';
    if (url.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _progress = 0.05;
    });

    try {
      final wsClient = ref.read(webSocketClientProvider);
      Uint8List? fileKey;
      if (widget.message.e2eeFileKey != null &&
          widget.message.e2eeFileKey!.isNotEmpty) {
        fileKey = base64Decode(widget.message.e2eeFileKey!);
      }

      // Smooth simulated progress while download stream progresses
      for (double p = 0.15; p <= 0.85; p += 0.15) {
        if (!mounted || !_isDownloading) break;
        await Future.delayed(const Duration(milliseconds: 120));
        if (mounted) setState(() => _progress = p);
      }

      final localPath = await WsMediaFetcher.fetchToLocalFile(
        filePath: url,
        wsClient: wsClient,
        e2eeFileKey: fileKey,
      );

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _isDownloading = false;
          _localPath = localPath;
        });

        HapticFeedback.mediumImpact();
        FileOpener.openFile(
          context: context,
          filePath: localPath,
          fileName: fileName,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка скачивания файла: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final m = widget.message;
    final name = m.mediaName ?? 'Документ';
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';
    final sizeText = m.mediaSize != null
        ? FileTypeDetector.formatFileSize(m.mediaSize!)
        : '';
    final dateText = DateFormat('d MMM, HH:mm').format(m.sentAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          M3Container(
            Shapes.c4_sided_cookie,
            width: 46,
            height: 46,
            color: scheme.secondaryContainer,
            child: Center(
              child: Text(
                ext.length > 4 ? ext.substring(0, 4) : ext,
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sizeText • $dateText',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_isDownloading)
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    strokeWidth: 3,
                    color: scheme.primary,
                    backgroundColor: scheme.primary.withValues(alpha: 0.2),
                  ),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            )
          else if (_localPath != null)
            IconButton.filledTonal(
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              tooltip: 'Открыть файл',
              onPressed: () => FileOpener.openFile(
                context: context,
                filePath: _localPath!,
                fileName: name,
              ),
            )
          else
            IconButton.filledTonal(
              icon: const Icon(Icons.download_rounded, size: 20),
              tooltip: 'Скачать файл',
              onPressed: _startDownload,
            ),
        ],
      ),
    );
  }
}

class _SharedMediaItem {
  const _SharedMediaItem({
    required this.message,
    required this.mediaUrl,
    required this.isVideo,
    this.e2eeFileKey,
    this.duration,
    this.mediaName,
  });

  final ApiMessage message;
  final String mediaUrl;
  final bool isVideo;
  final String? e2eeFileKey;
  final int? duration;
  final String? mediaName;
}

class _SharedMediaVideoTile extends StatelessWidget {
  const _SharedMediaVideoTile({
    required this.item,
    required this.scheme,
    required this.textTheme,
  });

  final _SharedMediaItem item;
  final ColorScheme scheme;
  final TextTheme textTheme;

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerLowest,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_rounded,
                    color: Colors.white70,
                    size: 12,
                  ),
                  SizedBox(width: 3),
                  Text(
                    'MP4',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.mediaName ?? 'Видео',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item.duration != null && item.duration! > 0)
                    Text(
                      _formatDuration(item.duration!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaGridTileWrapper extends StatefulWidget {
  const _MediaGridTileWrapper({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_MediaGridTileWrapper> createState() => _MediaGridTileWrapperState();
}

class _MediaGridTileWrapperState extends State<_MediaGridTileWrapper> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: _isPressed ? M3SpringCurves.snappy : M3SpringCurves.bouncy,
          child: widget.child,
        ),
      ),
    );
  }
}
