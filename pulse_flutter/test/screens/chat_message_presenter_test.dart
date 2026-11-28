import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_presenter.dart';

const int _myUserId = 1;

final AppLocalizations _ru = lookupAppLocalizations(const Locale('ru'));
final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));

ApiMessage _msg({
  int id = 100,
  int senderId = 2,
  String content = '',
  String msgType = 'text',
  int? replyToId,
  String? mediaUrl,
  String? mediaType,
  String? mediaName,
  int? mediaDuration,
  String senderDisplayName = 'Партнёр',
  String senderUsername = 'partner',
  ApiSticker? sticker,
  bool? isStickerExplicit,
  String? systemEventType,
}) => ApiMessage(
  id: id,
  chatId: 9001,
  senderId: senderId,
  senderUsername: senderUsername,
  senderDisplayName: senderDisplayName,
  senderBadges: const [],
  content: content,
  msgType: msgType,
  replyToId: replyToId,
  mediaUrl: mediaUrl,
  mediaType: mediaType,
  mediaName: mediaName,
  mediaSize: null,
  mediaDuration: mediaDuration,
  commentsCount: 0,
  reactions: const {},
  sentAt: DateTime.utc(2026, 11, 28, 10),
  editedAt: null,
  isDeleted: false,
  sticker: sticker,
  isStickerExplicit: isStickerExplicit,
  systemEventType: systemEventType,
);

String _author(ApiMessage msg, {int myUserId = _myUserId, String chatName = ''}) =>
    ChatMessagePresenter(
      _ru,
    ).resolveReplyAuthor(msg, myUserId: myUserId, chatName: chatName);

void main() {
  final ChatMessagePresenter presenter = ChatMessagePresenter(_ru);

  group('resolveReplySnippet — stickers', () {
    test('sticker with emoji', () {
      final ApiMessage msg = _msg(
        msgType: 'sticker',
        sticker: const ApiSticker(id: 1, url: 's.webp', emoji: '🔥'),
      );
      expect(presenter.resolveReplySnippet(msg), '🖼️ Стикер 🔥');
    });

    test('sticker without emoji', () {
      final ApiMessage msg = _msg(
        msgType: 'sticker',
        sticker: const ApiSticker(id: 1, url: 's.webp'),
      );
      expect(presenter.resolveReplySnippet(msg), '🖼️ Стикер');
    });

    test('explicit sticker flag without sticker payload', () {
      final ApiMessage msg = _msg(msgType: 'text', isStickerExplicit: true);
      expect(presenter.resolveReplySnippet(msg), '🖼️ Стикер');
    });
  });

  group('resolveReplySnippet — voice', () {
    test('voice with duration', () {
      final ApiMessage msg = _msg(msgType: 'voice', mediaDuration: 125);
      expect(
        presenter.resolveReplySnippet(msg),
        '🎤 Голосовое сообщение (2:05)',
      );
    });

    test('voice without duration', () {
      final ApiMessage msg = _msg(msgType: 'voice');
      expect(presenter.resolveReplySnippet(msg), '🎤 Голосовое сообщение');
    });

    test('audio media type is treated as voice', () {
      final ApiMessage msg = _msg(mediaType: 'audio/ogg', mediaDuration: 60);
      expect(
        presenter.resolveReplySnippet(msg),
        '🎤 Голосовое сообщение (1:00)',
      );
    });

    test('zero duration falls back to the plain voice label', () {
      final ApiMessage msg = _msg(msgType: 'voice', mediaDuration: 0);
      expect(presenter.resolveReplySnippet(msg), '🎤 Голосовое сообщение');
    });
  });

  group('resolveReplySnippet — video notes', () {
    for (final String type in <String>[
      'circle',
      'circle_video',
      'video_note',
      'round_video',
    ]) {
      test(type, () {
        expect(
          presenter.resolveReplySnippet(_msg(msgType: type)),
          '📹 Видеосообщение',
        );
      });
    }
  });

  group('resolveReplySnippet — media', () {
    test('image with caption', () {
      final ApiMessage msg = _msg(
        content: 'пляж',
        mediaUrl: 'https://cdn/a.jpg',
        mediaName: 'a.jpg',
      );
      expect(presenter.resolveReplySnippet(msg), '📷 пляж');
    });

    test('image without caption', () {
      final ApiMessage msg = _msg(mediaUrl: 'https://cdn/a.png');
      expect(presenter.resolveReplySnippet(msg), 'Фото');
    });

    test('video with caption', () {
      final ApiMessage msg = _msg(
        content: 'клип',
        mediaUrl: 'https://cdn/a.mp4',
      );
      expect(presenter.resolveReplySnippet(msg), '🎥 клип');
    });

    test('video without caption', () {
      final ApiMessage msg = _msg(mediaUrl: 'https://cdn/a.mov');
      expect(presenter.resolveReplySnippet(msg), 'Видео');
    });

    test('document with caption and name', () {
      final ApiMessage msg = _msg(
        content: 'счёт',
        mediaUrl: 'https://cdn/bill.pdf',
        mediaName: 'bill.pdf',
      );
      expect(presenter.resolveReplySnippet(msg), '📎 bill.pdf • счёт');
    });

    test('document without caption uses the url path as its label', () {
      final ApiMessage msg = _msg(mediaUrl: 'https://cdn/files/report.docx');
      expect(presenter.resolveReplySnippet(msg), '📎 report.docx');
    });

    test('image media type wins without an extension', () {
      final ApiMessage msg = _msg(
        mediaUrl: 'https://cdn/blob/1',
        mediaType: 'image/png',
      );
      expect(presenter.resolveReplySnippet(msg), 'Фото');
    });

    test('video media type wins without an extension', () {
      final ApiMessage msg = _msg(
        mediaUrl: 'https://cdn/blob/2',
        mediaType: 'video/mp4',
      );
      expect(presenter.resolveReplySnippet(msg), 'Видео');
    });
  });

  group('resolveReplySnippet — text', () {
    test('call event', () {
      expect(
        presenter.resolveReplySnippet(_msg(msgType: 'call')),
        '📞 Звонок',
      );
      expect(
        presenter.resolveReplySnippet(_msg(systemEventType: 'call')),
        '📞 Звонок',
      );
    });

    test('empty text and no media', () {
      expect(presenter.resolveReplySnippet(_msg()), 'Сообщение');
    });

    test('plain text is returned trimmed', () {
      expect(
        presenter.resolveReplySnippet(_msg(content: '  привет  ')),
        'привет',
      );
    });

    test('long text is not truncated here (callers trim differently)', () {
      final String long = 'a' * 100;
      expect(presenter.resolveReplySnippet(_msg(content: long)), long);
    });
  });

  group('isVideoMedia', () {
    for (final String ext in <String>[
      '.mp4',
      '.mov',
      '.mkv',
      '.webm',
      '.3gp',
      '.avi',
    ]) {
      test('by url $ext', () {
        expect(
          presenter.isVideoMedia(_msg(), 'https://cdn/clip$ext'),
          isTrue,
        );
      });
      test('by file name $ext', () {
        expect(
          presenter.isVideoMedia(
            _msg(mediaName: 'clip$ext'),
            'https://cdn/blob/1',
          ),
          isTrue,
        );
      });
    }

    test('by media type', () {
      expect(
        presenter.isVideoMedia(
          _msg(mediaType: 'VIDEO/MP4'),
          'https://cdn/blob/1',
        ),
        isTrue,
      );
    });

    test('image is not video', () {
      expect(
        presenter.isVideoMedia(_msg(), 'https://cdn/a.jpg'),
        isFalse,
      );
    });
  });

  group('isImageMedia', () {
    for (final String ext in <String>[
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
      '.svg',
    ]) {
      test('by url $ext', () {
        expect(
          presenter.isImageMedia(_msg(), 'https://cdn/pic$ext'),
          isTrue,
        );
      });
      test('by file name $ext', () {
        expect(
          presenter.isImageMedia(_msg(mediaName: 'pic$ext'), 'https://cdn/1'),
          isTrue,
        );
      });
    }

    test('by media type', () {
      expect(
        presenter.isImageMedia(
          _msg(mediaType: 'Image/PNG'),
          'https://cdn/blob/1',
        ),
        isTrue,
      );
    });

    test('video is not image', () {
      expect(
        presenter.isImageMedia(_msg(), 'https://cdn/a.mp4'),
        isFalse,
      );
    });
  });

  group('mediaUrlFor / extractUrlFromText', () {
    test('direct media url wins', () {
      expect(
        presenter.mediaUrlFor(
          _msg(mediaUrl: ' https://cdn/a.jpg ', content: 'https://b.com'),
        ),
        'https://cdn/a.jpg',
      );
    });

    test('media msg type extracts the first http(s) url from content', () {
      expect(
        presenter.mediaUrlFor(
          _msg(
            msgType: 'media',
            content: 'caption https://cdn/a.jpg?a=1&b=2 tail',
          ),
        ),
        'https://cdn/a.jpg?a=1&b=2',
      );
    });

    test('http url is accepted', () {
      expect(
        presenter.extractUrlFromText('see http://x.dev/p now'),
        'http://x.dev/p',
      );
    });

    test('no url returns null', () {
      expect(presenter.extractUrlFromText('just text'), isNull);
      expect(presenter.mediaUrlFor(_msg(msgType: 'media')), isNull);
      expect(presenter.mediaUrlFor(_msg(msgType: 'text')), isNull);
    });
  });

  group('mediaLabel', () {
    test('explicit media name wins and is trimmed', () {
      expect(
        presenter.mediaLabel(
          _msg(mediaName: '  photo.jpg '),
          'https://cdn/x.png',
        ),
        'photo.jpg',
      );
    });

    test('falls back to the last url segment', () {
      expect(
        presenter.mediaLabel(_msg(), 'https://cdn/dir/clip.mp4'),
        'clip.mp4',
      );
    });

    test('falls back to the localized attachment label', () {
      expect(presenter.mediaLabel(_msg(), 'https://cdn/'), _ru.chatAttachment);
      expect(
        ChatMessagePresenter(_en).mediaLabel(_msg(), 'https://cdn/'),
        _en.chatAttachment,
      );
    });
  });

  group('displayText', () {
    test('plain content', () {
      expect(presenter.displayText(_msg(content: 'hello')), 'hello');
    });

    test('empty content', () {
      expect(presenter.displayText(_msg()), isEmpty);
    });
  });

  group('resolveReplyAuthor', () {
    test('my own message', () {
      expect(_author(_msg(senderId: _myUserId)), 'Вы');
      expect(
        ChatMessagePresenter(_en).resolveReplyAuthor(
          _msg(senderId: _myUserId),
          myUserId: _myUserId,
          chatName: '',
        ),
        'You',
      );
    });

    test('sender display name wins', () {
      expect(_author(_msg(senderDisplayName: 'Анна')), 'Анна');
    });

    test('"unknown" display name falls through to the username', () {
      expect(
        _author(_msg(senderDisplayName: 'unknown', senderUsername: 'anna')),
        '@anna',
      );
    });

    test('username already prefixed with @ is kept', () {
      expect(
        _author(_msg(senderDisplayName: '', senderUsername: '@anna')),
        '@anna',
      );
    });

    test('chat name is the next fallback', () {
      expect(
        _author(
          _msg(senderDisplayName: 'unknown', senderUsername: 'unknown'),
          chatName: '  Рабочий чат ',
        ),
        'Рабочий чат',
      );
    });

    test('localized partner label is the last fallback', () {
      final ApiMessage msg = _msg(
        senderDisplayName: 'unknown',
        senderUsername: 'unknown',
      );
      expect(_author(msg), _ru.chatSenderPartner);
      expect(
        ChatMessagePresenter(_en).resolveReplyAuthor(
          msg,
          myUserId: _myUserId,
          chatName: '   ',
        ),
        _en.chatSenderPartner,
      );
    });
  });

  group('replyPreviewFor', () {
    final ApiMessage target = _msg(id: 5, content: 'исходное');

    test('unknown reply target uses the localized id label', () {
      final ApiMessage msg = _msg(replyToId: 999);
      expect(
        presenter.replyPreviewFor(msg, const {}, myUserId: _myUserId, chatName: ''),
        _ru.chatReplyToId(999),
      );
      expect(
        presenter.replyPreviewFor(msg, const {}, myUserId: _myUserId, chatName: ''),
        'Ответ на #999',
      );
    });

    test('no reply returns null', () {
      expect(
        presenter.replyPreviewFor(
          _msg(),
          const <int, ApiMessage>{},
          myUserId: _myUserId,
          chatName: '',
        ),
        isNull,
      );
    });

    test('author and snippet are joined', () {
      expect(
        presenter.replyPreviewFor(
          _msg(replyToId: 5),
          <int, ApiMessage>{5: target},
          myUserId: _myUserId,
          chatName: '',
        ),
        'Партнёр: исходное',
      );
    });

    test('long previews are cut at 64 characters plus an ellipsis', () {
      final String long = 'x' * 100;
      final String preview = presenter.replyPreviewFor(
        _msg(replyToId: 5),
        <int, ApiMessage>{5: _msg(id: 5, content: long)},
        myUserId: _myUserId,
        chatName: '',
      )!;
      expect(preview.endsWith('...'), isTrue);
      expect(preview.length, 67);
      expect(preview.startsWith('Партнёр: xxxx'), isTrue);
    });

    test('exactly 64 characters is not cut', () {
      final String content = 'y' * (64 - 'Партнёр: '.length);
      final String preview = presenter.replyPreviewFor(
        _msg(replyToId: 5),
        <int, ApiMessage>{5: _msg(id: 5, content: content)},
        myUserId: _myUserId,
        chatName: '',
      )!;
      expect(preview, 'Партнёр: $content');
      expect(preview.endsWith('...'), isFalse);
    });
  });

  group('dateSeparatorLabel', () {
    final DateTime now = DateTime(2026, 11, 28, 15);

    test('today', () {
      expect(
        presenter.dateSeparatorLabel(DateTime(2026, 11, 28, 1), now),
        _ru.chatToday,
      );
      expect(
        ChatMessagePresenter(_en).dateSeparatorLabel(
          DateTime(2026, 11, 28, 1),
          now,
        ),
        _en.chatToday,
      );
    });

    test('yesterday', () {
      expect(
        presenter.dateSeparatorLabel(DateTime(2026, 11, 27, 23), now),
        _ru.chatYesterday,
      );
    });

    test('older dates use the full date format', () {
      final String label = presenter.dateSeparatorLabel(
        DateTime(2025, 1, 15, 12),
        now,
      );
      expect(label, isNotEmpty);
      expect(label, isNot(_ru.chatToday));
      expect(label, isNot(_ru.chatYesterday));
      expect(label, contains('2025'));
    });
  });
}
