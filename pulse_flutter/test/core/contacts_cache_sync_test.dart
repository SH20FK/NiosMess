import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/storage/contacts_cache_sync.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';

ApiChatSummary _contact(
  int id, {
  String? name,
  String? username,
  String? avatar,
  int unread = 0,
  String last = '',
}) {
  return ApiChatSummary.fromJson(<String, dynamic>{
    'id': id,
    'chat_type': 'direct',
    'name': name ?? 'Контакт $id',
    'username': username ?? 'user$id',
    'avatar_url': avatar,
    'unread_count': unread,
    'members_count': 2,
    'last_message': <String, dynamic>{
      'id': id * 100 + unread,
      'chat_id': id,
      'sender_id': 5,
      'sender_username': 'user$id',
      'sender_display_name': 'Пир $id',
      'content': last,
      'msg_type': 'text',
    },
  });
}

/// What a message in a chat does to the inbox list: new activity counters, a
/// new last message and a new order.
List<ApiChatSummary> _withMessages(
  List<ApiChatSummary> contacts,
  int round,
) {
  final List<ApiChatSummary> updated = <ApiChatSummary>[
    for (final ApiChatSummary chat in contacts)
      _contact(
        chat.id,
        name: chat.name,
        username: chat.username,
        unread: round,
        last: 'сообщение $round',
      ),
  ];
  return updated.reversed.toList(growable: false);
}

void main() {
  group('ContactsCacheSync', () {
    test('messages never rewrite the contacts cache', () async {
      var writes = 0;
      final ContactsCacheSync sync = ContactsCacheSync(
        save: (_) async => writes++,
        debounce: Duration.zero,
      );
      addTearDown(sync.dispose);
      final List<ApiChatSummary> contacts = <ApiChatSummary>[
        for (var id = 1; id <= 5; id++) _contact(id),
      ];
      sync.submit(contacts);
      await sync.flush();
      expect(writes, 1, reason: 'the first fill writes the cache once');

      for (var round = 1; round <= 100; round++) {
        sync.submit(_withMessages(contacts, round));
        await sync.flush();
      }

      expect(writes, 1, reason: 'unread count, last message and order are not contacts');
    });

    test('a renamed contact is written exactly once', () async {
      var writes = 0;
      List<ApiChatSummary> lastSaved = const <ApiChatSummary>[];
      final ContactsCacheSync sync = ContactsCacheSync(
        save: (List<ApiChatSummary> contacts) async {
          writes++;
          lastSaved = contacts;
        },
        debounce: Duration.zero,
      );
      addTearDown(sync.dispose);
      final List<ApiChatSummary> contacts = <ApiChatSummary>[
        for (var id = 1; id <= 3; id++) _contact(id),
      ];
      sync.submit(contacts);
      await sync.flush();
      expect(writes, 1);
      expect(lastSaved.length, 3);

      for (var round = 1; round <= 100; round++) {
        sync.submit(_withMessages(lastSaved, round));
      }
      await sync.flush();
      expect(writes, 1);

      final List<ApiChatSummary> renamed = <ApiChatSummary>[
        _contact(1, name: 'Новое имя', username: lastSaved.first.username),
        ...lastSaved.skip(1),
      ];
      sync.submit(renamed);
      await sync.flush();
      expect(writes, 2);
      expect(lastSaved.first.name, 'Новое имя');

      for (var round = 101; round <= 200; round++) {
        sync.submit(_withMessages(lastSaved, round));
      }
      await sync.flush();
      expect(writes, 2, reason: 'later traffic does not follow the rename');
    });

    test('a new avatar is written, the same avatar is not', () async {
      var writes = 0;
      final ContactsCacheSync sync = ContactsCacheSync(
        save: (_) async => writes++,
        debounce: Duration.zero,
      );
      addTearDown(sync.dispose);
      sync.submit(<ApiChatSummary>[_contact(1), _contact(2)]);
      await sync.flush();
      expect(writes, 1);

      sync.submit(<ApiChatSummary>[
        _contact(1, avatar: 'https://cdn/one.png'),
        _contact(2),
      ]);
      await sync.flush();
      expect(writes, 2);

      sync.submit(<ApiChatSummary>[
        _contact(1, avatar: 'https://cdn/one.png'),
        _contact(2),
      ]);
      await sync.flush();
      expect(writes, 2);
    });

    test('rapid changes coalesce into one write of the latest list', () async {
      var writes = 0;
      String savedName = '';
      final ContactsCacheSync sync = ContactsCacheSync(
        save: (List<ApiChatSummary> contacts) async {
          writes++;
          savedName = contacts.first.name;
        },
        debounce: const Duration(milliseconds: 5),
      );
      addTearDown(sync.dispose);
      sync.submit(<ApiChatSummary>[_contact(1, name: 'База')]);
      await sync.flush();
      expect(writes, 1);

      for (final String name in <String>['Раз', 'Два', 'Три']) {
        sync.submit(<ApiChatSummary>[_contact(1, name: name)]);
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(writes, 2);
      expect(savedName, 'Три');
    });

    test('fingerprint ignores ordering and compares contact fields', () {
      final List<String> a = ContactsCacheSync.fingerprintOf(<ApiChatSummary>[
        _contact(1),
        _contact(2),
      ]);
      final List<String> reordered = ContactsCacheSync.fingerprintOf(
        <ApiChatSummary>[_contact(2), _contact(1)],
      );
      final List<String> renamed = ContactsCacheSync.fingerprintOf(
        <ApiChatSummary>[_contact(1, name: 'Другое'), _contact(2)],
      );
      expect(reordered, a);
      expect(renamed, isNot(a));
    });
  });
}
