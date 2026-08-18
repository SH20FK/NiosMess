import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/utils/file_opener.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/chat/ws_cached_image.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/voice_message_player.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class ProfileSharedMediaTabView extends ConsumerStatefulWidget {
  const ProfileSharedMediaTabView({
    required this.chatId,
    super.key,
  });

  final int? chatId;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllChatMedia();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileSharedMediaTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAllChatMedia();
      });
    }
  }

  Future<void> _loadAllChatMedia() async {
    final int? cid = widget.chatId;
    if (cid == null || cid <= 0) return;
    int added = 1;
    int iterations = 0;
    while (added > 0 && iterations < 15 && mounted) {
      iterations++;
      try {
        added = await ref
            .read(chatMessagesProvider(cid).notifier)
            .loadOlder(pageSize: 100);
      } catch (_) {
        break;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

        final isVideo = type.startsWith('video/') ||
            msgType.contains('video') ||
            name.endsWith('.mp4') ||
            name.endsWith('.mov') ||
            name.endsWith('.mkv') ||
            name.endsWith('.webm') ||
            urlLower.endsWith('.mp4') ||
            urlLower.endsWith('.mov') ||
            urlLower.endsWith('.webm') ||
            urlLower.endsWith('.mkv');

        final isPhoto = type.startsWith('image/') ||
            msgType.contains('image') ||
            msgType.contains('photo') ||
            name.endsWith('.jpg') ||
            name.endsWith('.jpeg') ||
            name.endsWith('.png') ||
            name.endsWith('.webp') ||
            name.endsWith('.gif') ||
            urlLower.endsWith('.jpg') ||
            urlLower.endsWith('.jpeg') ||
            urlLower.endsWith('.png') ||
            urlLower.endsWith('.webp') ||
            urlLower.endsWith('.gif') ||
            (!isVideo &&
                (msgType == 'media' ||
                    msgType == 'file' ||
                    msgType == 'document'));

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
    if (type.startsWith('image/') ||
        type.startsWith('video/') ||
        msgType.contains('image') ||
        msgType.contains('photo') ||
        msgType.contains('video') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif') ||
        name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm')) {
      return false;
    }
    return true;
  }

  bool _hasLink(ApiMessage m) {
    return _urlRegExp.hasMatch(m.content);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.chatId == null || widget.chatId! <= 0) {
      return _buildNoChatPlaceholder(scheme, textTheme);
    }

    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId!));

    return messagesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: AppLoadingIndicator(size: 32)),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Center(
          child: Text(
            'Не удалось загрузить медиафайлы',
            style: textTheme.bodyMedium?.copyWith(color: scheme.error),
          ),
        ),
      ),
      data: (messages) {
        final photosAndVideos = _extractPhotosAndVideos(messages);
        final voiceAndVideoNotes =
            messages.where(_isVoiceOrVideoNote).toList(growable: false);
        final files = messages.where(_isFile).toList(growable: false);
        final links = messages.where(_hasLink).toList(growable: false);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Material 3 Expressive Sticky Tab Bar (Scrollable to prevent clipping) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: scheme.onPrimary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                labelStyle: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                unselectedLabelStyle: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.photo_library_rounded, size: 16),
                    text: 'Медиа (${photosAndVideos.length})',
                    iconMargin: const EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: const Icon(Icons.mic_rounded, size: 16),
                    text: 'Голос (${voiceAndVideoNotes.length})',
                    iconMargin: const EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: const Icon(Icons.insert_drive_file_rounded, size: 16),
                    text: 'Файлы (${files.length})',
                    iconMargin: const EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: const Icon(Icons.link_rounded, size: 16),
                    text: 'Ссылки (${links.length})',
                    iconMargin: const EdgeInsets.only(bottom: 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tab Bar Views ─────────────────────────────────────────
            SizedBox(
              height: 420,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMediaGrid(photosAndVideos, scheme, textTheme),
                  _buildVoiceList(voiceAndVideoNotes, scheme, textTheme),
                  _buildFilesList(files, scheme, textTheme),
                  _buildLinksList(links, scheme, textTheme),
                ],
              ),
            ),
          ],
        );
      },
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

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final url = item.mediaUrl;
        final isVideo = item.isVideo;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            final typeParam = isVideo ? 'video' : 'image';
            final titleParam = Uri.encodeComponent(
              item.mediaName ?? (isVideo ? 'Видео' : 'Фото'),
            );
            context.push(
              '/media-viewer?url=${Uri.encodeComponent(url)}&type=$typeParam&title=$titleParam',
              extra: item.e2eeFileKey,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isVideo)
                  _MediaGridVideoThumbnail(
                    key: ValueKey('vid_$url'),
                    mediaUrl: url,
                    chatId: widget.chatId ?? 0,
                    isE2ee: item.message.isE2ee,
                    e2eeFileKey: item.e2eeFileKey,
                  )
                else
                  WsCachedImage(
                    key: ValueKey('img_$url'),
                    mediaUrl: url,
                    chatId: widget.chatId ?? 0,
                    isE2ee: item.message.isE2ee,
                    e2eeFileKey: item.e2eeFileKey,
                    fit: BoxFit.cover,
                    placeholder: (ctx) => Container(
                      color: scheme.surfaceContainerHigh,
                      child: const Center(child: AppLoadingIndicator(size: 20)),
                    ),
                    errorWidget: (ctx, err) => Container(
                      color: scheme.surfaceContainerHigh,
                      child: Icon(
                        Icons.image_rounded,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        size: 28,
                      ),
                    ),
                  ),
                if (isVideo)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
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
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          if (item.duration != null && item.duration! > 0)
                            Text(
                              _formatDuration(item.duration!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
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

class _MediaGridVideoThumbnail extends ConsumerStatefulWidget {
  const _MediaGridVideoThumbnail({
    required this.mediaUrl,
    required this.chatId,
    required this.isE2ee,
    this.e2eeFileKey,
    super.key,
  });

  final String mediaUrl;
  final int chatId;
  final bool isE2ee;
  final String? e2eeFileKey;

  @override
  ConsumerState<_MediaGridVideoThumbnail> createState() =>
      _MediaGridVideoThumbnailState();
}

class _MediaGridVideoThumbnailState
    extends ConsumerState<_MediaGridVideoThumbnail> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  @override
  void didUpdateWidget(covariant _MediaGridVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _disposeController();
      _initThumbnail();
    }
  }

  Future<void> _initThumbnail() async {
    try {
      final wsClient = ref.read(webSocketClientProvider);
      Uint8List? fileKey;
      if (widget.e2eeFileKey != null && widget.e2eeFileKey!.isNotEmpty) {
        fileKey = base64Decode(widget.e2eeFileKey!);
      }
      final String localPath = await WsMediaFetcher.fetchToLocalFile(
        filePath: widget.mediaUrl,
        wsClient: wsClient,
        e2eeFileKey: fileKey,
      );
      final controller = VideoPlayerController.file(File(localPath));
      await controller.initialize();
      await controller.seekTo(const Duration(milliseconds: 100));
      await controller.pause();
      if (mounted) {
        setState(() {
          _controller = controller;
          _initialized = true;
        });
      } else {
        controller.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = true);
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_error) {
      return Container(
        color: scheme.surfaceContainerHigh,
        child: Icon(
          Icons.videocam_rounded,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          size: 28,
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return Container(
        color: scheme.surfaceContainerHigh,
        child: const Center(child: AppLoadingIndicator(size: 20)),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _controller!.value.size.width > 0
            ? _controller!.value.size.width
            : 200,
        height: _controller!.value.size.height > 0
            ? _controller!.value.size.height
            : 200,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}
