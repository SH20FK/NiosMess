import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/encrypted_draft_sync_provider.dart';

class EncryptedDraftConflictNotice extends ConsumerWidget {
  const EncryptedDraftConflictNotice({
    required this.chatId,
    required this.onSelected,
    super.key,
  });
  final int chatId;
  final ValueChanged<String> onSelected;

  Future<void> _compare(BuildContext context, WidgetRef ref) async {
    final sync = ref.read(encryptedDraftSyncProvider);
    if (sync == null) return;
    try {
      final versions = await sync.conflictVersions(chatId);
      if (!context.mounted) return;
      final choice = await AppBottomSheets.show<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Два варианта черновика',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Черновик изменён на двух устройствах. Выберите, какой продолжить.',
                ),
                const SizedBox(height: 20),
                Text(
                  'На этом устройстве',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  versions.local.isEmpty ? 'Пустой черновик' : versions.local,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Оставить этот'),
                ),
                const Divider(height: 32),
                Text(
                  'С другого устройства',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  versions.remote.isEmpty ? 'Пустой черновик' : versions.remote,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Продолжить этот'),
                ),
              ],
            ),
          ),
        ),
      );
      if (choice == null || !context.mounted) return;
      final text = await sync.resolveConflict(
        chatId,
        local: versions.local,
        remote: versions.remote,
        revision: versions.revision,
        keepLocal: choice,
      );
      if (context.mounted) onSelected(text);
    } catch (e) {
      if (context.mounted) AppToast.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts =
        ref.watch(encryptedDraftConflictsProvider).value ?? const <int>{};
    if (!conflicts.contains(chatId)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            SvgPicture.string(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 3 6 6-12 12H3v-6Z"/><path d="m13 5 6 6"/></svg>',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                scheme.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Черновик изменён на другом устройстве'),
            ),
            TextButton(
              onPressed: () => _compare(context, ref),
              child: const Text('Сравнить'),
            ),
          ],
        ),
      ),
    );
  }
}
