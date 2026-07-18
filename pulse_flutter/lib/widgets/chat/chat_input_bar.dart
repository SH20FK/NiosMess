import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/voice_recorder_service.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:pulse_flutter/screens/circle_video_recorder_screen.dart';
import 'package:pulse_flutter/widgets/chat/voice_recording_panel.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class ChatInputBar extends StatefulWidget {
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
    this.hapticsEnabled = true,
    super.key,
  });

  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final bool isAiProcessing;
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
  final bool hapticsEnabled;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _showEmojiPicker = false;
  bool _isInputEmpty = true;
  bool _isRecording = false;
  bool _isVideoMode = false;
  Offset _recordingDragOffset = Offset.zero;
  bool _isRecordingLocked = false;
  Duration _recordingElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.inputController.addListener(_onTextChanged);
    _isInputEmpty = widget.inputController.text.trim().isEmpty;
    widget.inputFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.inputController.removeListener(_onTextChanged);
    widget.inputFocusNode.removeListener(_onFocusChanged);
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
    if (widget.inputFocusNode.hasFocus && _showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
    }
  }

  void _toggleEmojiPicker() {
    if (widget.hapticsEnabled) HapticService.tap();
    if (_showEmojiPicker) {
      widget.inputFocusNode.requestFocus();
    } else {
      widget.inputFocusNode.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      setState(() {
        _showEmojiPicker = true;
      });
    }
  }

  Future<void> _openCircleVideo() async {
    final String? result = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: false,
        barrierDismissible: true,
        
        pageBuilder: (_, __, ___) => const CircleVideoRecorderScreen(),
        transitionsBuilder: (_, Animation<double> a, __, Widget child) =>
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool showSendButton = (!_isInputEmpty || widget.editingMessageId != null) && !_isRecording;

    return PopScope(
      canPop: !_showEmojiPicker,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _showEmojiPicker) {
          setState(() {
            _showEmojiPicker = false;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
          // Panels (Edit/Reply)
          if (widget.editingMessageId != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: scheme.primary, width: 3)),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.edit_rounded, size: 16, color: scheme.primary),
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
                            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
              ),
            ),

          if (widget.replyToMessageId != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: scheme.secondary, width: 3)),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.reply_rounded, size: 16, color: scheme.secondary),
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
              ),
            ),

          // Voice Recording Overlay (when recording)
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VoiceRecordingPanel(
                elapsed: _recordingElapsed,
                dragOffset: _recordingDragOffset,
                isLocked: _isRecordingLocked,
                onSend: () async {
                  HapticService.confirm();
                  final String? path = await VoiceRecorderService.stopRecording();
                  if (path != null && mounted) {
                    setState(() => _isRecording = false);
                    widget.onVoiceSend(path);
                  }
                },
                onCancel: () async {
                  HapticService.destructive();
                  await VoiceRecorderService.cancelRecording();
                  if (mounted) setState(() => _isRecording = false);
                },
              ),
            ),

          // Input Row (always visible)
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 54),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _isRecording
                            ? scheme.error.withValues(alpha: 0.45)
                            : widget.inputFocusNode.hasFocus
                                ? scheme.primary.withValues(alpha: 0.45)
                                : scheme.outlineVariant.withValues(alpha: 0.30),
                        width: 1.0,
                      ),
                    ),
                    child: _isRecording
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.mic_rounded,
                                    color: Theme.of(context).colorScheme.onError,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  VoiceRecorderService.formatDuration(_recordingElapsed),
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              // Emoji Toggle Button
                              Tooltip(
                                message: context.l10n.chatEmojiToggle,
                                child: InkWell(
                                  onTap: _toggleEmojiPicker,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    child: Icon(
                                      _showEmojiPicker ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
                                      size: 22,
                                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),

                              // Text Field
                              Expanded(
                                child: Focus(
                                  onKeyEvent: (FocusNode node, KeyEvent event) {
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                                      if (HardwareKeyboard.instance.isShiftPressed) {
                                        return KeyEventResult.ignored;
                                      } else {
                                        if (widget.editingMessageId != null) {
                                          widget.onCommitEdit();
                                        } else if (!_isInputEmpty) {
                                          widget.onSend();
                                        }
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TextField(
                                    controller: widget.inputController,
                                    focusNode: widget.inputFocusNode,
                                    readOnly: widget.isAiProcessing,
                                    textInputAction: TextInputAction.newline,
                                    maxLines: 3,
                                    minLines: 1,
                                    keyboardType: TextInputType.multiline,
                                    textCapitalization: TextCapitalization.sentences,
                                    style: textTheme.bodyMedium?.copyWith(fontSize: 15),
                                    decoration: InputDecoration(
                                      hintText: context.l10n.chatMessageHint,
                                      hintStyle: textTheme.bodyMedium?.copyWith(
                                        fontSize: 15,
                                        color: scheme.onSurfaceVariant.withValues(alpha: 0.50),
                                      ),
                                      filled: true,
                                      fillColor: Colors.transparent,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                                      isDense: true,
                                      isCollapsed: true,
                                    ),
                                  ),
                                ),
                              ),

                            // AI Assistant Button
                            if (widget.isAiProcessing)
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: AppLoadingIndicator(size: 18, color: scheme.primary),
                              )
                            else
                              Tooltip(
                                message: context.l10n.chatAiAssistant,
                                child: InkWell(
                                  onTap: widget.onAiPressed,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    child: Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 20,
                                      color: _isInputEmpty
                                          ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                                          : scheme.primary,
                                    ),
                                  ),
                                ),
                              ),

                            // Attach Media Button
                            if (widget.uploadingMedia)
                              Padding(
                                padding: const EdgeInsets.only(right: 14, bottom: 14),
                                child: AppLoadingIndicator(size: 20, color: scheme.primary),
                              )
                            else
                              Tooltip(
                                message: context.l10n.chatAttachMedia,
                                child: InkWell(
                                  onTap: widget.onAttachMedia,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    child: Icon(
                                      Icons.attach_file_rounded,
                                      size: 22,
                                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Mic Button (visible when recording, or when input empty + not editing)
              if (_isRecording ||
                  (_isInputEmpty && widget.editingMessageId == null))
                Tooltip(
                  message: _isRecording
                      ? ''
                      : (_isVideoMode
                          ? context.l10n.chatCircleVideo
                          : context.l10n.chatVoiceMessage),
                  child: GestureDetector(
                    onTap: () {
                      if (_isRecording) return;
                      setState(() => _isVideoMode = !_isVideoMode);
                      HapticService.confirm();
                    },
                    onLongPressStart: (details) async {
                      if (_isRecording) return;
                      if (_isVideoMode) {
                        HapticService.tap();
                        _openCircleVideo();
                        return;
                      }
                      HapticService.tap();
                      final bool started =
                          await VoiceRecorderService.startRecording(
                        onTick: (Duration d) {
                          if (mounted) {
                            setState(() => _recordingElapsed = d);
                          }
                        },
                      );
                      if (started && mounted) {
                        setState(() {
                          _isRecording = true;
                          _recordingDragOffset = Offset.zero;
                          _isRecordingLocked = false;
                          _recordingElapsed = Duration.zero;
                        });
                      }
                    },
                    onLongPressMoveUpdate: (details) {
                      if (!_isRecording || _isRecordingLocked) return;
                      setState(() {
                        _recordingDragOffset = details.localOffsetFromOrigin;
                      });
                    },
                    onLongPressEnd: (details) async {
                      if (!_isRecording || _isRecordingLocked) return;

                      final double dx = _recordingDragOffset.dx;
                      final double dy = _recordingDragOffset.dy;

                      if (dy < -60) {
                        HapticService.confirm();
                        setState(() => _isRecordingLocked = true);
                        return;
                      }

                      if (dx < -120) {
                        HapticService.destructive();
                        await VoiceRecorderService.cancelRecording();
                        if (mounted) {
                          setState(() {
                            _isRecording = false;
                            _recordingDragOffset = Offset.zero;
                          });
                        }
                        return;
                      }

                      HapticService.confirm();
                      final String? path =
                          await VoiceRecorderService.stopRecording();
                      if (path != null && mounted) {
                        setState(() => _isRecording = false);
                        widget.onVoiceSend(path);
                      }
                    },
                    child: AnimatedScale(
                      scale: showSendButton ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _isVideoMode ? scheme.tertiary : scheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: (_isVideoMode ? scheme.tertiary : scheme.primary)
                                      .withValues(alpha: 0.24),
                                  blurRadius: 8,
                                  spreadRadius: 0.5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (Widget child, Animation<double> anim) {
                                return ScaleTransition(
                                  scale: anim,
                                  child: RotationTransition(
                                    turns: anim,
                                    child: child,
                                  ),
                                );
                              },
                              child: Icon(
                                _isVideoMode ? Icons.videocam_rounded : Icons.mic_rounded,
                                key: ValueKey<bool>(_isVideoMode),
                                color: scheme.onPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            top: _isVideoMode ? 4 : 24,
                            right: _isVideoMode ? 4 : 24,
                            child: AnimatedScale(
                              scale: _isVideoMode ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: scheme.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(Icons.videocam, size: 8, color: scheme.onError),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Send/Check Button (when input has text or editing, not recording)
              if (!_isRecording &&
                  (!_isInputEmpty || widget.editingMessageId != null))
                AnimatedScale(
                  scale: showSendButton ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (Widget child, Animation<double> anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: GestureDetector(
                      key: ValueKey<bool>(widget.editingMessageId != null),
                      onTap: widget.editingMessageId != null
                          ? widget.onCommitEdit
                          : widget.onSend,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.24),
                              blurRadius: 8,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            widget.editingMessageId != null ? Icons.check_rounded : Icons.send_rounded,
                            key: ValueKey<bool>(widget.editingMessageId != null),
                            color: scheme.onPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            height: _showEmojiPicker ? 340 : 0,
            child: _showEmojiPicker
                ? EmojiPicker(
                    textEditingController: widget.inputController,
                    config: Config(
                      height: 340,
                      checkPlatformCompatibility: true,
                      emojiViewConfig: EmojiViewConfig(
                        backgroundColor: scheme.surfaceContainerLow,
                        columns: 7,
                        emojiSizeMax: 28 * (Platform.isIOS ? 1.20 : 1.0),
                        verticalSpacing: 0,
                        horizontalSpacing: 0,
                        gridPadding: EdgeInsets.zero,
                        buttonMode: ButtonMode.MATERIAL,
                      ),
                      skinToneConfig: const SkinToneConfig(),
                      categoryViewConfig: CategoryViewConfig(
                        backgroundColor: scheme.surfaceContainerLow,
                        indicatorColor: scheme.primary,
                        iconColor: scheme.onSurfaceVariant,
                        iconColorSelected: scheme.primary,
                        backspaceColor: scheme.primary,
                      ),
                      bottomActionBarConfig: BottomActionBarConfig(
                        backgroundColor: scheme.surfaceContainerLow,
                        buttonIconColor: scheme.onSurfaceVariant,
                        buttonColor: scheme.surfaceContainerHigh,
                      ),
                      searchViewConfig: SearchViewConfig(
                        backgroundColor: scheme.surfaceContainerLow,
                        buttonIconColor: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
        ),
      ),
    );
  }
}
