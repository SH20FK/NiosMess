import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_opener.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_presenter.dart';
import 'package:pulse_flutter/screens/media_viewer_screen.dart';
import 'package:pulse_flutter/widgets/m3_file_preview_bottom_sheet.dart';
import 'package:pulse_flutter/widgets/media/media_hero.dart';

/// The swipe playlist built for the media viewer, plus the item to open.
class ChatMediaPlaylist {
  const ChatMediaPlaylist({required this.items, required this.initialIndex});

  final List<MediaViewerItem> items;
  final int initialIndex;
}

/// Builds the viewer playlist from [messages] — every image/video message that
/// has a usable URL, in list order — and points [initialIndex] at [target] by
/// message id, never by list position.
///
/// Pure: same messages in, same playlist out. Returns `null` when there is
/// nothing to swipe through, which is what the caller puts in `extra`.
ChatMediaPlaylist? buildMediaPlaylist(
  List<ApiMessage> messages,
  ApiMessage target, {
  required ChatMessagePresenter presenter,
}) {
  final List<MediaViewerItem> items = <MediaViewerItem>[];
  int initialIndex = 0;

  for (final ApiMessage msg in messages) {
    final String? url = msg.mediaUrl;
    if (url == null || url.trim().isEmpty) continue;
    final bool isImage = presenter.isImageMedia(msg, url);
    final bool isVideo = presenter.isVideoMedia(msg, url);
    if (!isImage && !isVideo) continue;

    if (msg.id == target.id) {
      initialIndex = items.length;
    }
    items.add(
      MediaViewerItem(
        url: url,
        heroTag: chatMediaHeroTag(msg.chatId, msg.id),
        mediaType: isImage ? MediaType.image : MediaType.video,
        title: (msg.mediaName ?? '').trim().isNotEmpty
            ? msg.mediaName!.trim()
            : presenter.mediaLabel(msg, url),
        e2eeFileKey: msg.e2eeFileKey,
        filePath: msg.mediaUrl,
        mediaName: msg.mediaName,
      ),
    );
  }

  if (items.isEmpty) return null;
  return ChatMediaPlaylist(items: items, initialIndex: initialIndex);
}

/// Opens attachments: image/video go to the media viewer with the chat's
/// image/video playlist, everything else to the M3 file preview.
///
/// A plain class, like `ChatScrollCoordinator` and `ChatDraftController`: no
/// `ref` and no stored `BuildContext`. The screen hands in the message source,
/// navigation, forward/delete and the websocket client; `BuildContext` arrives
/// per call and is never kept.
class ChatMediaController {
  ChatMediaController({
    required AppLocalizations Function() l10n,
    required List<ApiMessage> Function() messages,
    required void Function(String location, {Object? extra}) push,
    required Future<void> Function(ApiMessage message) forward,
    required void Function(ApiMessage message) delete,
    required WebSocketClient Function() wsClient,
  }) : _l10n = l10n,
       _messages = messages,
       _push = push,
       _forward = forward,
       _delete = delete,
       _wsClient = wsClient;

  /// Read at call time so a language switch reaches the sheet and its labels.
  final AppLocalizations Function() _l10n;
  final List<ApiMessage> Function() _messages;
  final void Function(String location, {Object? extra}) _push;
  final Future<void> Function(ApiMessage message) _forward;
  final void Function(ApiMessage message) _delete;
  final WebSocketClient Function() _wsClient;

  ChatMessagePresenter get _presenter => ChatMessagePresenter(_l10n());

  /// True when the message carries a media URL this controller can open.
  static bool hasOpenableMedia(ApiMessage message) {
    final String? mediaUrl = message.mediaUrl;
    return mediaUrl != null && mediaUrl.trim().isNotEmpty;
  }

  void openMedia(BuildContext context, ApiMessage message) {
    final String? mediaUrl = message.mediaUrl;
    if (mediaUrl == null || mediaUrl.trim().isEmpty) return;

    final ChatMessagePresenter presenter = _presenter;
    final String fileName = (message.mediaName ?? '').trim().isNotEmpty
        ? message.mediaName!.trim()
        : presenter.mediaLabel(message, mediaUrl);

    final bool isImg = presenter.isImageMedia(message, mediaUrl);
    final bool isVid = presenter.isVideoMedia(message, mediaUrl);

    if (isImg || isVid) {
      final ChatMediaPlaylist? playlist = buildMediaPlaylist(
        _messages(),
        message,
        presenter: presenter,
      );

      _push(
        '/media-viewer?url=${Uri.encodeComponent(mediaUrl)}'
        '&type=${isImg ? 'image' : 'video'}'
        '&title=${Uri.encodeComponent(fileName)}',
        extra: <String, dynamic>{
          'heroTag': chatMediaHeroTag(message.chatId, message.id),
          'e2eeKey': message.e2eeFileKey,
          'playlist': (playlist?.items.isNotEmpty ?? false)
              ? playlist!.items
              : null,
          'initialIndex': playlist?.initialIndex ?? 0,
        },
      );
      return;
    }

    showM3FilePreview(
      context: context,
      fileName: fileName,
      fileSize: message.mediaSize ?? 0,
      mediaUrl: mediaUrl,
      e2eeFileKey: message.e2eeFileKey,
      onForward: () async {
        // The sheet outlives the frame that opened it: the screen may be gone.
        if (!context.mounted) return;
        await _forward(message);
      },
    );
  }

  Future<void> showMediaActions(
    BuildContext context,
    ApiMessage message, {
    required bool isMine,
    required bool amAdminOrOwner,
  }) async {
    if (!hasOpenableMedia(message)) return;

    await AppModal.showSheet<void>(
      context: context,
      builder: (BuildContext ctx) => buildMediaActionsSheet(
        context: context,
        // The sheet's own theme, not the screen's: the route is shown on the
        // root navigator and must keep the colours it had before the move.
        scheme: Theme.of(ctx).colorScheme,
        dismiss: () => Navigator.of(ctx).pop(),
        message: message,
        isMine: isMine,
        amAdminOrOwner: amAdminOrOwner,
      ),
    );
  }

  /// The media long-press menu. [context] is the screen's context (labels,
  /// saving, opening); [dismiss] closes the sheet's own route, so a pop never
  /// resolves to the screen's navigator by accident.
  Widget buildMediaActionsSheet({
    required BuildContext context,
    required ColorScheme scheme,
    required VoidCallback dismiss,
    required ApiMessage message,
    required bool isMine,
    required bool amAdminOrOwner,
  }) {
    final String? mediaUrl = message.mediaUrl;
    final String fileName = (message.mediaName ?? '').trim().isNotEmpty
        ? message.mediaName!.trim()
        : _presenter.mediaLabel(message, mediaUrl ?? '');
    final AppLocalizations l10n = _l10n();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: Text(l10n.mediaActionSave),
              onTap: () {
                dismiss();
                if (mediaUrl == null) return;
                saveM3File(
                  context: context,
                  fileName: fileName,
                  fileSize: message.mediaSize ?? 0,
                  mediaUrl: mediaUrl,
                  e2eeFileKey: message.e2eeFileKey,
                  wsClient: _wsClient(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward_rounded),
              title: Text(l10n.chatResendTo),
              onTap: () {
                dismiss();
                _forward(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(l10n.mediaActionCopy),
              onTap: () async {
                final String copyLabel = l10n.mediaActionCopy;
                dismiss();
                if (mediaUrl == null) return;
                await Clipboard.setData(ClipboardData(text: mediaUrl));
                if (context.mounted) AppToast.showInfo(context, copyLabel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: Text(l10n.mediaActionOpenIn),
              onTap: () {
                dismiss();
                if (mediaUrl == null) return;
                FileOpener.openUrl(context, mediaUrl);
              },
            ),
            if (isMine || amAdminOrOwner)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.error,
                ),
                title: Text(
                  l10n.chatDelete,
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () {
                  dismiss();
                  _delete(message);
                },
              ),
          ],
        ),
      ),
    );
  }
}
