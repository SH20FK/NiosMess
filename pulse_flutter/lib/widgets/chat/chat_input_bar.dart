import 'dart:math' as math;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/voice_recorder_service.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/screens/circle_video_recorder_screen.dart';
import 'package:pulse_flutter/widgets/chat/m3_emoji_search_view.dart';
import 'package:pulse_flutter/widgets/chat/sticker_picker_view.dart';
import 'package:pulse_flutter/widgets/chat/voice_recording_panel.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

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
    this.chatId,
    this.onSendSticker,
    this.hapticsEnabled = true,
    this.sendOnEnter = true,
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
  final int? chatId;
  final void Function(ApiSticker sticker)? onSendSticker;
  final bool hapticsEnabled;
  final bool sendOnEnter;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _showEmojiPicker = false;
  int _pickerTabIndex = 0;
  late final PageController _pickerPageController =
      PageController(initialPage: _pickerTabIndex);

  double _cachedKeyboardHeight = 310.0;
  bool _isFocused = false;

  bool _isInputEmpty = true;
  bool _isRecording = false;
  bool _isVideoMode = false;
  Offset _recordingDragOffset = Offset.zero;
  bool _isRecordingLocked = false;
  final ValueNotifier<Duration> _elapsedNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<List<double>> _amplitudeNotifier =
      ValueNotifier<List<double>>(<double>[]);
  bool _isStartingRecording = false;
  bool _sendOnStart = false;
  bool _cancelOnStart = false;

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
    _pickerPageController.dispose();
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

    if (selection.isValid && selection.start != selection.end) {
      final String newText =
          text.replaceRange(selection.start, selection.end, '');
      widget.inputController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
      return;
    }

    final int cursorOffset =
        selection.isValid ? selection.start : text.length;
    if (cursorOffset <= 0) return;

    final Characters chars = text.characters;
    if (chars.isNotEmpty) {
      final String newText = chars.skipLast(1).toString();
      widget.inputController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
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
    _amplitudeNotifier.value = <double>[];
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
        final List<double> history = List<double>.from(_amplitudeNotifier.value);
        history.add(amp);
        if (history.length > 48) {
          _amplitudeNotifier.value = history.sublist(history.length - 48);
        } else {
          _amplitudeNotifier.value = history;
        }
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
      setState(() {
        _isRecording = true;
        _recordingDragOffset = Offset.zero;
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
    HapticService.confirm();
    final String? path = await VoiceRecorderService.stopRecording();
    if (mounted) {
      _amplitudeNotifier.value = <double>[];
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        widget.onVoiceSend(path);
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    HapticService.destructive();
    await VoiceRecorderService.cancelRecording();
    if (mounted) {
      _amplitudeNotifier.value = <double>[];
      setState(() {
        _isRecording = false;
        _recordingDragOffset = Offset.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    // Cache physical keyboard height dynamically for 1:1 zero-jolt panel parity
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    if (bottomInset > 0) {
      final double clamped = bottomInset.clamp(260.0, 440.0);
      if ((_cachedKeyboardHeight - clamped).abs() > 1.0) {
        _cachedKeyboardHeight = clamped;
      }
    }

    // Mathematical zero-jolt height: when switching, the sum of keyboardInset + panelHeight
    // remains constant so the message list doesn't move a single pixel!
    final double effectivePanelHeight = _showEmojiPicker
        ? math.max(0.0, _cachedKeyboardHeight - bottomInset)
        : 0.0;

    return PopScope(
      canPop: !_showEmojiPicker,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _showEmojiPicker) {
          setState(() {
            _showEmojiPicker = false;
          });
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
                if (widget.editingMessageId != null)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                            left:
                                BorderSide(color: scheme.primary, width: 3)),
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
                                  style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                            left: BorderSide(
                                color: scheme.secondary, width: 3)),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.reply_rounded,
                              size: 16, color: scheme.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.replyPreviewText ??
                                  context.l10n.chatReply,
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

                // ── Voice Recording Panel ──
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: _elapsedNotifier,
                      builder: (BuildContext context, Duration elapsed, _) {
                        return ValueListenableBuilder<List<double>>(
                          valueListenable: _amplitudeNotifier,
                          builder: (BuildContext context, List<double> amplitudes, _) {
                            return VoiceRecordingPanel(
                              elapsed: elapsed,
                              dragOffset: _recordingDragOffset,
                              isLocked: _isRecordingLocked,
                              amplitudeHistory: amplitudes,
                              onSend: _sendVoiceRecording,
                              onCancel: _cancelVoiceRecording,
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
                              minHeight: 52, maxHeight: 140),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: M3SpringCurves.spatial,
                            decoration: BoxDecoration(
                              color: _isFocused
                                  ? scheme.surfaceContainerHighest
                                  : scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: _isFocused
                                    ? scheme.primary.withValues(alpha: 0.45)
                                    : scheme.outlineVariant
                                        .withValues(alpha: 0.18),
                                width: 1.4,
                              ),
                              boxShadow: _isFocused
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: scheme.primary
                                            .withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
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
                                          horizontal: 12, vertical: 12),
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        switchInCurve: M3SpringCurves.snappy,
                                        switchOutCurve: M3SpringCurves.snappy,
                                        transitionBuilder: (Widget child,
                                            Animation<double> anim) {
                                          return RotationTransition(
                                            turns: Tween<double>(
                                                    begin: 0.88, end: 1.0)
                                                .animate(anim),
                                            child: ScaleTransition(
                                                scale: anim, child: child),
                                          );
                                        },
                                        child: Icon(
                                          _showEmojiPicker
                                              ? Icons.keyboard_rounded
                                              : Icons
                                                  .emoji_emotions_outlined,
                                          key: ValueKey<bool>(
                                              _showEmojiPicker),
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
                                    onKeyEvent: (FocusNode node,
                                        KeyEvent event) {
                                      if (event is KeyDownEvent &&
                                          event.logicalKey ==
                                              LogicalKeyboardKey.enter) {
                                        if (!widget.sendOnEnter ||
                                            HardwareKeyboard
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
                                    child: TouchContainer(
                                      borderRadius: AppRadii.fullRadius,
                                      onTap: widget.onAiPressed,
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
                                Tooltip(
                                  message: context.l10n.chatAttachMedia,
                                  child: TouchContainer(
                                    borderRadius: AppRadii.fullRadius,
                                    onTap: widget.onAttachMedia,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 12),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 24,
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                ),
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
                          return ScaleTransition(
                            scale: anim,
                            child: child,
                          );
                        },
                        child: (_isInputEmpty &&
                                widget.editingMessageId == null)
                            ? KeyedSubtree(
                                key: const ValueKey<String>(
                                    'record_action'),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: M3SpringCurves.spatial,
            height: effectivePanelHeight,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: effectivePanelHeight > 0
                  ? <BoxShadow>[
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.09),
                        blurRadius: 18,
                        offset: const Offset(0, -4),
                      ),
                    ]
                  : null,
            ),
            child: effectivePanelHeight > 0
                ? Column(
                    children: <Widget>[
                      // Drag handle for smooth pull-down to dismiss
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate:
                            (DragUpdateDetails details) {
                          if (details.primaryDelta != null &&
                              details.primaryDelta! > 5) {
                            if (widget.hapticsEnabled) {
                              HapticService.tap();
                            }
                            setState(() => _showEmojiPicker = false);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          color: Colors.transparent,
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Expressive Tab Bar: [ 😊 Эмодзи | 🏷️ Стикеры ] + Backspace
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 2, 8, 8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          border: Border(
                            bottom: BorderSide(
                              color: scheme.outlineVariant
                                  .withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            const SizedBox(width: 40), // Balances backspace button
                            Expanded(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.55),
                                    borderRadius:
                                        BorderRadius.circular(24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      _buildPickerTab(
                                        index: 0,
                                        label: 'Эмодзи',
                                        icon: Icons.emoji_emotions_outlined,
                                        scheme: scheme,
                                      ),
                                      const SizedBox(width: 4),
                                      _buildPickerTab(
                                        index: 1,
                                        label: 'Стикеры',
                                        icon: Icons.sticky_note_2_outlined,
                                        scheme: scheme,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Quick backspace button for emojis
                            IconButton(
                              onPressed: _onEmojiBackspace,
                              icon: Icon(
                                Icons.backspace_outlined,
                                size: 19,
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.75),
                              ),
                              tooltip: 'Удалить',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),

                      // Horizontal PageView for smooth swiping between Emojis and Stickers
                      Expanded(
                        child: PageView(
                          controller: _pickerPageController,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (int page) {
                            if (widget.hapticsEnabled) {
                              HapticService.tap();
                            }
                            setState(() => _pickerTabIndex = page);
                          },
                          children: <Widget>[
                            // Page 0: Emoji Picker
                            EmojiPicker(
                              textEditingController:
                                  widget.inputController,
                              config: Config(
                                checkPlatformCompatibility: true,
                                emojiViewConfig: const EmojiViewConfig(
                                  backgroundColor: Colors.transparent,
                                  columns: 8,
                                  emojiSizeMax: 28,
                                  verticalSpacing: 3,
                                  horizontalSpacing: 3,
                                  gridPadding: EdgeInsets.symmetric(
                                      horizontal: 8),
                                  buttonMode: ButtonMode.NONE,
                                ),
                                skinToneConfig: const SkinToneConfig(),
                                categoryViewConfig: CategoryViewConfig(
                                  backgroundColor: Colors.transparent,
                                  tabBarHeight: 38,
                                  indicatorColor: scheme.primary,
                                  iconColor: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                  iconColorSelected: scheme.primary,
                                  backspaceColor: scheme.onSurfaceVariant,
                                  dividerColor: Colors.transparent,
                                ),
                                bottomActionBarConfig:
                                    BottomActionBarConfig(
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
                            ),

                            // Page 1: Sticker Picker
                            StickerPickerView(
                              chatId: widget.chatId,
                              onStickerSelected: (ApiSticker sticker) {
                                if (widget.onSendSticker != null) {
                                  widget.onSendSticker!(sticker);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTab({
    required int index,
    required String label,
    required IconData icon,
    required ColorScheme scheme,
  }) {
    final bool isSelected = _pickerTabIndex == index;
    return TouchContainer(
      onTap: () {
        if (widget.hapticsEnabled) HapticService.tap();
        setState(() => _pickerTabIndex = index);
        if (_pickerPageController.hasClients) {
          _pickerPageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 260),
            curve: M3SpringCurves.snappy,
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: M3SpringCurves.snappy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
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
      onLongPressCancel: () async {
        if (_isStartingRecording) {
          _cancelOnStart = true;
          return;
        }
        if (_isRecording && !_isRecordingLocked) {
          await _sendVoiceRecording();
        }
      },
      onLongPressEnd: (LongPressEndDetails details) async {
        if (_isStartingRecording) {
          if (_recordingDragOffset.dx < -120) {
            _cancelOnStart = true;
          } else {
            _sendOnStart = true;
          }
          return;
        }
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
      child: TouchContainer(
        key: ValueKey<bool>(widget.editingMessageId != null),
        borderRadius: AppRadii.fullRadius,
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
