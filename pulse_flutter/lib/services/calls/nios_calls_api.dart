import 'dart:convert';
import 'package:http/http.dart' as http;

const String kCallsBaseUrl = 'https://c.ni-os.ru';

class NiosCallsApi {
  final http.Client _client;

  NiosCallsApi({http.Client? client}) : _client = client ?? http.Client();

  Future<CreateRoomResult> createRoom({String? roomId}) async {
    final body = roomId != null ? jsonEncode({'room_id': roomId}) : null;
    final response = await _client.post(
      Uri.parse('$kCallsBaseUrl/create_room'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw NiosCallsException('create_room failed: ${response.statusCode}');
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    final rid = responseBody['room_id'] as String;
    return CreateRoomResult(roomId: rid);
  }

  Future<void> endRoom(String roomId) async {
    final response = await _client.post(
      Uri.parse('$kCallsBaseUrl/end_room'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'room_id': roomId}),
    );

    if (response.statusCode != 200) {
      throw NiosCallsException('end_room failed: ${response.statusCode}');
    }
  }

  void dispose() {
    _client.close();
  }
}

class CreateRoomResult {
  final String roomId;

  const CreateRoomResult({required this.roomId});
}

class NiosCallsException implements Exception {
  final String message;
  const NiosCallsException(this.message);

  @override
  String toString() => 'NiosCallsException: $message';
}
