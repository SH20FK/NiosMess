import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';

/// Quiet time between the last keystroke and the draft write.
const Duration chatDraftDebounce = Duration(milliseconds: 500);

/// The secret-chat side of draft persistence: the account engine, narrowed to
/// the three operations the draft controller needs.
///
/// The screen adapts `SecretChatEngine` to it (see `_SecretDraftSink`), tests
/// fake it. It is looked up lazily — a chat can be flagged secret in metadata
/// before its engine entry exists — and must never touch `ref`, because
/// [ChatDraftController.saveNow] also runs from `dispose()`.
abstract interface class SecretDraftSink {
  /// True once the engine owns [chatId].
  bool isOpen(int chatId);

  /// The draft currently stored in the engine, or `null`.
  String? read(int chatId);

  /// Persists [text]; an empty string is the engine's "no draft".
  Future<void> save(int chatId, String text);
}

/// Owns the composer draft: restore on open, debounced save while typing, the
/// final save in `dispose()`, the "draft restored" banner flag and the seam
/// where a remote draft lands.
///
/// A plain class, like `ChatScrollCoordinator` and `ChatAiRewriteController`:
/// no `ref`, no `BuildContext`. The screen hands in the cached [DraftStorage]
/// (reading `ref` in `dispose()` is not allowed), the composer controller, and
/// the live flags it owns — `isSecret` and the ordinary-persistence gate are
/// function getters, read at call time, never captured in the constructor.
class ChatDraftController {
  ChatDraftController({
    required this.chatId,
    required TextEditingController textController,
    required DraftStorage storage,
    required bool Function() isSecret,
    required bool Function() canPersistOrdinaryDraft,
    required void Function() onBannerChanged,
    SecretDraftSink? Function()? secretSink,
    Future<void> Function()? ensureSecretReady,
    void Function(Object error)? onError,
  }) : _textController = textController,
       _storage = storage,
       _isSecret = isSecret,
       _canPersistOrdinaryDraft = canPersistOrdinaryDraft,
       _onBannerChanged = onBannerChanged,
       _secretSink = secretSink,
       _ensureSecretReady = ensureSecretReady,
       _onError = onError;

  final int? chatId;
  final TextEditingController _textController;
  final DraftStorage _storage;
  final bool Function() _isSecret;
  final bool Function() _canPersistOrdinaryDraft;
  final void Function() _onBannerChanged;
  final SecretDraftSink? Function()? _secretSink;
  final Future<void> Function()? _ensureSecretReady;
  final void Function(Object error)? _onError;

  Timer? _saveTimer;
  bool _showRestoredBanner = false;
  bool _isDisposed = false;

  /// The draft the store is known to hold, as this screen last saved or
  /// adopted it. [applyRemote] only overwrites the composer while the composer
  /// still equals it — that is what keeps a remote sync from eating text the
  /// user typed after the last save.
  String _knownText = '';

  /// Drives the "draft restored" banner in the composer.
  bool get showRestoredBanner => _showRestoredBanner;

  /// True while a keystroke is waiting for its debounced save.
  bool get hasPendingSave => _saveTimer?.isActive ?? false;

  /// Loads the stored draft into an empty composer and raises the banner.
  ///
  /// Secret drafts come from the account engine (the coordinator may still be
  /// resolving), ordinary ones from [DraftStorage]. A non-empty composer is
  /// never overwritten.
  Future<void> restore() async {
    final int? id = chatId;
    if (id == null || _isDisposed) return;

    if (_isSecret()) {
      await _ensureSecretReady?.call();
    }
    // Read lazily and after the await: the coordinator may have flipped the
    // secret flag while we were waiting.
    final String? draft = _isSecret()
        ? _secretSink?.call()?.read(id)
        : await _storage.get(id);
    if (_isDisposed) return;
    if (draft == null || draft.isEmpty) return;
    if (_textController.text.isNotEmpty) return;

    _textController.text = draft;
    _knownText = draft.trim();
    _setRestoredBanner(true);
  }

  /// Schedules the debounced save; every keystroke restarts the 500 ms timer.
  void scheduleSave() {
    if (_isDisposed) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(chatDraftDebounce, saveNow);
  }

  /// Writes the composer text now. Secret chats go to the engine and never to
  /// disk; ordinary chats are skipped while the metadata gate is closed.
  ///
  /// The empty string keeps its current meaning: `DraftStorage.set` removes the
  /// key and the engine stores an empty draft, i.e. "no draft".
  void saveNow() {
    if (_isDisposed) return;
    final int? id = chatId;
    if (id == null) return;
    final String text = _textController.text.trim();

    final SecretDraftSink? sink = _secretSink?.call();
    if (_isSecret() || (sink?.isOpen(id) ?? false)) {
      _knownText = text;
      if (sink != null) {
        // A secret chat must not fail because the journal is unavailable.
        unawaited(sink.save(id, text).catchError((Object _) {}));
      }
      return;
    }
    if (!_canPersistOrdinaryDraft()) return;

    _knownText = text;
    unawaited(_persistOrdinary(id, text));
  }

  /// Clears the composer and the stored draft, for both kinds of chat.
  void clear() {
    final int? id = chatId;
    if (id != null) {
      if (_isSecret()) {
        final SecretDraftSink? sink = _secretSink?.call();
        if (sink != null) {
          unawaited(sink.save(id, '').catchError((Object _) {}));
        }
      } else {
        // Same call the screen made before: remove, not set('').
        unawaited(_removeOrdinary(id));
      }
    }
    _saveTimer?.cancel();
    _knownText = '';
    _textController.clear();
    _setRestoredBanner(false);
  }

  /// Applies a draft that arrived through `liveDraftMapProvider`.
  ///
  /// The caller keeps the "secret chat" and "editing a message" guards; this
  /// refuses to replace anything typed since the last save.
  void applyRemote(String text) {
    if (_isDisposed) return;
    if (text.trim() == _knownText) return;
    if (_textController.text.trim() != _knownText) return;
    _textController.text = text;
    _knownText = text.trim();
  }

  /// Cancels the pending debounce **before** the final save, so the last
  /// <500 ms of typing is written exactly once.
  void dispose() {
    if (_isDisposed) return;
    _saveTimer?.cancel();
    _saveTimer = null;
    saveNow();
    _isDisposed = true;
  }

  Future<void> _persistOrdinary(int id, String text) async {
    try {
      await _storage.set(id, text);
    } catch (error) {
      _onError?.call(error);
    }
  }

  Future<void> _removeOrdinary(int id) async {
    try {
      await _storage.remove(id);
    } catch (error) {
      _onError?.call(error);
    }
  }

  void _setRestoredBanner(bool value) {
    if (_showRestoredBanner == value) return;
    _showRestoredBanner = value;
    _onBannerChanged();
  }
}
