import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/live_location.dart';
import 'package:pulse_flutter/providers/live_location_provider.dart';

class LocationIcon extends StatelessWidget {
  const LocationIcon({this.color, super.key});
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>',
    width: 20,
    height: 20,
    colorFilter: ColorFilter.mode(
      color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      BlendMode.srcIn,
    ),
  );
}

Future<void> showLiveLocationComposer(
  BuildContext context,
  WidgetRef ref,
  int chatId,
) async {
  final service = ref.read(liveLocationProvider);
  if (service == null) return;
  final duration = await AppBottomSheets.show<Duration>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Передавать геопозицию',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Передача завершится автоматически. Остановить её можно в сообщении. Если приложение закрыто системой, координаты перестанут обновляться.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(const Duration(minutes: 15)),
              child: const Text('15 минут'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(const Duration(hours: 1)),
              child: const Text('1 час'),
            ),
          ],
        ),
      ),
    ),
  );
  if (duration == null || !context.mounted) return;
  try {
    AppToast.showInfo(context, 'Определяю геопозицию…');
    await service.start(chatId, duration);
    if (context.mounted) {
      AppToast.showSuccess(context, 'Передача геопозиции началась');
    }
  } catch (e) {
    if (context.mounted) AppToast.showError(context, e);
  }
}

class LiveLocationCard extends ConsumerStatefulWidget {
  const LiveLocationCard({
    required this.location,
    required this.chatId,
    required this.foreground,
    super.key,
  });
  final LiveLocation location;
  final int chatId;
  final Color foreground;
  @override
  ConsumerState<LiveLocationCard> createState() => _LiveLocationCardState();
}

class _LiveLocationCardState extends ConsumerState<LiveLocationCard> {
  Timer? _timer;
  bool _stopping = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(liveLocationChangesProvider);
    final service = ref.read(liveLocationProvider);
    final location = widget.location;
    final sharing = service?.isSharing(widget.chatId, location.id) == true;
    final active =
        location.activeAt(DateTime.now().toUtc()) &&
        service?.stopped.contains(location.id) != true;
    final time = TimeOfDay.fromDateTime(
      location.updatedAt.toLocal(),
    ).format(context);
    final until = TimeOfDay.fromDateTime(
      location.expiresAt.toLocal(),
    ).format(context);
    final style = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              LocationIcon(color: widget.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Геопозиция',
                  style: style.titleSmall?.copyWith(color: widget.foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
            style: style.bodyMedium?.copyWith(color: widget.foreground),
          ),
          const SizedBox(height: 4),
          Text(
            'Обновлено в $time · точность ${location.accuracy.round()} м',
            style: style.bodySmall?.copyWith(color: widget.foreground),
          ),
          const SizedBox(height: 4),
          Text(
            active ? 'Передача до $until' : 'Передача завершена',
            style: style.bodySmall?.copyWith(color: widget.foreground),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () async {
                // Explicit user click opens the external map; there are no automatic map requests.
                final uri =
                    Uri.https('www.openstreetmap.org', '/', {
                      'mlat': '${location.latitude}',
                      'mlon': '${location.longitude}',
                    }).replace(
                      fragment:
                          'map=16/${location.latitude}/${location.longitude}',
                    );
                if (!await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    ) &&
                    context.mounted) {
                  AppToast.showError(context, 'Не удалось открыть карту');
                }
              },
              child: const Text('Открыть на карте'),
            ),
          ),
          if (sharing && active)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _stopping
                    ? null
                    : () async {
                        setState(() => _stopping = true);
                        try {
                          await service!.stop(widget.chatId);
                        } catch (_) {
                          if (context.mounted) {
                            AppToast.showInfo(
                              context,
                              'Геопозиция больше не передаётся. Собеседник пока видит последнее полученное положение.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _stopping = false);
                        }
                      },
                child: Text(_stopping ? 'Останавливаю…' : 'Остановить'),
              ),
            ),
        ],
      ),
    );
  }
}
