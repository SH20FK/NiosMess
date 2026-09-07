import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/support_ticket_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class SupportRepository {
  const SupportRepository(this._ref);

  final Ref _ref;

  Future<SupportTicket?> createTicket({
    required String ticketType,
    required String subject,
    required String body,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('create_support_ticket', payload: <String, dynamic>{
      'ticket_type': ticketType,
      'subject': subject,
      'body': body,
    });

    if (response is Map) {
      return SupportTicket.fromJson(
        response.map(
          (dynamic k, dynamic v) => MapEntry(k.toString(), v),
        ),
      );
    }
    return null;
  }

  Future<List<SupportTicket>> listTickets() async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('list_support_tickets', payload: <String, dynamic>{});

    if (response is Map && response['tickets'] is List) {
      final List list = response['tickets'] as List;
      return list
          .whereType<Map>()
          .map((m) => SupportTicket.fromJson(
                m.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
              ))
          .toList(growable: false);
    }
    return const <SupportTicket>[];
  }
}

final Provider<SupportRepository> supportRepositoryProvider =
    Provider<SupportRepository>((Ref ref) {
  return SupportRepository(ref);
});
