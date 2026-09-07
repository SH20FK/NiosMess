import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/repositories/sticker_repository.dart';

export 'package:pulse_flutter/repositories/sticker_repository.dart';

class StickerSetsNotifier extends AsyncNotifier<List<ApiStickerSet>> {
  @override
  Future<List<ApiStickerSet>> build() async {
    return _fetchSets();
  }

  Future<List<ApiStickerSet>> _fetchSets() async {
    final StickerRepository repo = ref.read(stickerRepositoryProvider);
    return repo.listStickerSets();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<ApiStickerSet>>();
    state = await AsyncValue.guard(_fetchSets);
  }

  Future<ApiStickerSet> createStickerSet({
    required String name,
    required String title,
    bool isPublic = true,
  }) async {
    final StickerRepository repo = ref.read(stickerRepositoryProvider);
    final ApiStickerSet newSet = await repo.createStickerSet(
      name: name,
      title: title,
      isPublic: isPublic,
    );

    final List<ApiStickerSet> current = state.value ?? const <ApiStickerSet>[];
    state = AsyncData<List<ApiStickerSet>>(<ApiStickerSet>[...current, newSet]);
    return newSet;
  }

  Future<ApiSticker> addSticker({
    required int setId,
    required String filename,
    required String dataBase64,
    int? width,
    int? height,
    int? durationSeconds,
    String? emoji,
  }) async {
    final StickerRepository repo = ref.read(stickerRepositoryProvider);
    final ApiSticker sticker = await repo.addSticker(
      setId: setId,
      filename: filename,
      dataBase64: dataBase64,
      width: width,
      height: height,
      durationSeconds: durationSeconds,
      emoji: emoji,
    );

    final List<ApiStickerSet> current = state.value ?? const <ApiStickerSet>[];
    final List<ApiStickerSet> updated = current.map((ApiStickerSet s) {
      if (s.id == setId) {
        return s.copyWith(stickers: <ApiSticker>[...s.stickers, sticker]);
      }
      return s;
    }).toList(growable: false);

    state = AsyncData<List<ApiStickerSet>>(updated);
    return sticker;
  }

  Future<void> saveStickerSet(int setId) async {
    final StickerRepository repo = ref.read(stickerRepositoryProvider);
    await repo.saveStickerSet(setId);
    // Reload full list to get updated collection with all stickers
    await refresh();
  }

  Future<void> removeStickerSet(
    int setId, {
    bool deletePermanently = false,
  }) async {
    final StickerRepository repo = ref.read(stickerRepositoryProvider);
    await repo.removeStickerSet(setId, deletePermanently: deletePermanently);

    final List<ApiStickerSet> current = state.value ?? const <ApiStickerSet>[];
    final List<ApiStickerSet> updated =
        current.where((ApiStickerSet s) => s.id != setId).toList(growable: false);
    state = AsyncData<List<ApiStickerSet>>(updated);
  }

  Future<void> deleteSticker(int setId, int stickerId) async {
    final StickerRepository repo = ref.read(stickerRepositoryProvider);
    await repo.deleteSticker(stickerId);

    final List<ApiStickerSet> current = state.value ?? const <ApiStickerSet>[];
    final List<ApiStickerSet> updated = current.map((ApiStickerSet s) {
      if (s.id == setId) {
        return s.copyWith(
          stickers: s.stickers
              .where((ApiSticker st) => st.id != stickerId)
              .toList(growable: false),
        );
      }
      return s;
    }).toList(growable: false);

    state = AsyncData<List<ApiStickerSet>>(updated);
  }
}

final AsyncNotifierProvider<StickerSetsNotifier, List<ApiStickerSet>>
    stickerSetsProvider =
    AsyncNotifierProvider<StickerSetsNotifier, List<ApiStickerSet>>(
  StickerSetsNotifier.new,
);

final stickerSetByIdProvider =
    Provider.family<ApiStickerSet?, int>((Ref ref, int setId) {
  final List<ApiStickerSet> sets =
      ref.watch(stickerSetsProvider).value ?? const <ApiStickerSet>[];
  for (final ApiStickerSet s in sets) {
    if (s.id == setId) return s;
  }
  return null;
});
