import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';

/// Account-local ballots shared by the feed and every open post screen.
/// Pending choices never count as a confirmed vote or reveal quiz answers.
class FeedPollVote {
  const FeedPollVote({
    this.poll,
    this.choices,
    this.pending = false,
    this.failed = false,
  });
  final Map<String, dynamic>? poll;
  final Set<int>? choices;
  final bool pending;
  final bool failed;
}

class FeedPollSync {
  const FeedPollSync(this.revisions, this.pending, this.order);
  final Map<int, int> revisions;
  final Set<int> pending;
  final int order;
}

class FeedPollVotes extends Notifier<Map<int, FeedPollVote>> {
  int _epoch = 0, _serial = 0, _syncSerial = 0;
  final _revisions = <int, int>{};
  final _lastSync = <int, int>{};

  @override
  Map<int, FeedPollVote> build() {
    ref.watch(
      authProvider.select((a) => (a.session?.userId, a.session?.accessToken)),
    );
    _epoch++;
    _revisions.clear();
    _lastSync.clear();
    return const {};
  }

  FeedPollSync get revisions => FeedPollSync(Map.of(_revisions), {
    for (final entry in state.entries)
      if (entry.value.pending) entry.key,
  }, ++_syncSerial);

  void _put(int id, FeedPollVote vote) {
    final next = {...state, id: vote};
    // Keep pending requests; bound only completed, in-memory UI state.
    for (final key in next.keys.toList()) {
      if (next.length <= 256) break;
      if (!next[key]!.pending && key != id) {
        next.remove(key);
        _revisions.remove(key);
        _lastSync.remove(key);
      }
    }
    state = Map.unmodifiable(next);
  }

  void select(int id, Map<String, dynamic> source, Set<int> choices) {
    if (ref.read(authProvider.notifier).isLoggingOut ||
        ref.read(authProvider).session == null) {
      return;
    }
    final old = state[id];
    if (old?.pending == true) return;
    _revisions[id] = ++_serial;
    _put(
      id,
      FeedPollVote(
        poll: old?.poll ?? source,
        choices: Set.unmodifiable(choices),
      ),
    );
  }

  /// A fetch may replace only ballots untouched since that fetch started.
  void reconcile(FeedPollSync before, List<NgPost> posts) {
    var next = state;
    for (final post in posts) {
      if (post.poll == null || !next.containsKey(post.id)) continue;
      if (before.pending.contains(post.id) ||
          before.order < (_lastSync[post.id] ?? 0) ||
          _revisions[post.id] != before.revisions[post.id] ||
          next[post.id]!.pending ||
          next[post.id]!.failed ||
          next[post.id]!.choices != null) {
        continue;
      }
      _lastSync[post.id] = before.order;
      next = {...next, post.id: FeedPollVote(poll: post.poll)};
    }
    if (!identical(next, state)) state = Map.unmodifiable(next);
  }

  Future<void> vote(
    int id,
    Map<String, dynamic> source,
    Set<int> choices,
  ) async {
    if (ref.read(authProvider.notifier).isLoggingOut ||
        ref.read(authProvider).session == null) {
      return;
    }
    if (state[id]?.pending == true || choices.isEmpty) return;
    final epoch = _epoch;
    final session = ref.read(authProvider).session;
    final identity = (session?.userId, session?.accessToken);
    final revision = _revisions[id] = ++_serial;
    final poll = state[id]?.poll ?? source;
    final items = poll['items'];
    if (items is! List || choices.any((i) => i < 0 || i >= items.length)) {
      return;
    }
    if (poll['kind'] == 'quiz' &&
        (poll['my_choices'] as List? ?? []).isNotEmpty) {
      return;
    }
    final deadline = poll['closes_at'];
    if (poll['closed'] == true ||
        (deadline is int &&
            deadline <= DateTime.now().toUtc().millisecondsSinceEpoch)) {
      return;
    }
    bool current() {
      if (!ref.mounted || epoch != _epoch || _revisions[id] != revision) {
        return false;
      }
      final active = ref.read(authProvider).session;
      return identity == (active?.userId, active?.accessToken) &&
          !ref.read(authProvider.notifier).isLoggingOut;
    }

    _put(
      id,
      FeedPollVote(
        poll: poll,
        choices: Set.unmodifiable(choices),
        pending: true,
      ),
    );
    try {
      final result = await ref.read(customEmojiRequestProvider)(
        'vote_feed_poll',
        {'post_id': id, 'choices': choices.toList()..sort()},
      );
      if (!current()) return;
      final confirmed = result['poll'];
      if (result['error'] != null ||
          confirmed is! Map ||
          confirmed['items'] is! List ||
          (confirmed['items'] as List).any((item) => item is! String) ||
          !listEquals(confirmed['items'] as List, items) ||
          confirmed['kind'] != poll['kind'] ||
          confirmed['counts'] is! List ||
          (confirmed['counts'] as List).length != items.length ||
          (confirmed['counts'] as List).any(
            (count) => count is! num || !count.isFinite || count < 0,
          ) ||
          confirmed['total_voters'] is! num ||
          !(confirmed['total_voters'] as num).isFinite ||
          (confirmed['total_voters'] as num) < 0 ||
          (confirmed['title'] != null && confirmed['title'] is! String) ||
          (confirmed['explanation'] != null &&
              confirmed['explanation'] is! String) ||
          (confirmed['correct'] != null &&
              (confirmed['correct'] is! int ||
                  (confirmed['correct'] as int) < 0 ||
                  (confirmed['correct'] as int) >= items.length)) ||
          confirmed['my_choices'] is! List ||
          (confirmed['my_choices'] as List).isEmpty ||
          (confirmed['my_choices'] as List).any(
            (choice) =>
                choice is! int ||
                choice < 0 ||
                choice >= (confirmed['items'] as List).length,
          )) {
        throw const FormatException('POLL_RESPONSE_INVALID');
      }
      _put(id, FeedPollVote(poll: Map<String, dynamic>.from(confirmed)));
    } catch (error) {
      if (!current()) return;
      debugPrint('[feed_poll] VOTE_FAILED: ${error.runtimeType}');
      _put(
        id,
        FeedPollVote(
          poll: poll,
          choices: Set.unmodifiable(choices),
          failed: true,
        ),
      );
    }
  }
}

final feedPollVotesProvider =
    NotifierProvider<FeedPollVotes, Map<int, FeedPollVote>>(FeedPollVotes.new);
