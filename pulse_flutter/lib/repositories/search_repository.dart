import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class SearchRepository {
  const SearchRepository(this._ref);

  final Ref _ref;

  Future<ApiSearchResult> search(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const ApiSearchResult.empty();
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'search',
          payload: <String, dynamic>{'q': trimmed},
        );

    if (response is Map<String, dynamic>) {
      return ApiSearchResult.fromJson(response);
    }
    if (response is Map) {
      return ApiSearchResult.fromJson(
        response.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        ),
      );
    }
    return const ApiSearchResult.empty();
  }
}

final Provider<SearchRepository> searchRepositoryProvider =
    Provider<SearchRepository>((Ref ref) {
      return SearchRepository(ref);
    });
