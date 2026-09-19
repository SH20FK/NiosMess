import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/chat/chat_empty_state.dart';

export 'chat_empty_state.dart';

/// Backward-compatible adapter forwarding to [ChatEmptyState].
class ChatStateSurface extends StatelessWidget {
  const ChatStateSurface({
    super.key,
    required this.variant,
    required this.title,
    required this.description,
    this.icon,
    this.features,
    this.actionLabel,
    this.onAction,
  });

  factory ChatStateSurface.empty({
    Key? key,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatStateSurface(
      key: key,
      variant: ChatEmptyStateVariant.empty,
      icon: Icons.chat_bubble_outline_rounded,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  factory ChatStateSurface.secret({
    Key? key,
    required String title,
    required String description,
    required List<String> features,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatStateSurface(
      key: key,
      variant: ChatEmptyStateVariant.secret,
      icon: Icons.lock_rounded,
      title: title,
      description: description,
      features: features,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  factory ChatStateSurface.offline({
    Key? key,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatStateSurface(
      key: key,
      variant: ChatEmptyStateVariant.offline,
      icon: Icons.wifi_off_rounded,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  factory ChatStateSurface.error({
    Key? key,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatStateSurface(
      key: key,
      variant: ChatEmptyStateVariant.error,
      icon: Icons.sync_problem_rounded,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  final ChatEmptyStateVariant variant;
  final String title;
  final String description;
  final IconData? icon;
  final List<String>? features;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ChatEmptyState(
      variant: variant,
      title: title,
      description: description,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
