import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/voice_recorder_service.dart';
import 'package:pulse_flutter/screens/circle_video_recorder_screen.dart';
import 'package:pulse_flutter/widgets/chat/m3_emoji_search_view.dart';
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
  List<double> _amplitudeHistory = <double>[];

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
    HapticService.tap();
    _amplitudeHistory = <double>[];
    final bool started = await VoiceRecorderService.startRecording(
      onTick: (Duration d) {
        if (mounted) {
          setState(() => _recordingElapsed = d);
        }
      },
      onAmplitude: (double amp) {
        if (mounted) {
          setState(() {
            _amplitudeHistory.add(amp);
            // Keep only the last 48 samples for UI
            if (_amplitudeHistory.length > 48) {
              _amplitudeHistory =
                  _amplitudeHistory.sublist(_amplitudeHistory.length - 48);
            }
          });
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
  }

  Future<void> _sendVoiceRecording() async {
    HapticService.confirm();
    final String? path = await VoiceRecorderService.stopRecording();
    if (path != null && mounted) {
      setState(() {
        _isRecording = false;
        _amplitudeHistory = <double>[];
      });
      widget.onVoiceSend(path);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    HapticService.destructive();
    await VoiceRecorderService.cancelRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingDragOffset = Offset.zero;
        _amplitudeHistory = <double>[];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

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
            // ── Edit panel ──
            if (widget.editingMessageId != null)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                        left: BorderSide(color: scheme.primary, width: 3)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.edit_rounded,
                          size: 16, color: scheme.primary),
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
                              style: textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
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

            // ── Reply panel ──
            if (widget.replyToMessageId != null)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                        left: BorderSide(color: scheme.secondary, width: 3)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.reply_rounded,
                          size: 16, color: scheme.secondary),
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

            // ── Voice Recording Panel (replaces input row when recording) ──
            if (_isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: VoiceRecordingPanel(
                  elapsed: _recordingElapsed,
                  dragOffset: _recordingDragOffset,
                  isLocked: _isRecordingLocked,
                  amplitudeHistory: _amplitudeHistory,
                  onSend: _sendVoiceRecording,
                  onCancel: _cancelVoiceRecording,
                ),
              ),

            // ── Input Row (hidden when recording — no duplicate) ──
            if (!_isRecording) ...<Widget>[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Text input field
                  Expanded(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: 52, maxHeight: 140),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: widget.inputFocusNode.hasFocus
                                ? scheme.primary.withValues(alpha: 0.45)
                                : scheme.outlineVariant
                                    .withValues(alpha: 0.30),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            // Emoji Toggle Button
                            Tooltip(
                              message: context.l10n.chatEmojiToggle,
                              child: InkWell(
                                onTap: _toggleEmojiPicker,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  child: Icon(
                                    _showEmojiPicker
                                        ? Icons.keyboard_outlined
                                        : Icons.emoji_emotions_outlined,
                                    size: 22,
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),

                            // Text Field
                            Expanded(
                              child: Focus(
                                onKeyEvent:
                                    (FocusNode node, KeyEvent event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.enter) {
                                    if (HardwareKeyboard
                                        .instance.isShiftPressed) {
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
                                  return KeyEventResult.ignored;
                                },
                                child: TextField(
                                  controller: widget.inputController,
                                  focusNode: widget.inputFocusNode,
                                  readOnly: widget.isAiProcessing,
                                  textInputAction:
                                      TextInputAction.newline,
                                  maxLines: 5,
                                  minLines: 1,
                                  keyboardType:
                                      TextInputType.multiline,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText:
                                        context.l10n.chatMessageHint,
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
                                            horizontal: 4, vertical: 10),
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
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: AppLoadingIndicator(
                                    size: 18, color: scheme.primary),
                              )
                            else
                              Tooltip(
                                message: context.l10n.chatAiAssistant,
                                child: InkWell(
                                  onTap: widget.onAiPressed,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 12),
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
                            if (widget.uploadingMedia)
                              Padding(
                                padding: const EdgeInsets.only(
                                    right: 14, bottom: 14),
                                child: AppLoadingIndicator(
                                    size: 20, color: scheme.primary),
                              )
                            else
                              Tooltip(
                                message: context.l10n.chatAttachMedia,
                                child: InkWell(
                                  onTap: widget.onAttachMedia,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 12),
                                    child: Icon(
                                      Icons.attach_file_rounded,
                                      size: 22,
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.7),
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

                  // ── Mic/Video or Send button ──
                  if (_isInputEmpty && widget.editingMessageId == null)
                    _buildRecordButton(scheme)
                  else
                    _buildSendButton(scheme),
                ],
              ),
            ],

            // ── Emoji Picker ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              height: _showEmojiPicker ? 380 : 0,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: _showEmojiPicker
                  ? EmojiPicker(
                      textEditingController: widget.inputController,
                      config: Config(
                        height: 380,
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          backgroundColor: Colors.transparent,
                          columns: 8,
                          emojiSizeMax: 26,
                          verticalSpacing: 2,
                          horizontalSpacing: 2,
                          gridPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          buttonMode: ButtonMode.NONE,
                        ),
                        skinToneConfig: const SkinToneConfig(),
                        categoryViewConfig: CategoryViewConfig(
                          backgroundColor: Colors.transparent,
                          tabBarHeight: 36,
                          indicatorColor: scheme.primary,
                          iconColor: scheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                          iconColorSelected: scheme.primary,
                          backspaceColor: scheme.onSurfaceVariant,
                          dividerColor: Colors.transparent,
                        ),
                        bottomActionBarConfig: BottomActionBarConfig(
                          backgroundColor: Colors.transparent,
                          buttonColor: scheme.surfaceContainerHigh,
                          buttonIconColor: scheme.onSurfaceVariant,
                        ),
                        searchViewConfig: SearchViewConfig(
                          backgroundColor: Colors.transparent,
                          buttonIconColor: scheme.onSurfaceVariant,
                          customSearchView:
                              (config, state, showEmojiView) {
                            return M3EmojiSearchView(
                                config, state, showEmojiView);
                          },
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

  // ── Record button (mic/video toggle + long press to record) ──
  Widget _buildRecordButton(ColorScheme scheme) {
    return GestureDetector(
      onTap: () {
        // Tap toggles mic ↔ video mode
        setState(() => _isVideoMode = !_isVideoMode);
        HapticService.confirm();
      },
      onLongPressStart: (LongPressStartDetails details) async {
        if (_isVideoMode) {
          // Video mode: open circle recorder with auto-start
          HapticService.tap();
          _openCircleVideo(autoStart: true);
          return;
        }
        // Voice mode: start recording
        await _startVoiceRecording();
      },
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
        if (!_isRecording || _isRecordingLocked) return;
        setState(() {
          _recordingDragOffset = details.localOffsetFromOrigin;
        });

        // Real-time lock detection: lock as soon as threshold is crossed
        if (details.localOffsetFromOrigin.dy < -60 && !_isRecordingLocked) {
          HapticService.confirm();
          setState(() => _isRecordingLocked = true);
        }
      },
      onLongPressEnd: (LongPressEndDetails details) async {
        if (!_isRecording || _isRecordingLocked) return;

        final double dx = _recordingDragOffset.dx;

        if (dx < -120) {
          // Slide left → cancel
          await _cancelVoiceRecording();
          return;
        }

        // Release → send
        await _sendVoiceRecording();
      },
      child: AnimatedContainer(
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
              child: child,
            );
          },
          child: Icon(
            _isVideoMode ? Icons.videocam_rounded : Icons.mic_rounded,
            key: ValueKey<bool>(_isVideoMode),
            color: _isVideoMode ? scheme.onTertiary : scheme.onPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ── Send / Commit edit button ──
  Widget _buildSendButton(ColorScheme scheme) {
    return AnimatedSwitcher(
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
            transitionBuilder: (Widget child, Animation<double> anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              widget.editingMessageId != null
                  ? Icons.check_rounded
                  : Icons.send_rounded,
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
