import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/support_ticket_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class SupportTicketsBundle {
  const SupportTicketsBundle({
    required this.tickets,
    this.spamBlock,
  });

  final List<SupportTicket> tickets;
  final SpamBlockStatus? spamBlock;
}

class SupportRepository {
  const SupportRepository(this._ref);

  final Ref _ref;

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
    }
    return const <String, dynamic>{};
  }

  Future<SupportStatusOverview> getStatus() async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('support_get_status', payload: <String, dynamic>{});
    return SupportStatusOverview.fromJson(_asMap(response));
  }

  Future<SupportTicket?> createTicket({
    required String ticketType,
    required String subject,
    required String body,
  }) => createSupportRequest(
    ticketType: ticketType,
    subject: subject,
    body: body,
  );

  Future<SupportTicket?> createSupportRequest({
    required String ticketType,
    required String subject,
    required String body,
    String? category,
    String? priority,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'create_support_ticket',
          payload: <String, dynamic>{
            'ticket_type': ticketType,
            'subject': subject,
            'body': body,
            if (category != null && category.isNotEmpty) 'category': category,
            if (priority != null && priority.isNotEmpty) 'priority': priority,
          },
          maxRetries: 0,
        );

    final map = _asMap(response);
    if (map.isNotEmpty) {
      return SupportTicket.fromJson(map);
    }
    return null;
  }

  Future<SupportTicketsBundle> listTicketsWithStatus({
    String? status,
    String? category,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'list_support_tickets',
          payload: <String, dynamic>{
            if (status != null && status.isNotEmpty) 'status': status,
            if (category != null && category.isNotEmpty) 'category': category,
          },
        );

    final map = _asMap(response);
    final rawTickets = map['tickets'];
    final List<SupportTicket> tickets = rawTickets is List
        ? rawTickets
            .whereType<Map>()
            .map((m) => SupportTicket.fromJson(_asMap(m)))
            .toList(growable: false)
        : const <SupportTicket>[];
    final rawSb = map['spam_block'];
    final SpamBlockStatus? sb =
        rawSb is Map ? SpamBlockStatus.fromJson(_asMap(rawSb)) : null;
    return SupportTicketsBundle(tickets: tickets, spamBlock: sb);
  }

  Future<List<SupportTicket>> listTickets() async {
    final bundle = await listTicketsWithStatus();
    return bundle.tickets;
  }

  Future<SupportTicket?> getTicket(int ticketId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'get_support_ticket',
          payload: <String, dynamic>{'ticket_id': ticketId},
        );
    final map = _asMap(response);
    final rawTicket = map['ticket'];
    if (rawTicket is Map) {
      return SupportTicket.fromJson(_asMap(rawTicket));
    }
    return null;
  }

  Future<SupportTicket?> replyTicket(int ticketId, String body) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'reply_support_ticket',
          payload: <String, dynamic>{'ticket_id': ticketId, 'body': body},
          maxRetries: 0,
        );
    final map = _asMap(response);
    final rawTicket = map['ticket'];
    if (rawTicket is Map) {
      return SupportTicket.fromJson(_asMap(rawTicket));
    }
    return null;
  }

  Future<SupportTicket?> closeTicket(int ticketId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'close_support_ticket',
          payload: <String, dynamic>{'ticket_id': ticketId},
        );
    final map = _asMap(response);
    final rawTicket = map['ticket'];
    if (rawTicket is Map) {
      return SupportTicket.fromJson(_asMap(rawTicket));
    }
    return null;
  }

  Future<SupportTicket?> submitSpamAppeal(String explanation) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'submit_spam_appeal',
          payload: <String, dynamic>{'explanation': explanation},
          maxRetries: 0,
        );
    final map = _asMap(response);
    final rawTicket = map['ticket'];
    if (rawTicket is Map) {
      return SupportTicket.fromJson(_asMap(rawTicket));
    }
    return null;
  }
}

final Provider<SupportRepository> supportRepositoryProvider =
    Provider<SupportRepository>((Ref ref) {
      return SupportRepository(ref);
    });
