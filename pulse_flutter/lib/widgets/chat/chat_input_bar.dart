import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/core/utils/expression_editing.dart';
import 'package:pulse_flutter/widgets/chat/expression_picker_panel.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/services/desktop_pasteboard_service.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/voice_recorder_service.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/screens/circle_video_recorder_screen.dart';
import 'package:pulse_flutter/widgets/chat/voice_recording_panel.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({
    required this.inputController,
    required this.inputFocusNode,
    required this.isAiProcessing,
    required this.uploadingMedia,
    required this.editingMessageId,
    required this.editingOriginalText,
    required this.replyToMessageId,
    required this.replyPreviewText,
    required this.onSend,
    required this.onCommitEdit,
    required this.onCancelEdit,
    required this.onClearReply,
    required this.onAttachMedia,
    required this.onAiPressed,
    required this.onVoiceSend,
    this.onCircleSend,
    this.chatId,
    this.onSendSticker,
    this.onCancelAi,
    this.onEditLastMessage,
    this.onAttachFiles,
    this.hapticsEnabled = true,
    this.sendOnEnter = true,
    super.key,
  });

  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final bool isAiProcessing;
  final VoidCallback? onCancelAi;
  final bool uploadingMedia;
  final int? editingMessageId;
  final String? editingOriginalText;
  final int? replyToMessageId;
  final String? replyPreviewText;
  final VoidCallback onSend;
  final VoidCallback onCommitEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onClearReply;
  final VoidCallback onAttachMedia;
  final VoidCallback onAiPressed;
  final void Function(String filePath) onVoiceSend;
  final void Function(String filePath)? onCircleSend;
  final int? chatId;
  final void Function(ApiSticker sticker)? onSendSticker;
  final VoidCallback? onEditLastMessage;
  final void Function(List<String> filePaths, {bool sendAsDocument})?
  onAttachFiles;
  final bool hapticsEnabled;
  final bool sendOnEnter;

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar>
    with WidgetsBindingObserver {
  bool _showEmojiPicker = false;
  bool _pickerHasOpened = false;
  bool _pickerExpanded = false;
  double _cachedKeyboardHeight = 310.0;
  double _windowKeyboardInset = 0;
  bool _isFocused = false;

  bool _isInputEmpty = true;
  bool _isRecording = false;
  bool _isVideoMode = false;
  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier<Offset>(
    Offset.zero,
  );
  bool _isRecordingLocked = false;
  final ValueNotifier<Duration> _elapsedNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<List<double>> _amplitudeNotifier =
      ValueNotifier<List<double>>(<double>[]);
  static const int _kWaveformSampleCount = 48;
  final List<double> _waveformBuffer = <double>[];
  bool _isStartingRecording = false;
  bool _sendOnStart = false;
  bool _cancelOnStart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.inputController.addListener(_onTextChanged);
    _isInputEmpty = widget.inputController.text.trim().isEmpty;
    widget.inputFocusNode.addListener(_onFocusChanged);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final double bottom =
        WidgetsBinding
            .instance
            .platformDispatcher
            .views
            .firstOrNull
            ?.viewInsets
            .bottom ??
        0.0;
    final double pixelRatio =
        WidgetsBinding
            .instance
            .platformDispatcher
            .views
            .firstOrNull
            ?.devicePixelRatio ??
        1.0;
    final double logicalBottom = bottom / (pixelRatio > 0 ? pixelRatio : 1.0);
    if (mounted && (_windowKeyboardInset - logicalBottom).abs() > 1) {
      setState(() => _windowKeyboardInset = logicalBottom);
    }
    if (logicalBottom > 0) {
      final double clamped = logicalBottom.clamp(260.0, 440.0);
      if ((_cachedKeyboardHeight - clamped).abs() > 1.0) {
        _cachedKeyboardHeight = clamped;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.inputController.removeListener(_onTextChanged);
    widget.inputFocusNode.removeListener(_onFocusChanged);
    _dragOffsetNotifier.dispose();
    _amplitudeNotifier.dispose();
    _elapsedNotifier.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final bool empty = widget.inputController.text.trim().isEmpty;
    if (empty != _isInputEmpty) {
      setState(() {
        _isInputEmpty = empty;
      });
    }
  }

  void _onFocusChanged() {
    final bool hasFocus = widget.inputFocusNode.hasFocus;
    if (hasFocus != _isFocused) {
      setState(() => _isFocused = hasFocus);
    }
    if (hasFocus && _showEmojiPicker) {
      // Delay closing picker slightly to allow keyboard to slide up synchronously
      Future<void>.delayed(const Duration(milliseconds: 140), () {
        if (mounted && widget.inputFocusNode.hasFocus) {
          setState(() {
            _showEmojiPicker = false;
          });
        }
      });
    }
  }

  void _toggleEmojiPicker() {
    if (widget.hapticsEnabled) HapticService.tap();
    if (_showEmojiPicker) {
      // Switching from emoji panel back to keyboard
      widget.inputFocusNode.requestFocus();
      Future<void>.delayed(const Duration(milliseconds: 140), () {
        if (mounted) {
          setState(() {
            _showEmojiPicker = false;
          });
        }
      });
    } else {
      // Switching to emoji panel
      final bool keyboardOpen =
          MediaQuery.viewInsetsOf(context).bottom > 0 ||
          widget.inputFocusNode.hasFocus;
      setState(() {
        _pickerHasOpened = true;
        _showEmojiPicker = true;
      });
      if (keyboardOpen) {
        widget.inputFocusNode.unfocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      }
    }
  }

  void _onEmojiBackspace() {
    if (widget.hapticsEnabled) HapticService.tap();
    final String text = widget.inputController.text;
    final TextSelection selection = widget.inputController.selection;
    if (text.isEmpty) return;

    final result = deleteExpressionBeforeCursor(
      text,
      selection.isValid ? selection.start : text.length,
      selection.isValid ? selection.end : text.length,
    );
    widget.inputController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
  }

  Future<void> _pickDesktopFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool sendAsDocument = false,
  }) async {
    try {
      final List<PlatformFile> picked = await FilePicker.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
      );
      if (picked.isNotEmpty && mounted) {
        final List<String> validPaths = picked
            .map((PlatformFile f) => f.path)
            .whereType<String>()
            .where((String p) => p.isNotEmpty)
            .toList();
        if (validPaths.isNotEmpty) {
          if (widget.onAttachFiles != null) {
            widget.onAttachFiles!(validPaths, sendAsDocument: sendAsDocument);
          } else {
            widget.onAttachMedia();
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatInputBar] Error picking desktop files: $e');
    }
  }

  Widget _buildAttachButton(BuildContext context, ColorScheme scheme) {
    final bool isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (isDesktop) {
      return MenuAnchor(
        builder:
            (BuildContext context, MenuController controller, Widget? child) {
              return Tooltip(
                message: context.l10n.chatAttachMedia,
                child: TouchContainer(
                  borderRadius: AppRadii.fullRadius,
                  onTap: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 24,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              );
            },
        menuChildren: <Widget>[
          MenuItemButton(
            leadingIcon: const Icon(Icons.image_outlined, size: 20),
            onPressed: () => _pickDesktopFiles(
              type: FileType.custom,
              allowedExtensions: <String>[
                'jpg',
                'jpeg',
                'png',
                'webp',
                'gif',
                'mp4',
                'mov',
                'mkv',
              ],
            ),
            child: Text(context.l10n.attachmentPhotoVideo),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.description_outlined, size: 20),
            onPressed: () =>
                _pickDesktopFiles(type: FileType.any, sendAsDocument: true),
            child: Text(context.l10n.attachmentDocument),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.audiotrack_outlined, size: 20),
            onPressed: () => _pickDesktopFiles(type: FileType.audio),
            child: Text(context.l10n.attachmentAudio),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.videocam_outlined, size: 20),
            onPressed: () => _openCircleVideo(autoStart: true),
            child: Text(context.l10n.attachmentRecordCircle),
          ),
        ],
      );
    }

    return Tooltip(
      message: context.l10n.chatAttachMedia,
      child: TouchContainer(
        borderRadius: AppRadii.fullRadius,
        onTap: widget.onAttachMedia,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Icon(
            Icons.add_rounded,
            size: 24,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }

  Future<void> _openCircleVideo({bool autoStart = false}) async {
    final String? result = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, _, _) =>
            CircleVideoRecorderScreen(autoStart: autoStart),
        transitionsBuilder: (_, Animation<double> a, _, Widget child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    if (result != null && mounted) {
      if (widget.onCircleSend != null) {
        widget.onCircleSend!(result);
      } else {
        widget.onVoiceSend(result);
      }
    }
  }

  Future<void> _startVoiceRecording() async {
    if (widget.hapticsEnabled) HapticService.tap();
    _waveformBuffer.clear();
    _amplitudeNotifier.value = const <double>[];
    _dragOffsetNotifier.value = Offset.zero;
    _isStartingRecording = true;
    _sendOnStart = false;
    _cancelOnStart = false;

    final bool started = await VoiceRecorderService.startRecording(
      onTick: (Duration d) {
        if (mounted) {
          _elapsedNotifier.value = d;
        }
      },
      onAmplitude: (double amp) {
        if (!mounted) return;
        _waveformBuffer.add(amp);
        if (_waveformBuffer.length > _kWaveformSampleCount) {
          _waveformBuffer.removeAt(0);
        }
        _amplitudeNotifier.value = List<double>.unmodifiable(_waveformBuffer);
      },
    );

    _isStartingRecording = false;

    if (started && mounted) {
      if (_cancelOnStart) {
        _cancelOnStart = false;
        await _cancelVoiceRecording();
        return;
      }
      if (_sendOnStart) {
        _sendOnStart = false;
        await _sendVoiceRecording();
        return;
      }
      _elapsedNotifier.value = Duration.zero;
      _dragOffsetNotifier.value = Offset.zero;
      ref.read(appSoundProvider).playEvent(SoundEvent.recordStart);
      setState(() {
        _isRecording = true;
        _isRecordingLocked = false;
      });
    } else if (mounted) {
      AppToast.showError(
        context,
        'Не удалось начать запись. Проверьте разрешение на микрофон.',
      );
    }
  }

  Future<void> _sendVoiceRecording() async {
    if (widget.hapticsEnabled) HapticService.confirm();
    ref.read(appSoundProvider).playEvent(SoundEvent.recordSend);
    final String? path = await VoiceRecorderService.stopRecording();
    if (mounted) {
      _waveformBuffer.clear();
      _amplitudeNotifier.value = const <double>[];
      _dragOffsetNotifier.value = Offset.zero;
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        widget.onVoiceSend(path);
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (widget.hapticsEnabled) HapticService.destructive();
    ref.read(appSoundProvider).playEvent(SoundEvent.recordCancel);
    await VoiceRecorderService.cancelRecording();
    if (mounted) {
      _waveformBuffer.clear();
      _amplitudeNotifier.value = const <double>[];
      _dragOffsetNotifier.value = Offset.zero;
      setState(() {
        _isRecording = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final bool isCompact = MediaQuery.sizeOf(context).width < 360;

    // Read physical keyboard height dynamically for 1:1 zero-jolt panel parity
    final double bottomInset = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      _windowKeyboardInset,
    );
    final double effectiveKeyboardHeight = bottomInset > 0
        ? bottomInset.clamp(260.0, 440.0)
        : _cachedKeyboardHeight;

    final media = MediaQuery.of(context);
    // Keep the picker above the IME, within the remaining chat viewport.
    final available = math.max(
      0.0,
      media.size.height - media.padding.vertical - bottomInset - 160,
    );
    final compactHeight = math.min(
      effectiveKeyboardHeight,
      math.max(0.0, media.size.height - media.padding.vertical - 160),
    );
    final panelLayoutHeight = _pickerExpanded
        ? math.min(media.size.height * .72, available)
        : compactHeight;
    final effectivePanelHeight = _showEmojiPicker
        ? (_pickerExpanded
              ? panelLayoutHeight
              : math.max(0.0, compactHeight - bottomInset))
        : 0.0;

    return PopScope(
      canPop: !_showEmojiPicker,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _showEmojiPicker) {
          setState(() {
            _showEmojiPicker = false;
          });
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Floating Input Bar Row
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // ── Edit panel ──
                AnimatedSize(
                    key: const ValueKey('edit-context-transition'),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero : M3Durations.short4,
                    curve: M3SpringCurves.expressiveDecel,
                    child: widget.editingMessageId != null ? Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(color: scheme.primary, width: 3),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  context.l10n.chatEditingMessage,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  (widget.editingOriginalText ?? '').length > 80
                                      ? '${(widget.editingOriginalText ?? '').substring(0, 80)}...'
                                      : (widget.editingOriginalText ?? ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onCancelEdit,
                            icon: const Icon(Icons.close_rounded),
                            tooltip: context.l10n.chatEditCancel,
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ) : const SizedBox.shrink(),
                  ),

                // ── Reply panel ──
                AnimatedSize(
                    key: const ValueKey('reply-context-transition'),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero : M3Durations.short4,
                    curve: M3SpringCurves.expressiveDecel,
                    child: widget.replyToMessageId != null ? Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(color: scheme.secondary, width: 3),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.reply_rounded,
                            size: 16,
                            color: scheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.replyPreviewText ?? context.l10n.chatReply,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall,
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onClearReply,
                            icon: const Icon(Icons.close_rounded),
                            tooltip: context.l10n.chatCancelReply,
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ) : const SizedBox.shrink(),
                  ),

                // ── Voice Recording Panel ──
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: _elapsedNotifier,
                      builder: (BuildContext context, Duration elapsed, _) {
                        return ValueListenableBuilder<List<double>>(
                          valueListenable: _amplitudeNotifier,
                          builder:
                              (
                                BuildContext context,
                                List<double> amplitudes,
                                _,
                              ) {
                                return ValueListenableBuilder<Offset>(
                                  valueListenable: _dragOffsetNotifier,
                                  builder:
                                      (
                                        BuildContext context,
                                        Offset dragOffset,
                                        _,
                                      ) {
                                        return VoiceRecordingPanel(
                                          elapsed: elapsed,
                                          dragOffset: dragOffset,
                                          isLocked: _isRecordingLocked,
                                          amplitudeHistory: amplitudes,
                                          onSend: _sendVoiceRecording,
                                          onCancel: _cancelVoiceRecording,
                                        );
                                      },
                                );
                              },
                        );
                      },
                    ),
                  ),

                // ── Input Row ──
                if (!_isRecording) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // Text input field
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 52,
                            maxHeight: 140,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: M3SpringCurves.spatial,
                            decoration: BoxDecoration(
                              color: _isFocused
                                  ? scheme.surfaceContainerHighest
                                  : scheme.surfaceContainerHighest.withValues(
                                      alpha: 0.8,
                                    ),
                              borderRadius:
                                  (theme.inputDecorationTheme.border
                                          as OutlineInputBorder?)
                                      ?.borderRadius ??
                                  BorderRadius.circular(28),
                              border: Border.all(
                                color: _isFocused
                                    ? scheme.primary.withValues(alpha: 0.45)
                                    : scheme.outlineVariant.withValues(
                                        alpha: 0.18,
                                      ),
                                width: 1.4,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                // Animated Emoji <-> Keyboard Toggle Button
                                Tooltip(
                                  message: context.l10n.chatEmojiToggle,
                                  child: TouchContainer(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: _toggleEmojiPicker,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      child: AnimatedSwitcher(
                                        duration:
                                            MediaQuery.disableAnimationsOf(
                                              context,
                                            )
                                            ? Duration.zero
                                            : M3Durations.medium1,
                                        switchInCurve: M3SpringCurves.snappy,
                                        switchOutCurve: M3SpringCurves.snappy,
                                        transitionBuilder:
                                            (
                                              Widget child,
                                              Animation<double> anim,
                                            ) {
                                              return RotationTransition(
                                                turns: Tween<double>(
                                                  begin: 0.88,
                                                  end: 1.0,
                                                ).animate(anim),
                                                child: ScaleTransition(
                                                  scale: anim,
                                                  child: child,
                                                ),
                                              );
                                            },
                                        child: Icon(
                                          _showEmojiPicker
                                              ? Icons.keyboard_rounded
                                              : Icons.emoji_emotions_outlined,
                                          key: ValueKey<bool>(_showEmojiPicker),
                                          size: 22,
                                          color: _showEmojiPicker
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant
                                                    .withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Text Field
                                Expanded(
                                  child: Focus(
                                    onKeyEvent: (FocusNode node, KeyEvent event) {
                                      if (event is KeyDownEvent) {
                                        // 1. Enter: send message or commit edit
                                        if (event.logicalKey ==
                                            LogicalKeyboardKey.enter) {
                                          if (!widget.sendOnEnter ||
                                              HardwareKeyboard
                                                  .instance
                                                  .isShiftPressed) {
                                            return KeyEventResult.ignored;
                                          } else {
                                            if (widget.editingMessageId !=
                                                null) {
                                              widget.onCommitEdit();
                                            } else if (!_isInputEmpty) {
                                              widget.onSend();
                                            }
                                            return KeyEventResult.handled;
                                          }
                                        }

                                        // 2. Escape: cancel edit / clear reply / close emoji picker
                                        if (event.logicalKey ==
                                            LogicalKeyboardKey.escape) {
                                          if (_showEmojiPicker) {
                                            setState(
                                              () => _showEmojiPicker = false,
                                            );
                                            return KeyEventResult.handled;
                                          }
                                          if (widget.editingMessageId != null) {
                                            widget.onCancelEdit();
                                            return KeyEventResult.handled;
                                          }
                                          if (widget.replyToMessageId != null) {
                                            widget.onClearReply();
                                            return KeyEventResult.handled;
                                          }
                                        }

                                        // 3. Arrow Up: edit last sent message if input is empty
                                        if (event.logicalKey ==
                                                LogicalKeyboardKey.arrowUp &&
                                            widget.inputController.text
                                                .trim()
                                                .isEmpty &&
                                            widget.editingMessageId == null) {
                                          if (widget.onEditLastMessage !=
                                              null) {
                                            widget.onEditLastMessage!();
                                            return KeyEventResult.handled;
                                          }
                                        }

                                        // 4. Ctrl+V / Cmd+V: check for clipboard images or files on desktop
                                        if ((HardwareKeyboard
                                                    .instance
                                                    .isControlPressed ||
                                                HardwareKeyboard
                                                    .instance
                                                    .isMetaPressed) &&
                                            event.logicalKey ==
                                                LogicalKeyboardKey.keyV &&
                                            DesktopPasteboardService
                                                .isDesktop) {
                                          unawaited(() async {
                                            final List<String> files =
                                                await DesktopPasteboardService.getClipboardFilesOrImage();
                                            if (files.isNotEmpty && mounted) {
                                              widget.onAttachFiles?.call(files);
                                            }
                                          }());
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: TextField(
                                      controller: widget.inputController,
                                      focusNode: widget.inputFocusNode,
                                      readOnly: widget.isAiProcessing,
                                      textInputAction: widget.sendOnEnter
                                          ? TextInputAction.send
                                          : TextInputAction.newline,
                                      onSubmitted: widget.sendOnEnter
                                          ? (_) {
                                              if (widget.editingMessageId !=
                                                  null) {
                                                widget.onCommitEdit();
                                              } else if (!_isInputEmpty) {
                                                widget.onSend();
                                              }
                                            }
                                          : null,
                                      maxLines: 5,
                                      minLines: 1,
                                      keyboardType: TextInputType.multiline,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: context.l10n.chatMessageHint,
                                        hintMaxLines: 1,
                                        hintStyle: textTheme.bodyMedium
                                            ?.copyWith(
                                              fontSize: 15,
                                              color: scheme.onSurfaceVariant
                                                  .withValues(alpha: 0.50),
                                            ),
                                        filled: false,
                                        fillColor: Colors.transparent,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 10,
                                            ),
                                        isDense: true,
                                        alignLabelWithHint: false,
                                      ),
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                    ),
                                  ),
                                ),

                                // AI Assistant Button
                                if (widget.isAiProcessing)
                                  Tooltip(
                                    message: context.l10n.commonCancel,
                                    child: TouchContainer(
                                      borderRadius: AppRadii.fullRadius,
                                      onTap: widget.onCancelAi,
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Center(
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: <Widget>[
                                              AppLoadingIndicator(
                                                size: 22,
                                                color: scheme.primary,
                                              ),
                                              Icon(
                                                Icons.stop_rounded,
                                                size: 13,
                                                color: scheme.primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else if (!isCompact)
                                  Tooltip(
                                    message: context.l10n.chatAiAssistant,
                                    child: TouchContainer(
                                      borderRadius: AppRadii.fullRadius,
                                      onTap: widget.onAiPressed,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 12,
                                        ),
                                        child: Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 20,
                                          color: _isInputEmpty
                                              ? scheme.onSurfaceVariant
                                                    .withValues(alpha: 0.4)
                                              : scheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Attach Media Button
                                _buildAttachButton(context, scheme),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ── Mic/Video or Send button (Animated Morph) ──
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: M3SpringCurves.bouncy,
                        switchOutCurve: M3SpringCurves.snappy,
                        transitionBuilder:
                            (Widget child, Animation<double> anim) {
                              return ScaleTransition(scale: anim, child: child);
                            },
                        child:
                            (_isInputEmpty && widget.editingMessageId == null)
                            ? KeyedSubtree(
                                key: const ValueKey<String>('record_action'),
                                child: _buildRecordButton(scheme),
                              )
                            : KeyedSubtree(
                                key: const ValueKey<String>('send_action'),
                                child: _buildSendButton(scheme),
                              ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Edge-to-Edge Material 3 Expressive Emoji & Sticker Hub ──
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: available),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : M3Durations.medium1,
              // Height must stay non-negative while the panel settles at zero.
              curve: M3SpringCurves.gentle,
              height: effectivePanelHeight,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: effectivePanelHeight > 0
                    ? Border(
                        top: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      )
                    : null,
              ),
              child: !_pickerHasOpened
                  ? const SizedBox.shrink()
                  : IgnorePointer(
                      ignoring: !_showEmojiPicker,
                      child: ExcludeSemantics(
                        excluding: !_showEmojiPicker,
                        child: ExcludeFocus(
                          excluding: !_showEmojiPicker,
                          child: TickerMode(
                            enabled: _showEmojiPicker,
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight: panelLayoutHeight,
                              maxHeight: panelLayoutHeight,
                              child: ExpressionPickerPanel(
                                inputController: widget.inputController,
                                onBackspace: _onEmojiBackspace,
                                onClose: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setState(() => _showEmojiPicker = false);
                                },
                                onExpandedChanged: (expanded) =>
                                    setState(() => _pickerExpanded = expanded),
                                onStickerSelected: (sticker) {
                                  if (widget.onSendSticker != null) {
                                    widget.onSendSticker!(sticker);
                                  } else if (widget.chatId != null) {
                                    unawaited(
                                      ref
                                          .read(
                                            chatMessagesProvider(
                                              widget.chatId!,
                                            ).notifier,
                                          )
                                          .sendSticker(sticker.id),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Record button (mic/video toggle + long press to record) ──
  Widget _buildRecordButton(ColorScheme scheme) {
    if (!ref.watch(clientCapabilitiesProvider).nativeRecording) {
      return const SizedBox.shrink();
    }
    final bool isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final String tooltipMessage = isDesktop
        ? (_isVideoMode
              ? context.l10n.recordCircleDesktopHint
              : context.l10n.recordVoiceDesktopHint)
        : (_isVideoMode
              ? context.l10n.chatCircleVideo
              : context.l10n.chatVoiceMessage);

    final Widget mainRecordBtn = Tooltip(
      message: tooltipMessage,
      child: GestureDetector(
        onTap: () async {
          if (isDesktop) {
            if (_isVideoMode) {
              if (widget.hapticsEnabled) HapticService.tap();
              _openCircleVideo(autoStart: true);
            } else {
              if (_isRecording) {
                await _sendVoiceRecording();
              } else {
                await _startVoiceRecording();
                ref.read(appSoundProvider).playEvent(SoundEvent.recordLock);
                setState(() => _isRecordingLocked = true);
              }
            }
          } else {
            // Tap toggles mic ↔ video mode on mobile
            setState(() => _isVideoMode = !_isVideoMode);
            if (widget.hapticsEnabled) HapticService.confirm();
          }
        },
        onSecondaryTap: isDesktop
            ? () {
                // Secondary click toggles mode on desktop
                setState(() => _isVideoMode = !_isVideoMode);
                if (widget.hapticsEnabled) HapticService.confirm();
              }
            : null,
        onLongPressStart: (LongPressStartDetails details) async {
          if (isDesktop) return; // Desktop uses single tap
          if (_isVideoMode) {
            // Video mode: open circle recorder with auto-start
            if (widget.hapticsEnabled) HapticService.tap();
            _openCircleVideo(autoStart: true);
            return;
          }
          // Voice mode: start recording
          await _startVoiceRecording();
        },
        onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
          if (isDesktop || !_isRecording || _isRecordingLocked) return;
          _dragOffsetNotifier.value = details.localOffsetFromOrigin;

          // Real-time lock detection: lock as soon as threshold is crossed
          if (details.localOffsetFromOrigin.dy < -60 && !_isRecordingLocked) {
            if (widget.hapticsEnabled) HapticService.confirm();
            ref.read(appSoundProvider).playEvent(SoundEvent.recordLock);
            setState(() => _isRecordingLocked = true);
          }
        },
        onLongPressCancel: () async {
          if (isDesktop) return;
          if (_isStartingRecording) {
            _cancelOnStart = true;
            return;
          }
          if (_isRecording && !_isRecordingLocked) {
            await _cancelVoiceRecording();
          }
        },
        onLongPressEnd: (LongPressEndDetails details) async {
          if (isDesktop) return;
          if (_isStartingRecording) {
            if (_dragOffsetNotifier.value.dx < -120) {
              _cancelOnStart = true;
            } else {
              _sendOnStart = true;
            }
            return;
          }
          if (!_isRecording || _isRecordingLocked) return;

          final double dx = _dragOffsetNotifier.value.dx;

          if (dx < -120) {
            // Slide left → cancel
            await _cancelVoiceRecording();
            return;
          }

          // Release → send
          await _sendVoiceRecording();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: M3SpringCurves.spatial,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _isVideoMode ? scheme.tertiary : scheme.primary,
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> anim) {
              return ScaleTransition(scale: anim, child: child);
            },
            child: Icon(
              _isVideoMode ? Icons.videocam_rounded : Icons.mic_rounded,
              key: ValueKey<bool>(_isVideoMode),
              color: _isVideoMode ? scheme.onTertiary : scheme.onPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );

    if (isDesktop) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() => _isVideoMode = !_isVideoMode);
                if (widget.hapticsEnabled) HapticService.selection();
              },
              child: Tooltip(
                message: _isVideoMode
                    ? context.l10n.recordSwitchVoice
                    : context.l10n.recordSwitchCircle,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.8,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isVideoMode ? Icons.mic_rounded : Icons.videocam_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          mainRecordBtn,
        ],
      );
    }

    return mainRecordBtn;
  }

  // ── Send / Commit edit button ──
  Widget _buildSendButton(ColorScheme scheme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (Widget child, Animation<double> anim) =>
          ScaleTransition(scale: anim, child: child),
      child: TouchContainer(
        key: ValueKey<bool>(widget.editingMessageId != null),
        borderRadius: AppRadii.fullRadius,
        onTap: widget.editingMessageId != null
            ? widget.onCommitEdit
            : widget.onSend,
        onLongPress:
            widget.editingMessageId != null ||
                widget.chatId == null ||
                widget.uploadingMedia ||
                ref.read(chatByIdProvider(widget.chatId!))?.isSecret == true
            ? null
            : () async {
                final draft = widget.inputController.text;
                if (draft.trim().isEmpty) return;
                final session = ref.read(authProvider).session;
                final account = (session?.userId, session?.accessToken);
                final saved = await showScheduledMessageComposer(
                  context,
                  ref,
                  chatId: widget.chatId!,
                  text: draft,
                  replyTo: widget.replyToMessageId,
                );
                if (!mounted ||
                    (
                          ref.read(authProvider).session?.userId,
                          ref.read(authProvider).session?.accessToken,
                        ) !=
                        account) {
                  return;
                }
                if (saved && widget.inputController.text == draft) {
                  widget.inputController.clear();
                  widget.onClearReply();
                }
              },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              widget.editingMessageId != null
                  ? Icons.check_rounded
                  : Icons.arrow_upward_rounded,
              key: ValueKey<bool>(widget.editingMessageId != null),
              color: scheme.onPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
