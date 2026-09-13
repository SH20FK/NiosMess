import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/utils/app_error_formatter.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/docx_parser.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

class NativeFileViewerScreen extends ConsumerStatefulWidget {
  const NativeFileViewerScreen({
    required this.fileName,
    required this.fileType,
    this.url,
    this.localPath,
    this.bytes,
    this.e2eeFileKey,
    super.key,
  });

  final String fileName;
  final FileTypeInfo fileType;
  final String? url;
  final String? localPath;
  final Uint8List? bytes;

  /// Base64 per-file AES key for E2EE media (secret chats).
  final String? e2eeFileKey;

  @override
  ConsumerState<NativeFileViewerScreen> createState() =>
      _NativeFileViewerScreenState();
}

class _NativeFileViewerScreenState extends ConsumerState<NativeFileViewerScreen> {
  Uint8List? _fetchedBytes;
  Object? _fetchError;
  bool _fetching = false;
  bool _showMarkdownRaw = false;

  bool get _isE2ee =>
      widget.e2eeFileKey != null && widget.e2eeFileKey!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _maybeFetch();
  }

  @override
  void didUpdateWidget(covariant NativeFileViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.e2eeFileKey != widget.e2eeFileKey) {
      _fetchedBytes = null;
      _fetchError = null;
      _maybeFetch();
    }
  }

  Future<void> _maybeFetch() async {
    // Only fetch over the network when we only have a remote URL and no
    // local bytes/path (the local optimistically-sent messages already have
    // their bytes in hand).
    final bool hasUrl =
        widget.url != null && widget.url!.trim().isNotEmpty;
    if (!hasUrl || widget.bytes != null || widget.localPath != null) {
      return;
    }

    setState(() {
      _fetching = true;
      _fetchError = null;
    });

    try {
      Uint8List? fileKey;
      if (_isE2ee) {
        try {
          fileKey = base64Decode(widget.e2eeFileKey!);
        } catch (_) {}
      }
      final Uint8List bytes = await WsMediaFetcher.fetchAndDecryptMedia(
        filePath: widget.url!,
        wsClient: ref.read(webSocketClientProvider),
        e2eeFileKey: fileKey,
      );
      if (!mounted) return;
      setState(() {
        _fetchedBytes = bytes;
        _fetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = e;
        _fetching = false;
      });
    }
  }

  Future<void> _shareFile() async {
    final Uint8List? data = _fetchedBytes ?? widget.bytes;
    if (data != null) {
      final String tempDir = (await getTemporaryDirectory()).path;
      final String filePath = '$tempDir/${widget.fileName}';
      final File file = File(filePath);
      await file.writeAsBytes(data);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(filePath)],
          text: widget.fileName,
        ),
      );
    } else if (widget.localPath != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(widget.localPath!)],
          text: widget.fileName,
        ),
      );
    } else if (widget.url != null) {
      await SharePlus.instance.share(
        ShareParams(
          text: widget.url!,
          subject: widget.fileName,
        ),
      );
    }
  }

  Future<void> _downloadFile() async {
    final Uint8List? data = _fetchedBytes ?? widget.bytes;
    if (kIsWeb) {
      AppToast.showInfo(context, 'В веб-версии файл скачивается через браузер');
      if (widget.url != null) {
        launchUrl(Uri.parse(widget.url!));
      }
      return;
    }
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String savePath = '${dir.path}/${widget.fileName}';
      if (data != null) {
        final File file = File(savePath);
        await file.writeAsBytes(data);
        if (mounted) {
          AppToast.showSuccess(context, 'Файл сохранён в $savePath');
        }
      } else if (widget.localPath != null) {
        final File src = File(widget.localPath!);
        await src.copy(savePath);
        if (mounted) {
          AppToast.showSuccess(context, 'Файл сохранён в $savePath');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Не удалось сохранить файл: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String ext = widget.fileName.contains('.')
        ? widget.fileName.split('.').last.toLowerCase()
        : '';
    final bool isMarkdown = ext == 'md';

    final bool canRoutePop = ModalRoute.of(context)?.canPop ?? false;
    return PopScope(
      canPop: canRoutePop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (canRoutePop) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        } else {
          try {
            context.go('/main/chats');
          } catch (_) {
            Navigator.maybePop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(
            widget.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/main/chats');
              }
            },
          ),
          actions: [
            if (isMarkdown)
              IconButton(
                icon: Icon(_showMarkdownRaw
                    ? Icons.visibility_rounded
                    : Icons.code_rounded),
                tooltip: _showMarkdownRaw ? 'Форматированный вид' : 'Исходный код',
                onPressed: () =>
                    setState(() => _showMarkdownRaw = !_showMarkdownRaw),
              ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Поделиться',
              onPressed: _shareFile,
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Сохранить',
              onPressed: _downloadFile,
            ),
          ],
        ),
        body: _buildViewer(),
      ),
    );
  }

  Widget _buildViewer() {
    if (_fetching) {
      return const Center(child: AppLoadingIndicator(size: 32));
    }

    if (_fetchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppErrorFormatter.format(_fetchError).toString(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final Uint8List? resolvedBytes = _fetchedBytes ?? widget.bytes;
    final String? resolvedLocalPath = widget.localPath;
    final ft = widget.fileType;

    final String ext = widget.fileName.contains('.')
        ? widget.fileName.split('.').last.toLowerCase()
        : '';
    final bool isMarkdown = ext == 'md';
    final bool isDocx = ext == 'docx' || ext == 'doc';
    final bool isTextOrCode = ft.category == FileTypeCategory.text ||
        ft.category == FileTypeCategory.code ||
        ext == 'txt' ||
        ext == 'json' ||
        ext == 'csv' ||
        ext == 'log' ||
        ext == 'dart' ||
        ext == 'py' ||
        ext == 'js' ||
        ext == 'ts' ||
        ext == 'html' ||
        ext == 'css' ||
        ext == 'yaml' ||
        ext == 'yml' ||
        ext == 'xml' ||
        ext == 'sql' ||
        ext == 'sh';

    if (isMarkdown) {
      return _MarkdownViewer(
        fileName: widget.fileName,
        bytes: resolvedBytes,
        localPath: resolvedLocalPath,
        showRawSource: _showMarkdownRaw,
      );
    }

    if (isDocx) {
      return _DocxViewer(
        fileName: widget.fileName,
        bytes: resolvedBytes,
        localPath: resolvedLocalPath,
      );
    }

    if (isTextOrCode) {
      return _TextViewer(
        fileName: widget.fileName,
        bytes: resolvedBytes,
        localPath: resolvedLocalPath,
      );
    }

    if (ft.isImage) {
      return _ImageViewer(
        url: resolvedBytes == null ? widget.url : null,
        bytes: resolvedBytes,
        isSvg: widget.fileName.toLowerCase().endsWith('.svg'),
      );
    }

    if (ft.isVideo) {
      return _VideoViewer(
        url: resolvedBytes == null ? widget.url : null,
        localPath: resolvedLocalPath,
      );
    }

    if (ft.isAudio) {
      return _MusicPlayer(
        fileName: widget.fileName,
        url: resolvedBytes == null ? widget.url : null,
        localPath: resolvedLocalPath,
        bytes: resolvedBytes,
      );
    }

    if (ft.isPdf) {
      return _PdfViewer(
        url: resolvedBytes == null ? widget.url : null,
        localPath: resolvedLocalPath,
        bytes: resolvedBytes,
      );
    }

    // Fallback for other files
    return _DocumentInfoViewer(
      fileName: widget.fileName,
      fileType: ft,
      url: widget.url,
      localPath: resolvedLocalPath,
    );
  }
}

// ── Markdown Document Viewer ──────────────────────────────────
class _MarkdownViewer extends StatelessWidget {
  const _MarkdownViewer({
    required this.fileName,
    required this.bytes,
    required this.localPath,
    required this.showRawSource,
  });

  final String fileName;
  final Uint8List? bytes;
  final String? localPath;
  final bool showRawSource;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String content = '';
    if (bytes != null) {
      content = utf8.decode(bytes!, allowMalformed: true);
    } else if (localPath != null && !kIsWeb) {
      try {
        content = File(localPath!).readAsStringSync();
      } catch (_) {}
    }

    if (content.isEmpty) {
      return const Center(child: AppLoadingIndicator(size: 32));
    }

    if (showRawSource) {
      return _TextViewer(
        fileName: fileName,
        bytes: bytes,
        localPath: localPath,
      );
    }

    return SelectionArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Markdown(
            data: content,
            selectable: true,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            onTapLink: (text, href, title) {
              if (href != null && href.isNotEmpty) {
                launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
              }
            },
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: scheme.onSurface,
              ),
              h1: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
              h2: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
              h3: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
              code: TextStyle(
                backgroundColor: scheme.surfaceContainerHighest,
                fontFamily: 'monospace',
                fontSize: 13,
                color: scheme.primary,
              ),
              codeblockDecoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              blockquoteDecoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: scheme.primary, width: 4),
                ),
              ),
              tableBorder: TableBorder.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              tableHead: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Native DOCX Document Viewer ──────────────────────────────
class _DocxViewer extends StatefulWidget {
  const _DocxViewer({
    required this.fileName,
    required this.bytes,
    required this.localPath,
  });

  final String fileName;
  final Uint8List? bytes;
  final String? localPath;

  @override
  State<_DocxViewer> createState() => _DocxViewerState();
}

class _DocxViewerState extends State<_DocxViewer> {
  DocxDocument? _doc;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  void _parse() {
    Uint8List? data = widget.bytes;
    if (data == null && widget.localPath != null && !kIsWeb) {
      try {
        data = File(widget.localPath!).readAsBytesSync();
      } catch (_) {}
    }

    if (data != null && data.isNotEmpty) {
      _doc = DocxParser.parseBytes(data);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: AppLoadingIndicator(size: 32));
    }

    if (_doc == null || !_doc!.hasContent) {
      return _DocumentInfoViewer(
        fileName: widget.fileName,
        fileType: FileTypeDetector.detect(fileName: widget.fileName),
        localPath: widget.localPath,
      );
    }

    return SelectionArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: _doc!.blocks.length,
            itemBuilder: (BuildContext context, int index) {
              final DocxBlock block = _doc!.blocks[index];
              return _buildDocxBlock(context, block, scheme, textTheme);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDocxBlock(
    BuildContext context,
    DocxBlock block,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    switch (block.type) {
      case DocxBlockType.title:
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Text(
            block.plainText,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        );
      case DocxBlockType.heading1:
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            block.plainText,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        );
      case DocxBlockType.heading2:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            block.plainText,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        );
      case DocxBlockType.heading3:
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            block.plainText,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      case DocxBlockType.bulletItem:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7, right: 10),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: _buildRuns(block.runs, scheme, textTheme),
              ),
            ],
          ),
        );
      case DocxBlockType.table:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Table(
              border: TableBorder.symmetric(
                inside: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              children: block.tableRows.asMap().entries.map((entry) {
                final int rowIndex = entry.key;
                final List<String> row = entry.value;
                final bool isHeader = rowIndex == 0;
                return TableRow(
                  decoration: BoxDecoration(
                    color: isHeader
                        ? scheme.surfaceContainerHigh
                        : (rowIndex.isEven
                            ? scheme.surfaceContainerLowest
                            : scheme.surface),
                  ),
                  children: row.map((String cell) {
                    return Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        cell,
                        style: isHeader
                            ? textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              )
                            : textTheme.bodySmall,
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        );
      case DocxBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildRuns(block.runs, scheme, textTheme),
        );
    }
  }

  Widget _buildRuns(
    List<DocxRun> runs,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Text.rich(
      TextSpan(
        children: runs.map((DocxRun r) {
          return TextSpan(
            text: r.text,
            style: TextStyle(
              fontWeight: r.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: r.isItalic ? FontStyle.italic : FontStyle.normal,
              decoration:
                  r.isUnderline ? TextDecoration.underline : TextDecoration.none,
              height: 1.5,
              color: scheme.onSurface,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Native Text & Code Document Viewer ─────────────────────────
class _TextViewer extends StatefulWidget {
  const _TextViewer({
    required this.fileName,
    required this.bytes,
    required this.localPath,
  });

  final String fileName;
  final Uint8List? bytes;
  final String? localPath;

  @override
  State<_TextViewer> createState() => _TextViewerState();
}

class _TextViewerState extends State<_TextViewer> {
  String _content = '';
  bool _wrapLines = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.bytes != null) {
      _content = utf8.decode(widget.bytes!, allowMalformed: true);
    } else if (widget.localPath != null && !kIsWeb) {
      try {
        _content = File(widget.localPath!).readAsStringSync();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final List<String> lines = _content.split('\n');

    return Column(
      children: [
        // Search & settings bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск по тексту...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: _wrapLines
                    ? 'Отключить перенос строк'
                    : 'Включить перенос строк',
                icon: Icon(
                  _wrapLines ? Icons.wrap_text_rounded : Icons.table_rows_rounded,
                  size: 18,
                ),
                onPressed: () => setState(() => _wrapLines = !_wrapLines),
              ),
              IconButton.filledTonal(
                tooltip: 'Скопировать весь текст',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _content));
                  AppToast.showSuccess(context, 'Текст скопирован');
                },
              ),
            ],
          ),
        ),
        // Content with line numbers
        Expanded(
          child: SelectionArea(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              physics: const BouncingScrollPhysics(),
              itemCount: lines.length,
              itemBuilder: (BuildContext context, int index) {
                final String line = lines[index];
                final bool isMatch = _searchQuery.isNotEmpty &&
                    line.toLowerCase().contains(_searchQuery);

                return Container(
                  color: isMatch
                      ? scheme.primaryContainer.withValues(alpha: 0.35)
                      : Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          line,
                          softWrap: _wrapLines,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.4,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Image Viewer (with SVG support) ──────────────────────────
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({this.url, this.bytes, this.isSvg = false});

  final String? url;
  final Uint8List? bytes;
  final bool isSvg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5.0,
      child: Center(
        child: _buildContent(scheme, context),
      ),
    );
  }

  Widget _buildContent(ColorScheme scheme, BuildContext context) {
    if (isSvg && bytes != null) {
      return SvgPicture.memory(
        bytes!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (isSvg && url != null) {
      return SvgPicture.network(
        url!,
        headers: cachedAuthHeaders(),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        placeholderBuilder: (_) => const Center(
          child: AppLoadingIndicator(size: 32),
        ),
      );
    }

    final MediaQueryData? mq = MediaQuery.maybeOf(context);
    final double dpr = mq?.devicePixelRatio ?? 1.0;
    final double screenW = mq?.size.width ?? 1080.0;
    final int safeDecodeWidth = (screenW * dpr).round().clamp(1080, 2048);

    if (bytes != null) {
      return Image.memory(
        bytes!,
        fit: BoxFit.contain,
        cacheWidth: safeDecodeWidth,
      );
    }

    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url!,
        httpHeaders: cachedAuthHeaders(),
        fit: BoxFit.contain,
        memCacheWidth: safeDecodeWidth,
        placeholder: (_, _) => const Center(
          child: AppLoadingIndicator(size: 32),
        ),
        errorWidget: (_, _, _) => Icon(
          Icons.broken_image_rounded,
          color: scheme.outline,
          size: 56,
        ),
      );
    }

    return Center(child: Text(context.l10n.mediaViewerCannotPreview));
  }
}

// ── Video Viewer ──────────────────────────────────────────────
class _VideoViewer extends StatefulWidget {
  const _VideoViewer({this.url, this.localPath});

  final String? url;
  final String? localPath;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      if (widget.localPath != null && widget.localPath!.isNotEmpty) {
        _videoController = VideoPlayerController.file(File(widget.localPath!));
      } else if (widget.url != null && widget.url!.isNotEmpty) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      } else {
        throw Exception('Отсутствует источник видео');
      }
      await _videoController!.initialize();
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        placeholder: const AppLoadingIndicator(size: 32),
        allowFullScreen: true,
        allowMuting: true,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Container(
        color: scheme.scrim,
        alignment: Alignment.center,
        child: const Center(
          child: AppLoadingIndicator(size: 32),
        ),
      );
    }

    if (_error != null || _chewieController == null) {
      return Container(
        color: scheme.scrim,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              'Не удалось воспроизвести видео',
              style: TextStyle(color: scheme.onSurface),
            ),
          ],
        ),
      );
    }

    return Container(
      color: scheme.scrim,
      alignment: Alignment.center,
      child: Chewie(controller: _chewieController!),
    );
  }
}

// ── PDF Viewer ────────────────────────────────────────────────
class _PdfViewer extends StatefulWidget {
  const _PdfViewer({this.url, this.localPath, this.bytes});

  final String? url;
  final String? localPath;
  final Uint8List? bytes;

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  int _totalPages = 0;
  int _currentPage = 1;
  bool _ready = false;
  String? _error;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    if (widget.localPath != null) {
      _localPath = widget.localPath;
      setState(() {});
      return;
    }

    if (widget.bytes != null) {
      try {
        final tempDir = await _getTempDir();
        final tempFile = File('$tempDir/temp_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await tempFile.writeAsBytes(widget.bytes!);
        _localPath = tempFile.path;
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      }
    }
  }

  Future<String> _getTempDir() async {
    return (await getTemporaryDirectory()).path;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Failed to load PDF: $_error',
            style: textTheme.bodyLarge?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_localPath == null) {
      return const Center(child: AppLoadingIndicator(size: 32));
    }

    return Stack(
      children: <Widget>[
        PDFView(
          filePath: _localPath,
          onRender: (pages) {
            setState(() {
              _totalPages = pages ?? 0;
              _ready = true;
            });
          },
          onError: (error) {
            setState(() => _error = error.toString());
          },
          onPageError: (page, error) {
            debugPrint('[PDF] Page $page error: $error');
          },
          onViewCreated: (controller) {
            // controller ready
          },
          onPageChanged: (page, total) {
            setState(() {
              _currentPage = (page ?? 0) + 1;
              _totalPages = total ?? 0;
            });
          },
        ),
        if (_ready && _totalPages > 0)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Music Player ──────────────────────────────────────────────
class _MusicPlayer extends StatefulWidget {
  const _MusicPlayer({required this.fileName, this.url, this.localPath, this.bytes});

  final String fileName;
  final String? url;
  final String? localPath;
  final Uint8List? bytes;

  @override
  State<_MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<_MusicPlayer> {
  late final AudioPlayer _player;
  bool _playing = false;
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _playing = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _playing = false;
            _position = Duration.zero;
          }
        });
      }
    });
  }

  Future<void> _initPlayer() async {
    setState(() => _loading = true);
    try {
      if (widget.localPath != null) {
        await _player.setAudioSource(AudioSource.file(widget.localPath!));
      } else if (widget.bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('$tempDir/${DateTime.now().millisecondsSinceEpoch}.audio');
        await tempFile.writeAsBytes(widget.bytes!);
        await _player.setAudioSource(AudioSource.file(tempFile.path));
      } else if (widget.url != null) {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(widget.url!)));
      }
    } catch (e) {
      debugPrint('[MusicPlayer] Init error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      if (_position >= _duration && _duration > Duration.zero) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  void _seek(double fraction) {
    final target = _duration * fraction.clamp(0.0, 1.0);
    _player.seek(target);
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Album art placeholder
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer,
                    scheme.tertiaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: 80,
                color: scheme.onPrimaryContainer,
              ),
            ),

            const SizedBox(height: 32),

            // File name
            Text(
              widget.fileName,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 32),

            // Seekbar
            if (_duration > Duration.zero)
              Column(
                children: [
                  Slider(
                    value: _position.inMilliseconds.toDouble(),
                    min: 0,
                    max: _duration.inMilliseconds.toDouble(),
                    onChanged: (v) => _seek(v / _duration.inMilliseconds),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(_position),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _formatTime(_duration),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Rewind 10s
                IconButton.filledTonal(
                  onPressed: () {
                    final target = _position - const Duration(seconds: 10);
                    _player.seek(target < Duration.zero ? Duration.zero : target);
                  },
                  icon: const Icon(Icons.replay_10_rounded),
                  iconSize: 28,
                ),

                const SizedBox(width: 16),

                // Play/Pause
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _loading
                      ? Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.onPrimary,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _togglePlay,
                          icon: Icon(
                            _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: scheme.onPrimary,
                            size: 36,
                          ),
                        ),
                ),

                const SizedBox(width: 16),

                // Forward 10s
                IconButton.filledTonal(
                  onPressed: () {
                    final target = _position + const Duration(seconds: 10);
                    _player.seek(target > _duration ? _duration : target);
                  },
                  icon: const Icon(Icons.forward_10_rounded),
                  iconSize: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Document Info Viewer (Word, Excel, etc) ───────────────────
class _DocumentInfoViewer extends StatelessWidget {
  const _DocumentInfoViewer({
    required this.fileName,
    required this.fileType,
    this.url,
    this.localPath,
  });

  final String fileName;
  final FileTypeInfo fileType;
  final String? url;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final IconData docIcon = _getDocIcon();
    final Color docColor = Color(fileType.color);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Document icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: docColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                docIcon,
                size: 56,
                color: docColor,
              ),
            ),

            const SizedBox(height: 24),

            // File name
            Text(
              fileName,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // File type label
            Text(
              fileType.label,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // Open externally button
            FilledButton.icon(
              onPressed: () async {
                try {
                  if (localPath != null && localPath!.isNotEmpty) {
                    final OpenResult res = await OpenFile.open(localPath!);
                    if (res.type != ResultType.done && context.mounted) {
                      AppToast.showError(context, res.message);
                    }
                  } else if (url != null && url!.isNotEmpty) {
                    final Uri? uri = Uri.tryParse(url!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  } else {
                    AppToast.showInfo(context, context.l10n.filePreviewOpenExternal);
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppToast.showError(context, 'Не удалось открыть файл: $e');
                  }
                }
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(context.l10n.filePreviewOpenExternal),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Download button
            if (url != null || localPath != null)
              FilledButton.tonalIcon(
                onPressed: () async {
                  try {
                    Directory? dir = await getDownloadsDirectory();
                    dir ??= await getApplicationDocumentsDirectory();
                    final String targetPath = '${dir.path}/$fileName';
                    if (localPath != null && localPath!.isNotEmpty) {
                      final File src = File(localPath!);
                      if (await src.exists()) {
                        await src.copy(targetPath);
                        if (context.mounted) {
                          AppToast.showSuccess(context, 'Файл сохранен: $fileName');
                        }
                        return;
                      }
                    }
                    if (context.mounted) {
                      AppToast.showSuccess(context, context.l10n.filePreviewSaved);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppToast.showError(context, 'Ошибка сохранения: $e');
                    }
                  }
                },
                icon: const Icon(Icons.download_rounded),
                label: Text(context.l10n.filePreviewSave),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getDocIcon() {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'odt':
        return Icons.article_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
