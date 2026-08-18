import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/utils/file_opener.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

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

  bool _isPhotoOrVideo(ApiMessage m) {
    if ((m.mediaUrl ?? '').isEmpty) return false;
    final type = (m.mediaType ?? '').toLowerCase();
    final name = (m.mediaName ?? '').toLowerCase();
    final msgType = m.msgType.toLowerCase();

    if (msgType == 'voice' ||
        msgType == 'circle_video' ||
        msgType == 'video_note' ||
        type.startsWith('audio/')) {
      return false;
    }

    return type.startsWith('image/') ||
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
        name.endsWith('.webm');
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
    if (_isPhotoOrVideo(m)) return false;
    if (_isVoiceOrVideoNote(m)) return false;
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
        final photosAndVideos =
            messages.where(_isPhotoOrVideo).toList(growable: false);
        final voiceAndVideoNotes =
            messages.where(_isVoiceOrVideoNote).toList(growable: false);
        final files = messages.where(_isFile).toList(growable: false);
        final links = messages.where(_hasLink).toList(growable: false);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Material 3 Expressive Sticky Tab Bar ─────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
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
                  Tab(text: 'Медиа (${photosAndVideos.length})'),
                  Tab(text: 'Голос (${voiceAndVideoNotes.length})'),
                  Tab(text: 'Файлы (${files.length})'),
                  Tab(text: 'Ссылки (${links.length})'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tab Bar Views ─────────────────────────────────────────
            SizedBox(
              height: 380,
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

  // ── Tab 1: Photos & Videos Grid ───────────────────────────────────
  Widget _buildMediaGrid(
    List<ApiMessage> items,
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
        final m = items[index];
        final isVideo = (m.mediaType ?? '').toLowerCase().startsWith('video/') ||
            (m.mediaName ?? '').toLowerCase().endsWith('.mp4');
        final url = m.mediaUrl ?? '';

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            final typeParam = isVideo ? 'video' : 'image';
            final titleParam = Uri.encodeComponent(m.mediaName ?? 'Media');
            context.push(
              '/media-viewer?url=${Uri.encodeComponent(url)}&type=$typeParam&title=$titleParam',
              extra: m.e2eeFileKey,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, error, stackTrace) => Container(
                    color: scheme.surfaceContainerHigh,
                    child: Icon(
                      isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 28,
                    ),
                  ),
                ),
                if (isVideo)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          if (m.mediaDuration != null && m.mediaDuration! > 0) ...[
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(m.mediaDuration!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

  // ── Tab 2: Voice & Video Notes List ───────────────────────────────
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
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = items[index];
        final isRoundVideo = m.msgType == 'circle_video' ||
            m.msgType == 'video_note' ||
            m.msgType == 'round_video';
        final durationText = m.mediaDuration != null
            ? _formatDuration(m.mediaDuration!)
            : '0:30';
        final dateText = DateFormat('d MMM, HH:mm').format(m.sentAt);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              M3Container(
                isRoundVideo ? Shapes.circle : Shapes.c9_sided_cookie,
                width: 44,
                height: 44,
                color: scheme.primaryContainer,
                child: Center(
                  child: Icon(
                    isRoundVideo
                        ? Icons.videocam_rounded
                        : Icons.graphic_eq_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRoundVideo
                          ? 'Видеосообщение'
                          : 'Голосовое сообщение ($durationText)',
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
                    final typeParam = isRoundVideo ? 'video' : 'other';
                    context.push(
                      '/media-viewer?url=${Uri.encodeComponent(m.mediaUrl!)}&type=$typeParam&title=${Uri.encodeComponent(isRoundVideo ? "Видеосообщение" : "Аудиозапись")}',
                      extra: m.e2eeFileKey,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 3: Files & Documents List ─────────────────────────────────
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
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = items[index];
        final name = m.mediaName ?? 'Документ';
        final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';
        final sizeText = m.mediaSize != null
            ? FileTypeDetector.formatFileSize(m.mediaSize!)
            : '';
        final dateText = DateFormat('d MMM, HH:mm').format(m.sentAt);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              M3Container(
                Shapes.c4_sided_cookie,
                width: 44,
                height: 44,
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
              const SizedBox(width: 12),
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
              IconButton.filledTonal(
                icon: const Icon(Icons.download_rounded, size: 20),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if ((m.mediaUrl ?? '').isNotEmpty) {
                    FileOpener.openUrl(context, m.mediaUrl!);
                  }
                },
              ),
            ],
          ),
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
      separatorBuilder: (context, index) => const SizedBox(height: 8),
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
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.16),
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
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
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
