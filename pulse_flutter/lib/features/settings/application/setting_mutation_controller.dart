import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/diagnostics/app_logger.dart';

sealed class SettingMutationState {
  const SettingMutationState();
}

final class MutationIdle extends SettingMutationState {
  const MutationIdle();
}

final class MutationSaving extends SettingMutationState {
  const MutationSaving(this.requestedValue);
  final Object? requestedValue;
}

final class MutationFailed extends SettingMutationState {
  const MutationFailed(this.message);
  final String message;
}

class AsyncSettingController extends Notifier<SettingMutationState> {
  @override
  SettingMutationState build() => const MutationIdle();

  Future<bool> run(Future<void> Function() operation) async {
    if (state is MutationSaving) return false;
    state = const MutationSaving(null);
    try {
      await operation();
      state = const MutationIdle();
      return true;
    } catch (error, stack) {
      AppLogger.instance.warning(
        'settings_mutation_failed: $error\n$stack',
        source: 'settings',
      );
      state = const MutationFailed('Не удалось сохранить изменение');
      return false;
    }
  }
}

final NotifierProvider<AsyncSettingController, SettingMutationState>
    asyncSettingControllerProvider =
        NotifierProvider<AsyncSettingController, SettingMutationState>(
  AsyncSettingController.new,
);
