import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/interactive_message.dart';

InteractiveMessage definition(String kind, {bool multiple = false}) =>
    InteractiveMessage.parse(
      InteractiveMessage.encode({
        'kind': kind,
        'document': 'document-001',
        'title': 'Куда идём?',
        'items': ['В парк', 'В кино', 'Домой'],
        'multiple': multiple,
        if (kind == 'quiz') 'correct': 1,
      }, 'Пример'),
    )!;

ApiMessage action(
  InteractiveMessage doc,
  int id,
  int actor,
  Map<String, dynamic> update, {
  int root = 10,
  bool encrypted = false,
  bool decrypted = false,
}) => ApiMessage.fromJson({
  'id': id,
  'chat_id': 1,
  'sender_id': actor,
  'sender_display_name': 'Участник $actor',
  'reply_to_id': root,
  'content': InteractiveMessage.encode({
    'kind': 'update',
    'document': doc.document,
    'definition': doc.fingerprint,
    'root': root,
    ...update,
  }, 'Изменение'),
  'is_e2ee': encrypted,
}).copyWith(isDecrypted: decrypted);

void main() {
  test('recurring list resets only the due item and keeps assignments', () {
    final start = DateTime.utc(2026, 10, 1, 12);
    final now = start.add(const Duration(days: 8));
    final doc = InteractiveMessage.parse(
      InteractiveMessage.encode({
        'kind': 'list',
        'document': 'repeat-001',
        'title': 'Покупки',
        'items': ['Молоко', 'Хлеб'],
        'repeat_seconds': [604800, 0],
      }, 'Список'),
    )!;
    final events = [
      action(doc, 11, 1, {
        'action': 'check',
        'item': 0,
        'checked': true,
      }).copyWith(sentAt: start.add(const Duration(days: 1))),
      action(doc, 12, 1, {
        'action': 'check',
        'item': 1,
        'checked': true,
      }).copyWith(sentAt: start.add(const Duration(days: 1))),
      action(doc, 13, 1, {
        'action': 'assign',
        'item': 0,
        'assignee': 2,
      }).copyWith(sentAt: start.add(const Duration(days: 2))),
    ];
    final state = InteractiveState(
      doc,
      1,
      events,
      rootId: 10,
      now: now,
      rootSentAt: start,
    );
    expect(state.checked[0], isNull);
    expect(state.checked[1], isTrue);
    expect(state.assigned[0], 2);
    final current = action(doc, 14, 2, {
      'action': 'check',
      'item': 0,
      'checked': true,
    }).copyWith(sentAt: start.add(const Duration(days: 7, hours: 1)));
    final after = InteractiveState(
      doc,
      1,
      [...events, current],
      rootId: 10,
      now: now,
      rootSentAt: start,
    );
    expect(after.checked[0], isTrue);
  });
  test('deadline closes a poll and counts only votes sent before expiry', () {
    final end = DateTime.utc(2026, 10, 27, 12);
    final doc = InteractiveMessage.parse(
      InteractiveMessage.encode({
        'kind': 'poll',
        'document': 'deadline-001',
        'title': 'Вопрос',
        'items': ['Да', 'Нет'],
        'closes_at': end.millisecondsSinceEpoch,
      }, 'Опрос'),
    )!;
    final early = action(doc, 11, 1, {
      'action': 'vote',
      'choices': [0],
    }).copyWith(sentAt: end.subtract(const Duration(seconds: 1)));
    final late = action(doc, 12, 2, {
      'action': 'vote',
      'choices': [1],
    }).copyWith(sentAt: end);
    final state = InteractiveState(
      doc,
      1,
      [early, late],
      rootId: 10,
      now: end.add(const Duration(minutes: 1)),
    );
    expect(state.closed, true);
    expect(state.votes, {
      1: {0},
    });
  });
  test('invalid deadlines and deadlines on lists are rejected', () {
    final base = {
      'v': 1,
      'kind': 'poll',
      'document': 'deadline-002',
      'title': 'Вопрос',
      'items': ['Да', 'Нет'],
      'closes_at': 'tomorrow',
    };
    expect(
      InteractiveMessage.parse(
        'Пример${InteractiveMessage.marker}${jsonEncode(base)}',
      ),
      isNull,
    );
    expect(
      InteractiveMessage.parse(
        'Пример${InteractiveMessage.marker}${jsonEncode({...base, 'kind': 'list', 'closes_at': 123})}',
      ),
      isNull,
    );
  });

  test('one definition hash and stable counts for a thousand authenticated updates', () {
    final parsed = definition('poll');
    final doc = _CountingDefinition(parsed.data, parsed.preview);
    final rows = [for (var i = 0; i < 1000; i++) action(doc, i + 20, i + 100, {'action': 'vote', 'choices': [1]})];
    doc.hashes = 0;
    final state = InteractiveState(doc, 1, rows, rootId: 10);
    expect(state.voters, 1000);
    expect(state.count(1), 1000);
    expect(state.count(0), 0);
    expect(doc.hashes, 1);
  });

  test(
    'poll reduces authenticated actors in server order, deduplicates, replaces and withdraws',
    () {
      final doc = definition('poll', multiple: true);
      final first = action(doc, 11, 1, {
        'action': 'vote',
        'choices': [0, 0, 1],
      });
      final events = [
        action(doc, 14, 2, {'action': 'vote', 'choices': <int>[]}),
        action(doc, 13, 1, {
          'action': 'vote',
          'choices': [2],
        }),
        first,
        first,
        action(doc, 12, 2, {
          'action': 'vote',
          'choices': [1],
        }),
      ];
      final state = InteractiveState(doc, 1, events, rootId: 10);
      expect(state.voters, 1);
      expect(state.count(0), 0);
      expect(state.count(1), 0);
      expect(state.count(2), 1);
    },
  );
  test(
    'single choice rejects multiple selections and out-of-range options',
    () {
      final doc = definition('poll');
      final state = InteractiveState(doc, 1, [
        action(doc, 11, 2, {
          'action': 'vote',
          'choices': [0, 1],
        }),
        action(doc, 12, 3, {
          'action': 'vote',
          'choices': [9],
        }),
      ], rootId: 10);
      expect(state.voters, 0);
    },
  );
  test('quiz keeps first answer across repeated delivery and devices', () {
    final doc = definition('quiz');
    final state = InteractiveState(doc, 1, [
      action(doc, 12, 2, {
        'action': 'vote',
        'choices': [1],
      }),
      action(doc, 11, 2, {
        'action': 'vote',
        'choices': [0],
      }),
      action(doc, 13, 3, {
        'action': 'vote',
        'choices': [1],
      }),
    ], rootId: 10);
    expect(state.votes[2], {0});
    expect(state.voters, 2);
  });
  test('only author closes, later updates are ignored', () {
    final doc = definition('poll');
    final state = InteractiveState(doc, 1, [
      action(doc, 11, 3, {'action': 'close'}),
      action(doc, 12, 2, {
        'action': 'vote',
        'choices': [0],
      }),
      action(doc, 13, 1, {'action': 'close'}),
      action(doc, 14, 2, {
        'action': 'vote',
        'choices': [1],
      }),
    ], rootId: 10);
    expect(state.closed, true);
    expect(state.votes[2], {0});
  });
  test('shared list converges across actors and devices', () {
    final doc = definition('list');
    final state = InteractiveState(doc, 1, [
      action(doc, 13, 2, {'action': 'check', 'item': 0, 'checked': false}),
      action(doc, 11, 1, {'action': 'check', 'item': 0, 'checked': true}),
      action(doc, 12, 3, {'action': 'check', 'item': 1, 'checked': true}),
    ], rootId: 10);
    expect(state.checked, {0: false, 1: true});
  });
  test(
    'wrong root, edited definition, pending, deleted, undecrypted and plaintext injected in E2E do not count',
    () {
      final doc = definition('poll');
      final other = InteractiveMessage.parse(
        InteractiveMessage.encode({...doc.data, 'title': 'Изменён'}, 'Пример'),
      )!;
      final state = InteractiveState(
        doc,
        1,
        [
          action(doc, 11, 2, {
            'action': 'vote',
            'choices': [0],
          }, root: 99),
          action(
            other,
            12,
            2,
            {
              'action': 'vote',
              'choices': [0],
            },
            encrypted: true,
            decrypted: true,
          ),
          action(doc, 13, 2, {
            'action': 'vote',
            'choices': [0],
          }, encrypted: true),
          action(doc, 14, 2, {
            'action': 'vote',
            'choices': [0],
          }),
          action(
            doc,
            15,
            2,
            {
              'action': 'vote',
              'choices': [0],
            },
            encrypted: true,
            decrypted: true,
          ).copyWith(isDeleted: true),
          action(
            doc,
            16,
            2,
            {
              'action': 'vote',
              'choices': [0],
            },
            encrypted: true,
            decrypted: true,
          ).copyWith(isSending: true),
          action(
            doc,
            17,
            3,
            {
              'action': 'vote',
              'choices': [1],
            },
            encrypted: true,
            decrypted: true,
          ),
        ],
        rootId: 10,
        requireE2ee: true,
      );
      expect(state.voters, 1);
      expect(state.votes[3], {1});
    },
  );
  test('malformed and oversized payloads stay ordinary text', () {
    expect(InteractiveMessage.parse('обычная шутка'), null);
    expect(
      InteractiveMessage.parse('Привет${InteractiveMessage.marker}{"v":1}'),
      null,
    );
    expect(InteractiveMessage.parse('x' * 13000), null);
    expect(
      () => InteractiveMessage.encode({
        'kind': 'poll',
        'document': 'doc-0001',
        'title': 'Вопрос',
        'items': ['Один', 'Один'],
      }, 'Тест'),
      throwsFormatException,
    );
  });
}

class _CountingDefinition extends InteractiveMessage {
  _CountingDefinition(super.data, super.preview);
  int hashes = 0;
  @override
  String get fingerprint { hashes++; return super.fingerprint; }
}
