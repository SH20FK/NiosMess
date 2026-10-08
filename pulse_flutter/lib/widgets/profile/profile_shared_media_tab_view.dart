import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/core/storage/chat_media_cache.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_opener.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/screens/media_viewer_screen.dart';
import 'package:pulse_flutter/widgets/chat/ws_cached_image.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/voice_message_player.dart';

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

class _CachedMediaExtraction {
  _CachedMediaExtraction({
    required this.sourceMessages,
    required this.photosAndVideos,
    required this.voiceAndVideoNotes,
    required this.files,
    required this.links,
  });

  final List<ApiMessage> sourceMessages;
  final List<_SharedMediaItem> photosAndVideos;
  final List<ApiMessage> voiceAndVideoNotes;
  final List<ApiMessage> files;
  final List<ApiMessage> links;
}

class _ProfileSharedMediaTabViewState
    extends ConsumerState<ProfileSharedMediaTabView> {
  int _selectedTabIndex = 0;

  static final RegExp _urlRegExp = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  static const int _kBatchSize = 12;
  bool _isHistoryLoading = false;
  final Set<int> _loadedGroups = <int>{};
  bool _isBatchProcessing = false;
  List<ApiMessage> _cachedMediaMessages = const <ApiMessage>[];
  _CachedMediaExtraction? _cachedExtraction;

  @override
  void initState() {
    super.initState();
    final int? cid = widget.chatId;
    if (cid != null && cid > 0) {
      _cachedMediaMessages = ChatMediaCache.getCachedMediaSync(cid);
    }
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
      _cachedExtraction = null;
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
    final bool autoAllowed = ref.read(autoDownloadAllowedProvider);
    if (!autoAllowed) return; // МЕД-4: respect auto download setting

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

          // Yield between groups to ensure smooth 60/120 FPS
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
      } finally {
        _isBatchProcessing = false;
      }
    });
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
      if (m.isSticker) continue;
      final raw = (m.mediaUrl ?? '').trim();
      if (raw.isEmpty) continue;
      final msgType = m.msgType.toLowerCase();
      if (msgType == 'sticker' ||
          msgType == 'voice' ||
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
    if (m.isSticker) return false;
    final msgType = m.msgType.toLowerCase();
    if (msgType == 'sticker') return false;
    final type = (m.mediaType ?? '').toLowerCase();
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
    if (m.isSticker) return false;
    final msgType = m.msgType.toLowerCase();
    if (msgType == 'sticker') return false;
    if ((m.mediaUrl ?? '').isEmpty) return false;
    if (_isVoiceOrVideoNote(m)) return false;
    final type = (m.mediaType ?? '').toLowerCase();
    final name = (m.mediaName ?? '').toLowerCase();
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

  _CachedMediaExtraction _getOrExtractMedia(List<ApiMessage> messages) {
    final cached = _cachedExtraction;
    if (cached != null && identical(cached.sourceMessages, messages)) {
      return cached;
    }
    if (cached != null &&
        cached.sourceMessages.length == messages.length &&
        (messages.isEmpty ||
            (cached.sourceMessages.first.id == messages.first.id &&
                cached.sourceMessages.last.id == messages.last.id))) {
      return cached;
    }

    final List<_SharedMediaItem> photosAndVideos =
        _extractPhotosAndVideos(messages);
    final List<ApiMessage> voiceAndVideoNotes =
        messages.where(_isVoiceOrVideoNote).toList(growable: false);
    final List<ApiMessage> files =
        messages.where(_isFile).toList(growable: false);
    final List<ApiMessage> links =
        messages.where(_hasLink).toList(growable: false);

    final extraction = _CachedMediaExtraction(
      sourceMessages: messages,
      photosAndVideos: photosAndVideos,
      voiceAndVideoNotes: voiceAndVideoNotes,
      files: files,
      links: links,
    );
    _cachedExtraction = extraction;
    return extraction;
  }

  Widget _buildContent(
    List<ApiMessage> messages,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final extraction = _getOrExtractMedia(messages);
    final photosAndVideos = extraction.photosAndVideos;
    final voiceAndVideoNotes = extraction.voiceAndVideoNotes;
    final files = extraction.files;
    final links = extraction.links;

    if (photosAndVideos.isNotEmpty && !_isBatchProcessing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startGroupedBatchPipeline(photosAndVideos);
      });
    }

    final Widget currentTabView;
    switch (_selectedTabIndex) {
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
          duration: M3Durations.short4,
          switchInCurve: M3SpringCurves.expressiveDecel,
          switchOutCurve: M3SpringCurves.expressiveAccel,
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: <Widget>[
                ...previousChildren,
                ?currentChild,
              ],
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedTabIndex),
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

    // МЕД-1: If chatId is null or <= 0, immediately show no chat placeholder (no eternal shimmer!)
    if (widget.chatId == null || widget.chatId! <= 0) {
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
                  context.l10n.sharedMediaLoadFailed,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (rowIndex) {
          return Padding(
            padding: EdgeInsets.only(bottom: rowIndex < 2 ? 6.0 : 0.0),
            child: Row(
              children: List.generate(3, (colIndex) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: colIndex < 2 ? 6.0 : 0.0),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
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
      (icon: Icons.photo_library_rounded, label: context.l10n.sharedMediaTabMedia, count: mediaCount),
      (icon: Icons.mic_rounded, label: context.l10n.sharedMediaTabVoice, count: voiceCount),
      (icon: Icons.insert_drive_file_rounded, label: context.l10n.sharedMediaTabFiles, count: filesCount),
      (icon: Icons.link_rounded, label: context.l10n.sharedMediaTabLinks, count: linksCount),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          final tab = tabs[index];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticService.selection();
                  setState(() => _selectedTabIndex = index);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: M3Durations.medium1,
                  curve: M3SpringCurves.spatial,
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
            context.l10n.sharedMediaNoMedia,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.sharedMediaStartDialogHint,
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
    HapticService.tap();

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

  // ── Tab 1: Photos & Videos Grid without shrinkWrap ────────────────
  Widget _buildMediaGrid(
    List<_SharedMediaItem> items,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        title: context.l10n.sharedMediaNoPhotosVideos,
        subtitle: context.l10n.sharedMediaNoPhotosVideosSub,
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

        final int totalItems = items.length;
        final int rowCount = (totalItems / crossAxisCount).ceil();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(rowCount, (rowIndex) {
              final int startIdx = rowIndex * crossAxisCount;
              return Padding(
                padding: EdgeInsets.only(bottom: rowIndex < rowCount - 1 ? 6.0 : 0.0),
                child: Row(
                  children: List.generate(crossAxisCount, (colIndex) {
                    final int itemIndex = startIdx + colIndex;
                    if (itemIndex >= totalItems) {
                      return const Expanded(child: SizedBox());
                    }
                    final item = items[itemIndex];
                    final url = item.mediaUrl;
                    final isVideo = item.isVideo;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: colIndex < crossAxisCount - 1 ? 6.0 : 0.0,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: RepaintBoundary(
                            child: _MediaGridTileWrapper(
                              onTap: () => _openGallery(itemIndex, items),
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
                                        ),
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
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ── Tab 2: Voice & Video Notes without shrinkWrap ─────────────────
  Widget _buildVoiceList(
    List<ApiMessage> items,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mic_none_rounded,
        title: context.l10n.sharedMediaNoVoice,
        subtitle: context.l10n.sharedMediaNoVoiceSub,
        scheme: scheme,
        textTheme: textTheme,
      );
    }

    final String locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (index) {
          final m = items[index];
          final isRoundVideo = m.msgType == 'circle_video' ||
              m.msgType == 'video_note' ||
              m.msgType == 'round_video';

          final Widget itemWidget;
          if (isRoundVideo) {
            final dateText = DateFormat('d MMM, HH:mm', locale).format(m.sentAt);
            final durationText = (m.mediaDuration != null && m.mediaDuration! > 0)
                ? ' (${_formatDuration(m.mediaDuration!)})'
                : '';

            itemWidget = Container(
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
                          '${context.l10n.sharedMediaVideoMessage}$durationText',
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
                      HapticService.tap();
                      if ((m.mediaUrl ?? '').isNotEmpty) {
                        context.push(
                          '/media-viewer?url=${Uri.encodeComponent(m.mediaUrl!)}&type=video&title=${Uri.encodeComponent(context.l10n.sharedMediaVideoMessage)}',
                          extra: <String, dynamic>{
                            'playlist': <MediaViewerItem>[
                              MediaViewerItem(
                                url: m.mediaUrl!,
                                mediaType: MediaType.video,
                                title: context.l10n.sharedMediaVideoMessage,
                                e2eeFileKey: m.e2eeFileKey,
                              ),
                            ],
                            'initialIndex': 0,
                            'e2eeKey': m.e2eeFileKey,
                          },
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          } else {
            // Voice Message
            itemWidget = Container(
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
                        DateFormat('d MMMM, HH:mm', locale).format(m.sentAt),
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
                    durationSeconds: m.mediaDuration ?? 0,
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
          }

          return Padding(
            padding: EdgeInsets.only(bottom: index < items.length - 1 ? 10.0 : 0.0),
            child: itemWidget,
          );
        }),
      ),
    );
  }

  // ── Tab 3: Files & Documents without shrinkWrap ───────────────────
  Widget _buildFilesList(
    List<ApiMessage> items,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.insert_drive_file_outlined,
        title: context.l10n.sharedMediaNoFiles,
        subtitle: context.l10n.sharedMediaNoFilesSub,
        scheme: scheme,
        textTheme: textTheme,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index < items.length - 1 ? 10.0 : 0.0),
            child: _SharedFileTile(
              message: items[index],
              chatId: widget.chatId ?? 0,
            ),
          );
        }),
      ),
    );
  }

  // ── Tab 4: Links List without shrinkWrap ──────────────────────────
  Widget _buildLinksList(
    List<ApiMessage> items,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.link_rounded,
        title: context.l10n.sharedMediaNoLinks,
        subtitle: context.l10n.sharedMediaNoLinksSub,
        scheme: scheme,
        textTheme: textTheme,
      );
    }

    final String locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (index) {
          final m = items[index];
          final match = _urlRegExp.firstMatch(m.content);
          final url = match?.group(0) ?? '';
          final domain = Uri.tryParse(url)?.host ?? url;
          final dateText = DateFormat('d MMM, HH:mm', locale).format(m.sentAt);

          return Padding(
            padding: EdgeInsets.only(bottom: index < items.length - 1 ? 10.0 : 0.0),
            child: InkWell(
              onTap: () {
                HapticService.tap();
                if (url.isNotEmpty) {
                  AppUrlLauncher.openUrl(context, url);
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
            ),
          );
        }),
      ),
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
  String? _localPath;

  Future<void> _startDownload() async {
    if (_isDownloading) return;
    final fileName = widget.message.mediaName ?? context.l10n.sharedMediaFile;
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
    });

    try {
      final wsClient = ref.read(webSocketClientProvider);
      Uint8List? fileKey;
      if (widget.message.e2eeFileKey != null &&
          widget.message.e2eeFileKey!.isNotEmpty) {
        fileKey = base64Decode(widget.message.e2eeFileKey!);
      }

      final localPath = await WsMediaFetcher.fetchToLocalFile(
        filePath: url,
        wsClient: wsClient,
        e2eeFileKey: fileKey,
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _localPath = localPath;
        });

        HapticService.confirm();
        FileOpener.openFile(
          context: context,
          filePath: localPath,
          fileName: fileName,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        AppToast.showError(context, context.l10n.sharedMediaFileDownloadError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final m = widget.message;
    final name = m.mediaName ?? context.l10n.sharedMediaFile;
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';
    final sizeText = m.mediaSize != null
        ? FileTypeDetector.formatFileSize(m.mediaSize!)
        : '';
    final String locale = Localizations.localeOf(context).toString();
    final dateText = DateFormat('d MMM, HH:mm', locale).format(m.sentAt);

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
            const SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: AppLoadingIndicator(size: 22),
              ),
            )
          else if (_localPath != null)
            IconButton.filledTonal(
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              tooltip: context.l10n.sharedMediaOpenFile,
              onPressed: () => FileOpener.openFile(
                context: context,
                filePath: _localPath!,
                fileName: name,
              ),
            )
          else
            IconButton.filledTonal(
              icon: const Icon(Icons.download_rounded, size: 20),
              tooltip: context.l10n.sharedMediaDownloadFile,
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

  String _formatBadge(_SharedMediaItem item) {
    final String target = item.mediaName ?? item.mediaUrl;
    final int dot = target.lastIndexOf('.');
    if (dot != -1 && dot < target.length - 1) {
      final String raw = target.substring(dot + 1).split('?').first.toUpperCase();
      if (raw.isNotEmpty && raw.length <= 4) {
        return raw;
      }
    }
    return 'VIDEO';
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
                color: scheme.scrim.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: scheme.onSurface,
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
                color: scheme.scrim.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatBadge(item),
                    style: TextStyle(
                      color: scheme.onSurface,
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
                    scheme.scrim.withValues(alpha: 0.75),
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
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item.duration != null && item.duration! > 0)
                    Text(
                      _formatDuration(item.duration!),
                      style: TextStyle(
                        color: scheme.onSurface,
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

class _MediaGridTileWrapper extends StatelessWidget {
  const _MediaGridTileWrapper({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TouchContainer(
      onTap: onTap,
      child: child,
    );
  }
}
