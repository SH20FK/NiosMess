import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class ExpressionSearchField extends StatefulWidget {
  const ExpressionSearchField({
    required this.hint,
    required this.onChanged,
    this.onFocus,
    this.initialValue = '',
    super.key,
  });
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFocus;
  @override
  State<ExpressionSearchField> createState() => _ExpressionSearchFieldState();
}

class _ExpressionSearchFieldState extends State<ExpressionSearchField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
    child: TextField(
      controller: _controller,
      onTap: widget.onFocus,
      onChanged: (query) {
        setState(() {});
        widget.onChanged(query);
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: context.l10n.pickerClearSearch,
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
      ),
    ),
  );
}

class ExpressionPackButton extends StatelessWidget {
  const ExpressionPackButton({
    required this.label,
    required this.selected,
    required this.child,
    required this.onTap,
    super.key,
  });
  final String label;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: selected ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(selected ? 16 : 24),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox.square(
                dimension: 48,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExpressionPackCard extends StatelessWidget {
  const ExpressionPackCard({
    required this.title,
    this.count,
    required this.previews,
    required this.onTap,
    super.key,
  });
  final String title;
  final int? count;
  final List<Widget> previews;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: previews.isEmpty
                      ? [
                          Icon(
                            Icons.collections_outlined,
                            color: scheme.onSurfaceVariant,
                          ),
                        ]
                      : [
                          for (final preview in previews.take(3))
                            Expanded(child: Center(child: preview)),
                        ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (count != null)
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
