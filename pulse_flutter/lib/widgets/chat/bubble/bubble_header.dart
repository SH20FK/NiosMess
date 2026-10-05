import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';

class ForwardedPayload {
  const ForwardedPayload({required this.sender, required this.body});

  final String sender;
  final String body;
}

class MessageBubbleHeader extends StatelessWidget {
  const MessageBubbleHeader({
    required this.isMine,
    required this.senderDisplayName,
    required this.senderAvatarUrl,
    required this.visibleBadges,
    required this.hiddenBadgeCount,
    required this.scheme,
    required this.textTheme,
    super.key,
  });

  final bool isMine;
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  final List<ApiBadge> visibleBadges;
  final int hiddenBadgeCount;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (isMine ||
        ((senderDisplayName ?? '').trim().isEmpty && visibleBadges.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[
          if (senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: ApiConstants.resolve(senderAvatarUrl),
                httpHeaders: cachedAuthHeaders(),
                width: 16,
                height: 16,
                memCacheWidth: 32,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if ((senderDisplayName ?? '').trim().isNotEmpty)
            Text(
              senderDisplayName!,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.avatarColorFor(
                  senderDisplayName!,
                  scheme,
                ),
              ),
            ),
          ...visibleBadges.map(
            (ApiBadge badge) => BadgeChip(
              id: badge.id,
              name: badge.name,
              icon: badge.icon,
              color: badge.color,
              interactive: false,
            ),
          ),
          if (hiddenBadgeCount > 0) BadgeOverflowChip(count: hiddenBadgeCount),
        ],
      ),
    );
  }
}

