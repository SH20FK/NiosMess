import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'dart:async';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'dart:typed_data';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:pulse_flutter/widgets/chat/interactive_composer.dart';
import 'package:pulse_flutter/widgets/feed_poll_card.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/niosgram_draft_provider.dart';
import 'package:pulse_flutter/core/storage/niosgram_draft_store.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/core/utils/app_error_formatter.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/post_media_strip.dart';
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.autoPickMedia = false});

  final bool autoPickMedia;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

/// An authenticated draft copy no longer depends on a picker's temporary URI.
final class _RestoredDraftFile extends PlatformFile {
  _RestoredDraftFile(this.name, this.bytes);
  @override
  final String name;
  final Uint8List bytes;
  @override
  Uri get uri => Uri(scheme: 'memory', path: name);
  @override
  Never get xFile => throw UnsupportedError('No unencrypted temporary file');
  @override
  int lengthSync() => bytes.length;
  @override
  Future<int> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = CustomEmojiTextController();
  PlatformFile? _selectedFile;
  List<PlatformFile> _selectedFiles = <PlatformFile>[];
  List<Uint8List> _previewBytesList = <Uint8List>[];
  bool _isLoading = false;
  bool _isPickingMedia = false;
  CancellationToken? _uploadCancellation;
  Map<String, dynamic>? _poll;
  String? _error;
  late final NiosgramDraftStore? _draftStore;
  final Map<PlatformFile, NiosgramDraftFile> _persistedFiles = {};
  final Map<PlatformFile, int> _videoDurations = {};
  final Set<PlatformFile> _compressedFiles = {};
  Future<void> _draftWrites = Future<void>.value();
  Timer? _saveTimer;
  bool _restoring = true, _restoreFailed = false, _allowPop = false;
  bool _published = false, _leaving = false, _finalizing = false;
  bool _alreadyPublished = false;
  int _revision = 0;
  String _lastText = '';
  late final (int?, String?) _account;

  static const int _maxPostLength = 2000;
  static const int _maxFileBytes = 25 * 1024 * 1024;
  static const int _maxPhotoUploadBytes = 5 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final session = ref.read(authProvider).session;
    _account = (session?.userId, session?.accessToken);
    _draftStore = ref.read(niosgramDraftStoreProvider);
    _textController.addListener(_textChanged);
    ref.listenManual(
      authProvider.select((s) => (s.session?.userId, s.session?.accessToken)),
      (before, after) {
        if (before != after && mounted) {
          _saveTimer?.cancel();
          _uploadCancellation?.cancel();
          setState(() => _restoreFailed = true);
        }
      },
    );
    unawaited(_restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    if (!_published && !_restoring && !_restoreFailed) {
      // The queued snapshot does not access the widget after disposal.
      unawaited(_queueSave().catchError((Object _) {}));
    }
    _uploadCancellation?.cancel();
    _textController.removeListener(_textChanged);
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        !_published &&
        !_restoring &&
        !_restoreFailed &&
        !_finalizing) {
      _saveTimer?.cancel();
      unawaited(
        _queueSave().catchError((Object _) {
          if (mounted) {
            setState(() => _error = context.l10n.niosgramDraftSaveFailed);
          }
        }),
      );
    }
  }

  Future<void> _restore() async {
    try {
      final session = ref.read(authProvider).session;
      if ((session?.userId, session?.accessToken) != _account ||
          ref.read(authProvider.notifier).isLoggingOut) {
        throw StateError('POST_DRAFT_ACCOUNT_CHANGED');
      }
      final store = _draftStore;
      if (store == null) throw StateError('POST_DRAFT_ACCOUNT_UNAVAILABLE');
      final draft = await store.read();
      final files = <PlatformFile>[];
      final previews = <Uint8List>[];
      if (draft != null) {
        for (final item in draft.files) {
          final bytes = await store.readFile(item);
          if (bytes.isEmpty || bytes.length > _maxFileBytes) {
            throw const FormatException('POST_DRAFT_FILE_INVALID');
          }
          final file = _RestoredDraftFile(item.name, bytes);
          files.add(file);
          if (_isVideoFile(item.name)) {
            previews.add(Uint8List(0));
            if (item.durationMs != null) {
              _videoDurations[file] = item.durationMs!;
            }
          } else {
            final compressed = await ImageCompressor.compressImageBytes(
              bytes: bytes,
              fileName: item.name,
            );
            if (compressed != null) _compressedFiles.add(file);
            previews.add(compressed ?? bytes);
          }
          _persistedFiles[file] = item;
        }
      }
      if (!mounted || _restoreFailed) return;
      _textController.text = draft?.text ?? '';
      _lastText = _textController.text;
      setState(() {
        _selectedFiles = files;
        _selectedFile = files.firstOrNull;
        _previewBytesList = previews;
        _poll = draft?.poll;
        _restoring = false;
      });
      if (widget.autoPickMedia) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pickMedia();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _restoreFailed = true;
        });
      }
    }
  }

  void _textChanged() {
    if (_restoring || _restoreFailed || _textController.text == _lastText) {
      return;
    }
    _lastText = _textController.text;
    _changed();
  }

  void _changed() {
    _revision++;
    _alreadyPublished = false;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(
        _queueSave().catchError((Object _) {
          if (mounted) {
            setState(() => _error = context.l10n.niosgramDraftSaveFailed);
          }
        }),
      );
    });
  }

  Future<void> _queueSave() {
    final store = _draftStore;
    final files = List<PlatformFile>.of(_selectedFiles);
    final text = _textController.text;
    final poll = _poll == null ? null : Map<String, dynamic>.of(_poll!);
    final prior = _draftWrites;
    final operation = prior.then((_) async {
      if (store == null) throw StateError('POST_DRAFT_ACCOUNT_UNAVAILABLE');
      final stored = <NiosgramDraftFile>[];
      for (final file in files) {
        var item = _persistedFiles[file];
        if (item == null) {
          final bytes = await _readMediaBytes(file, 'POST_DRAFT_FILE_INVALID');
          item = await store.saveFile(
            file.name,
            bytes,
            durationMs: _videoDurations[file],
          );
          _persistedFiles[file] = item;
        }
        stored.add(item);
      }
      await store.write(
        NiosgramPostDraft(text: text, poll: poll, files: stored),
      );
    });
    _draftWrites = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _leave() async {
    if (_leaving || _restoring || _finalizing) return;
    if (_restoreFailed) {
      Navigator.maybePop(context);
      return;
    }
    _leaving = true;
    setState(() => _finalizing = true);
    _saveTimer?.cancel();
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _queueSave();
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        context.go('/main/niosgram');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.niosgramDraftSaveFailed);
      }
    } finally {
      _leaving = false;
      if (mounted && !_allowPop) setState(() => _finalizing = false);
    }
  }

  Future<void> _discard() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.commonDiscardChanges,
      subtitle: context.l10n.commonDiscardChangesDesc,
      confirmLabel: context.l10n.commonDiscardChangesConfirm,
      cancelLabel: context.l10n.commonCancel,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _finalizing = true);
    _saveTimer?.cancel();
    try {
      await _draftWrites;
      await _draftStore?.clear();
      if (!mounted) return;
      _textController.clear();
      _persistedFiles.clear();
      _videoDurations.clear();
      _compressedFiles.clear();
      setState(() {
        _selectedFiles = [];
        _selectedFile = null;
        _previewBytesList = [];
        _poll = null;
        _error = null;
      });
      _changed();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.niosgramDraftSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  bool _isVideoFile(String name) {
    final String ext = name.split('.').last.toLowerCase();
    return ext == 'mp4' ||
        ext == 'mov' ||
        ext == 'mkv' ||
        ext == 'webm' ||
        ext == 'avi' ||
        ext == '3gp';
  }

  Future<int> _videoDurationMs(PlatformFile file) async {
    final uri = file.uri;
    final VideoPlayerController controller;
    if (kIsWeb && (uri.scheme == 'blob' || uri.scheme == 'data')) {
      controller = VideoPlayerController.networkUrl(uri);
    } else if (!kIsWeb && uri.scheme == 'file') {
      controller = VideoPlayerController.file(File.fromUri(uri));
    } else if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        uri.scheme == 'content') {
      controller = VideoPlayerController.contentUri(uri);
    } else {
      throw StateError('POST_VIDEO_SOURCE_UNAVAILABLE');
    }
    try {
      await controller.initialize().timeout(const Duration(seconds: 12));
      return controller.value.duration.inMilliseconds;
    } finally {
      unawaited(controller.dispose().catchError((Object _) {}));
    }
  }

  Future<Uint8List> _readMediaBytes(
    PlatformFile file,
    String sizeError, {
    CancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final length = await file.length();
    if (length <= 0 || length > _maxFileBytes) throw FormatException(sizeError);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      cancellation?.throwIfCancelled();
      if (bytes.length + chunk.length > _maxFileBytes) {
        throw FormatException(sizeError);
      }
      bytes.add(chunk);
    }
    if (bytes.isEmpty) throw FormatException(sizeError);
    return bytes.takeBytes();
  }

  Future<void> _pickMedia() async {
    if (_isPickingMedia ||
        _isLoading ||
        _finalizing ||
        ref.read(authProvider.notifier).isLoggingOut) {
      return;
    }
    final int availableSlots = 5 - _selectedFiles.length;
    if (availableSlots <= 0) return;
    _isPickingMedia = true;
    final l10n = context.l10n;
    final sizeError = l10n.niosgramMediaTooLarge;
    final account = ref.read(authProvider).session;
    bool active() =>
        mounted &&
        !ref.read(authProvider.notifier).isLoggingOut &&
        ref.read(authProvider).session?.userId == account?.userId &&
        ref.read(authProvider).session?.accessToken == account?.accessToken;
    try {
      final result = await FilePicker.pickFiles(type: FileType.media);
      if (!active() || result.isEmpty || _isLoading) return;
      final validFiles = List<PlatformFile>.from(_selectedFiles);
      final previews = List<Uint8List>.from(_previewBytesList);
      String? selectionError;
      for (final file in result.take(availableSlots)) {
        final ext = file.name.split('.').last.toLowerCase();
        final video = _isVideoFile(file.name);
        if (!(video
                ? const {'mp4', 'webm', 'mov'}
                : const {'jpg', 'jpeg', 'png', 'webp', 'gif'})
            .contains(ext)) {
          selectionError = l10n.niosgramUnsupportedMedia;
          continue;
        }
        if ((video && validFiles.isNotEmpty) ||
            (!video && validFiles.any((item) => _isVideoFile(item.name)))) {
          selectionError = l10n.niosgramVideoAlone;
          continue;
        }
        final length = await file.length();
        if (!active()) return;
        if (length <= 0 || length > _maxFileBytes) {
          selectionError = l10n.niosgramMediaTooLarge;
          continue;
        }
        Uint8List previewBytes = Uint8List(0);
        if (video) {
          try {
            final duration = await _videoDurationMs(file);
            if (!active()) return;
            if (duration <= 0 || duration > 10000) {
              selectionError = l10n.niosgramVideoDurationLimit;
              continue;
            }
            _videoDurations[file] = duration;
          } catch (_) {
            if (!active()) return;
            selectionError = l10n.niosgramVideoDurationFailed;
            continue;
          }
        } else {
          previewBytes = await _readMediaBytes(file, sizeError);
          if (!mounted || !active()) return;
          final compressed = await ImageCompressor.compressImageBytes(
            bytes: previewBytes,
            fileName: file.name,
          );
          if (!mounted || !active()) return;
          if (compressed != null) {
            previewBytes = compressed;
            _compressedFiles.add(file);
          }
          if (previewBytes.length > _maxPhotoUploadBytes) {
            selectionError = l10n.niosgramPhotoTooLarge;
            continue;
          }
        }
        validFiles.add(file);
        previews.add(previewBytes);
      }
      if (active() && validFiles.length != _selectedFiles.length) {
        setState(() {
          _selectedFiles = validFiles;
          _previewBytesList = previews;
          _selectedFile = validFiles.firstOrNull;
          _error = selectionError;
        });
        _changed();
      } else if (active() && selectionError != null) {
        setState(() => _error = selectionError);
      }
    } catch (error) {
      if (active()) {
        setState(
          () => _error = AppErrorFormatter.format(
            error,
            l10n: context.l10n,
          ).toString(),
        );
      }
    } finally {
      _isPickingMedia = false;
    }
  }

  Future<void> _submit() async {
    if (_isLoading ||
        _isPickingMedia ||
        _finalizing ||
        _alreadyPublished ||
        ref.read(authProvider.notifier).isLoggingOut) {
      return;
    }
    final String text = _textController.text.trim();
    if (text.isEmpty &&
        _poll == null &&
        _selectedFiles.isEmpty &&
        _selectedFile == null) {
      setState(() => _error = context.l10n.postEmptyContent);
      return;
    }
    if (text.runes.length < 10 &&
        _poll == null &&
        _selectedFiles.isEmpty &&
        _selectedFile == null) {
      setState(() => _error = context.l10n.niosgramTextTooShort);
      return;
    }

    if (ref.read(uiSettingsProvider).haptics) HapticService.tap();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final files = List<PlatformFile>.of(
      _selectedFiles.isNotEmpty ? _selectedFiles : [?_selectedFile],
    );
    final previews = List<Uint8List>.of(_previewBytesList);
    final poll = _poll == null ? null : Map<String, dynamic>.of(_poll!);
    final durations = files
        .map((file) => (_videoDurations[file] ?? 0) / 1000)
        .toList();
    final revision = _revision;
    final account = ref.read(authProvider).session;
    final repository = ref.read(chatRepositoryProvider);
    final feed = ref.read(niosgramProvider.notifier);
    final sizeError = context.l10n.niosgramMediaTooLarge;
    final videoDurationError = context.l10n.niosgramVideoDurationFailed;
    final photoSizeError = context.l10n.niosgramPhotoTooLarge;
    final cancellation = CancellationToken();
    _uploadCancellation = cancellation;
    var draftSaved = false;
    var publicationRequested = false;
    var publicationConfirmed = false;
    bool active() =>
        mounted &&
        !ref.read(authProvider.notifier).isLoggingOut &&
        ref.read(authProvider).session?.userId == account?.userId &&
        ref.read(authProvider).session?.accessToken == account?.accessToken;
    try {
      // A publication attempt must not outrun the durable local draft.
      _saveTimer?.cancel();
      await _queueSave();
      if (!active()) return;
      draftSaved = true;
      final uploadIds = <String>[];
      for (var i = 0; i < files.length; i++) {
        cancellation.throwIfCancelled();
        if (!active()) return;
        final file = files[i];
        // Video previews are deliberately empty; they are never upload data.
        final bytes =
            !_isVideoFile(file.name) &&
                i < previews.length &&
                previews[i].isNotEmpty
            ? previews[i]
            : await _readMediaBytes(
                file,
                sizeError,
                cancellation: cancellation,
              );
        if (!active()) return;
        if (_isVideoFile(file.name) &&
            (_videoDurations[file] == null ||
                _videoDurations[file]! <= 0 ||
                _videoDurations[file]! > 10000)) {
          throw StateError(videoDurationError);
        }
        if (!_isVideoFile(file.name) && bytes.length > _maxPhotoUploadBytes) {
          throw StateError(photoSizeError);
        }
        final filename = _compressedFiles.contains(file)
            ? '${file.name.replaceFirst(RegExp(r'\.[^.]+$'), '')}.jpg'
            : (file.name.contains('.') ? file.name : '${file.name}.jpg');
        final uploadId = await repository.uploadStreamInChunks(
          bytes: bytes,
          filename: filename,
          mediaSubtype: 'media',
          fileSize: bytes.length,
          onProgress: (_, _) {},
          cancellationToken: cancellation,
        );
        if (!active()) return;
        if (uploadId.isEmpty) throw StateError('empty_upload_id');
        uploadIds.add(uploadId);
      }
      if (!active()) return;
      publicationRequested = true;
      await feed.createPost(
        text,
        uploadIds: uploadIds,
        poll: poll,
        uploadId: uploadIds.firstOrNull,
        mediaDurations: durations,
      );
      publicationConfirmed = true;

      if (mounted && active()) {
        if (ref.read(uiSettingsProvider).haptics) HapticService.confirm();
        if (_revision == revision) {
          // Freeze the editor while the saved copy is cleared. A later edit
          // must never be erased by completion of an earlier publication.
          setState(() => _finalizing = true);
          _saveTimer?.cancel();
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || !active()) return;
          if (_revision != revision) {
            AppToast.showSuccess(context, context.l10n.auditPostPublished);
            return;
          }
          await _draftWrites;
          await _draftStore?.clear();
          if (!active()) return;
          _published = true;
          setState(() => _allowPop = true);
          await WidgetsBinding.instance.endOfFrame;
          if (mounted) Navigator.of(context).pop();
        } else {
          AppToast.showSuccess(context, context.l10n.auditPostPublished);
          _changed();
        }
      }
    } catch (e) {
      if (!mounted || !active() || cancellation.isCancelled) return;
      if (ref.read(uiSettingsProvider).haptics) HapticService.destructive();
      final unknown =
          publicationRequested &&
          !publicationConfirmed &&
          (e is TimeoutException ||
              (e is ApiException && e.statusCode == 0) ||
              (e is StateError && e.message == 'POST_CONFIRMATION_UNKNOWN'));
      final String formatted = !draftSaved
          ? context.l10n.niosgramDraftSaveFailed
          : publicationConfirmed
          ? context.l10n.niosgramPublishedCleanupFailed
          : unknown
          ? context.l10n.niosgramPostStatusUnknown
          : AppErrorFormatter.format(e, l10n: context.l10n).toString();
      if (publicationConfirmed && _revision == revision) {
        _alreadyPublished = true;
      }
      setState(() => _error = formatted);
      if (mounted) {
        AppToast.showError(context, formatted);
      }
    } finally {
      if (identical(_uploadCancellation, cancellation)) {
        _uploadCancellation = null;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _finalizing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWide = screenWidth >= Breakpoints.medium;

    final AuthState auth = ref.watch(authProvider);
    final String displayName =
        auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;

    if (_restoring || _restoreFailed) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.postNewPost)),
        body: Center(
          child: _restoring
              ? const AppLoadingIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.niosgramDraftRestoreFailed),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _restoring = true;
                          _restoreFailed = false;
                        });
                        unawaited(_restore());
                      },
                      child: Text(context.l10n.commonRetry),
                    ),
                  ],
                ),
        ),
      );
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.postNewPost, maxLines: 2),
          toolbarHeight:
              kToolbarHeight *
              MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
          centerTitle: isWide,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _leave,
          ),
          actions: <Widget>[
            IconButton(
              tooltip: context.l10n.commonDiscardChanges,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _isLoading || _finalizing ? null : _discard,
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24 : 16,
                  vertical: 12,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isWide
                        ? (isDark ? scheme.surfaceContainerLow : scheme.surface)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: isWide
                        ? Border.all(
                            color: scheme.outlineVariant.withValues(
                              alpha: isDark ? 0.20 : 0.40,
                            ),
                          )
                        : null,
                  ),
                  padding: EdgeInsets.all(isWide ? 20 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Author Row
                      Row(
                        children: <Widget>[
                          PulseAvatar(
                            name: displayName,
                            avatarUrl: auth.profile?.avatarUrl,
                            radius: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  context.l10n.niosgramPublishToFeed,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Text input
                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: isDark ? 0.35 : 0.40,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: TextField(
                          controller: _textController,
                          readOnly: _finalizing,
                          maxLines: 12,
                          minLines:
                              MediaQuery.textScalerOf(context).scale(1) > 1.5
                              ? 2
                              : 4,
                          inputFormatters: [
                            CustomEmojiLengthFormatter(_maxPostLength),
                          ],
                          buildCounter:
                              (
                                _, {
                                required int currentLength,
                                required bool isFocused,
                                int? maxLength,
                              }) => null,
                          style: textTheme.bodyLarge?.copyWith(fontSize: 15),
                          decoration: InputDecoration(
                            filled: false,
                            hintText: context.l10n.postHint,
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.70,
                              ),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: context.l10n.postAttachMedia,
                            onPressed:
                                _selectedFiles.length >= 5 ||
                                    _isLoading ||
                                    _finalizing
                                ? null
                                : _pickMedia,
                            icon: Badge(
                              isLabelVisible: _selectedFiles.isNotEmpty,
                              label: Text('${_selectedFiles.length}'),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                            ),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IgnorePointer(
                            ignoring: _finalizing,
                            child: CustomEmojiComposerButton(
                              controller: _textController,
                            ),
                          ),
                          const Spacer(),
                          if (_textController.text.isNotEmpty)
                            Flexible(
                              child: Text(
                                '${customEmojiLength(_textController.text)} / $_maxPostLength',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: textTheme.labelSmall?.copyWith(
                                  color:
                                      customEmojiLength(_textController.text) >
                                          _maxPostLength - 200
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final kind in ['poll', 'quiz'])
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: screenWidth - (isWide ? 80 : 32),
                              ),
                              child: ActionChip(
                                onPressed: _isLoading || _finalizing
                                    ? null
                                    : () async {
                                        final result =
                                            await showInteractiveComposer(
                                              context,
                                              kind,
                                            );
                                        final parsed = result == null
                                            ? null
                                            : InteractiveMessage.parse(result);
                                        if (parsed != null && mounted) {
                                          setState(
                                            () => _poll =
                                                Map<String, dynamic>.from(
                                                  parsed.data,
                                                ),
                                          );
                                          _changed();
                                        }
                                      },
                                avatar: InteractiveIcon(kind),
                                side: BorderSide.none,
                                backgroundColor: scheme.surfaceContainerHigh,
                                label: Text(
                                  kind == 'quiz'
                                      ? context.l10n.niosgramAnonymousQuiz
                                      : context.l10n.niosgramAnonymousPoll,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          if (_poll != null)
                            TextButton(
                              onPressed: _isLoading || _finalizing
                                  ? null
                                  : () {
                                      setState(() => _poll = null);
                                      _changed();
                                    },
                              child: Text(context.l10n.niosgramRemovePoll),
                            ),
                        ],
                      ),
                      if (_poll != null)
                        FeedPollCard(postId: 0, poll: _poll!, preview: true),
                      // Media preview (reusable PostMediaStrip)
                      if (_previewBytesList.isNotEmpty) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${context.l10n.postAttachMedia} (${_previewBytesList.length}/5)',
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        PostMediaStrip(
                          selectedFiles: _selectedFiles,
                          previewBytesList: _previewBytesList,
                          isLoading: _isLoading || _finalizing,
                          tileSize: 84,
                          onAdd: _pickMedia,
                          onRemove: (int index) {
                            setState(() {
                              _selectedFiles.removeAt(index);
                              _previewBytesList.removeAt(index);
                              _selectedFile = _selectedFiles.firstOrNull;
                            });
                            _changed();
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Error message
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: scheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: scheme.onErrorContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading || _finalizing || _alreadyPublished
                        ? null
                        : _submit,
                    child: _isLoading
                        ? const AppLoadingIndicator(size: 18)
                        : Text(
                            context.l10n.postPublish,
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
