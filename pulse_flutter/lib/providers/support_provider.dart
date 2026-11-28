import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/support_ticket_model.dart';
import 'package:pulse_flutter/repositories/support_repository.dart';

/// Everything the support center renders: the ticket list plus the spam-block
/// badge, fetched in one round trip (with the status fallback the backend
/// sometimes requires).
///
/// [loading] and [error] live in the state on purpose: a silent reload must
/// keep the previous tickets and spam block on screen, and a failed reload
/// must keep them behind the error banner exactly as the screen did before.
class SupportCenterData {
  const SupportCenterData({
    required this.tickets,
    this.spamBlock,
    this.error,
    this.loading = false,
  });

  final List<SupportTicket> tickets;
  final SpamBlockStatus? spamBlock;
  final String? error;
  final bool loading;
}

/// Support-center state and mutations.
///
/// The screen only calls methods here; the repository stays inside the
/// provider layer.
class SupportCenterNotifier extends AsyncNotifier<SupportCenterData> {
  @override
  Future<SupportCenterData> build() => _fetch();

  Future<SupportCenterData> _fetch() async {
    final SupportRepository repo = ref.read(supportRepositoryProvider);
    final SupportTicketsBundle bundle = await repo.listTicketsWithStatus();
    SpamBlockStatus? spamBlock = bundle.spamBlock;
    spamBlock ??= (await repo.getStatus()).spamBlock;
    return SupportCenterData(tickets: bundle.tickets, spamBlock: spamBlock);
  }

  Future<void> refresh({bool silent = false}) async {
    final SupportCenterData previous =
        state.value ?? const SupportCenterData(tickets: <SupportTicket>[]);
    if (!silent) {
      state = AsyncData<SupportCenterData>(
        SupportCenterData(
          tickets: previous.tickets,
          spamBlock: previous.spamBlock,
          loading: true,
        ),
      );
    }
    try {
      final SupportCenterData data = await _fetch();
      if (!ref.mounted) return;
      state = AsyncData<SupportCenterData>(data);
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData<SupportCenterData>(
        SupportCenterData(
          tickets: previous.tickets,
          spamBlock: previous.spamBlock,
          error: '$error',
        ),
      );
    }
  }

  Future<SupportTicket?> submitAppeal(String explanation) {
    return ref.read(supportRepositoryProvider).submitSpamAppeal(explanation);
  }

  Future<SupportTicket?> createTicket({
    required String ticketType,
    required String category,
    required String subject,
    required String body,
  }) {
    return ref
        .read(supportRepositoryProvider)
        .createSupportRequest(
          ticketType: ticketType,
          category: category,
          subject: subject,
          body: body,
        );
  }
}

final supportCenterProvider =
    AsyncNotifierProvider.autoDispose<SupportCenterNotifier, SupportCenterData>(
      SupportCenterNotifier.new,
    );
