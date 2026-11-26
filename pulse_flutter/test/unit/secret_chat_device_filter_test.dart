import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:test/test.dart';

void main() {
  test('mismatched device secret chats are excluded while active chats stay', () {
    final List<ApiChatSummary> parsed = <Map<String, dynamic>>[
      {
        'id': 1,
        'chat_type': 'direct',
        'name': 'Matching Secret',
        'is_secret': true,
        'key_mismatch': false,
        'unread_count': 0,
        'members_count': 2,
      },
      {
        'id': 2,
        'chat_type': 'direct',
        'name': 'Foreign Device Secret',
        'is_secret': true,
        'key_mismatch': true,
        'unread_count': 3,
        'members_count': 2,
      },
      {
        'id': 3,
        'chat_type': 'group',
        'name': 'Public Group',
        'is_secret': false,
        'unread_count': 0,
        'members_count': 10,
      },
    ].map(ApiChatSummary.fromJson).toList(growable: false);

    final visible = parsed
        .where((c) => !(c.isSecret && c.keyMismatch))
        .toList(growable: false);

    expect(visible.map((c) => c.id).toList(), equals([1, 3]));
  });
}
