import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';

/// Unified resolver and caching coordinator for sticker packs.
/// Ensures reliable, single-point sticker pack lookups across messages, pickers, and sheets.
class StickerSetResolver {
  StickerSetResolver(this._ref);

  final Ref _ref;

  static final Map<int, ApiStickerSet> _cacheBySetId = <int, ApiStickerSet>{};
  static final Map<int, ApiStickerSet> _cacheByStickerId = <int, ApiStickerSet>{};

  /// Resolves an [ApiStickerSet] containing [stickerId] or matching [knownSetId].
  /// 1. Checks memory cache (O(1)).
  /// 2. Checks local installed sticker sets in Riverpod state.
  /// 3. Performs network fetch via backend repository.
  /// 4. Caches successful result.
  Future<ApiStickerSet?> resolveForSticker({
    required int stickerId,
    int? knownSetId,
  }) async {
    // 1. Fast in-memory cache
    if (knownSetId != null && knownSetId > 0 && _cacheBySetId.containsKey(knownSetId)) {
      final ApiStickerSet? cached = _cacheBySetId[knownSetId];
      if (cached != null && cached.stickers.isNotEmpty) {
        return cached;
      }
    }
    if (stickerId > 0 && _cacheByStickerId.containsKey(stickerId)) {
      final ApiStickerSet? cached = _cacheByStickerId[stickerId];
      if (cached != null && cached.stickers.isNotEmpty) {
        return cached;
      }
    }

    // 2. Local installed sticker sets
    try {
      final List<ApiStickerSet>? installed = _ref.read(stickerSetsProvider).value;
      if (installed != null) {
        final ApiStickerSet? localMatch = installed.cast<ApiStickerSet?>().firstWhere(
          (ApiStickerSet? s) {
            if (s == null || s.stickers.isEmpty) return false;
            if (knownSetId != null && knownSetId > 0 && s.id == knownSetId) {
              return true;
            }
            if (stickerId > 0 && s.stickers.any((ApiSticker st) => st.id == stickerId)) {
              return true;
            }
            return false;
          },
          orElse: () => null,
        );
        if (localMatch != null) {
          recordCache(localMatch);
          return localMatch;
        }
      }
    } catch (e) {
      debugPrint('[StickerSetResolver] Local lookup error: $e');
    }

    // 3. Network fetch from repository
    final StickerRepository repo = _ref.read(stickerRepositoryProvider);
    try {
      ApiStickerSet? fetched;
      if (knownSetId != null && knownSetId > 0) {
        fetched = await repo.getStickerSet(knownSetId);
      }
      if ((fetched == null || fetched.stickers.isEmpty) && stickerId > 0) {
        fetched = await repo.getStickerSetForSticker(stickerId);
      }

      if (fetched != null && fetched.stickers.isNotEmpty) {
        recordCache(fetched);
        return fetched;
      }
    } catch (e) {
      debugPrint('[StickerSetResolver] Network fetch failed: $e');
    }

    return null;
  }

  /// Records a sticker set into memory cache for future instant lookups.
  static void recordCache(ApiStickerSet set) {
    if (set.id > 0) {
      _cacheBySetId[set.id] = set;
    }
    for (final ApiSticker st in set.stickers) {
      if (st.id > 0) {
        _cacheByStickerId[st.id] = set;
      }
    }
  }

  /// Clears the resolution cache (e.g. on logout).
  static void clearCache() {
    _cacheBySetId.clear();
    _cacheByStickerId.clear();
  }
}

final Provider<StickerSetResolver> stickerSetResolverProvider =
    Provider<StickerSetResolver>((Ref ref) => StickerSetResolver(ref));
