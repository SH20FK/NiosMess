import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/bubble_style_provider.dart';

/// Widget for real-time bubble style customization with preview
class BubbleStyleCustomizer extends ConsumerWidget {
  const BubbleStyleCustomizer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bubbleStyle = ref.watch(bubbleStyleProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Preview
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Предпросмотр',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPreviewBubble(
                      isOutgoing: false,
                      style: bubbleStyle,
                      colorScheme: colorScheme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPreviewBubble(
                      isOutgoing: true,
                      style: bubbleStyle,
                      colorScheme: colorScheme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Corner Radius Slider
        _buildSliderSection(
          title: 'Радиус углов',
          value: bubbleStyle.cornerRadius,
          min: 0,
          max: 24,
          onChanged: (value) => ref.read(bubbleStyleProvider.notifier).setCornerRadius(value),
          displayValue: '${bubbleStyle.cornerRadius.toInt()}px',
        ),
        const SizedBox(height: 16),

        // Padding Slider
        _buildSliderSection(
          title: 'Отступы внутри',
          value: bubbleStyle.bubblePadding,
          min: 4,
          max: 24,
          onChanged: (value) => ref.read(bubbleStyleProvider.notifier).setBubblePadding(value),
          displayValue: '${bubbleStyle.bubblePadding.toInt()}px',
        ),
        const SizedBox(height: 16),

        // Toggles
        _buildToggle(
          title: 'Градиент для исходящих',
          value: bubbleStyle.useGradient,
          onChanged: (value) => ref.read(bubbleStyleProvider.notifier).setUseGradient(value),
        ),
        const SizedBox(height: 12),
        _buildToggle(
          title: 'Показывать "хвостик"',
          value: bubbleStyle.showTail,
          onChanged: (value) => ref.read(bubbleStyleProvider.notifier).setShowTail(value),
        ),
        const SizedBox(height: 24),

        // Reset Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => ref.read(bubbleStyleProvider.notifier).resetToDefaults(),
            icon: const Icon(Icons.restore),
            label: const Text('Сбросить настройки'),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewBubble({
    required bool isOutgoing,
    required BubbleStyleState style,
    required ColorScheme colorScheme,
  }) {
    final bgColor = isOutgoing
        ? (style.useGradient
            ? null
            : (style.customOutgoingColor ?? colorScheme.primary))
        : (style.customIncomingColor ?? colorScheme.surfaceContainerHighest);

    Widget bubble = Container(
      padding: EdgeInsets.all(style.bubblePadding),
      decoration: BoxDecoration(
        color: bgColor,
        gradient: isOutgoing && style.useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  style.customOutgoingColor ?? colorScheme.primary,
                  (style.customOutgoingColor ?? colorScheme.primary).withOpacity(0.8),
                ],
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isOutgoing ? style.cornerRadius : (style.showTail ? 4 : style.cornerRadius)),
          bottomRight: Radius.circular(isOutgoing ? (style.showTail ? 4 : style.cornerRadius) : style.cornerRadius),
        ),
      ),
      child: Text(
        isOutgoing ? 'Исходящее' : 'Входящее',
        style: TextStyle(
          color: isOutgoing ? Colors.white : colorScheme.onSurface,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
  }

  Widget _buildSliderSection({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String displayValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Widget that applies bubble style to actual message bubbles
class StyledMessageBubble extends ConsumerWidget {
  final Widget child;
  final bool isOutgoing;
  final EdgeInsets? padding;

  const StyledMessageBubble({
    super.key,
    required this.child,
    required this.isOutgoing,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bubbleStyle = ref.watch(bubbleStyleProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final bgColor = isOutgoing
        ? (bubbleStyle.useGradient
            ? null
            : (bubbleStyle.customOutgoingColor ?? colorScheme.primary))
        : (bubbleStyle.customIncomingColor ?? colorScheme.surfaceContainerHighest);

    return Container(
      padding: padding ?? EdgeInsets.all(bubbleStyle.bubblePadding),
      decoration: BoxDecoration(
        color: bgColor,
        gradient: isOutgoing && bubbleStyle.useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  bubbleStyle.customOutgoingColor ?? colorScheme.primary,
                  (bubbleStyle.customOutgoingColor ?? colorScheme.primary).withOpacity(0.8),
                ],
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isOutgoing ? bubbleStyle.cornerRadius : (bubbleStyle.showTail ? 4 : bubbleStyle.cornerRadius)),
          bottomRight: Radius.circular(isOutgoing ? (bubbleStyle.showTail ? 4 : bubbleStyle.cornerRadius) : bubbleStyle.cornerRadius),
        ),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: isOutgoing ? Colors.white : colorScheme.onSurface,
          fontSize: 15,
          height: 1.4,
        ),
        child: child,
      ),
    );
  }
}
