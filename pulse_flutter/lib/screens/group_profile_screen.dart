import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';

class GroupProfileScreen extends ConsumerWidget {
  const GroupProfileScreen({required this.chatId, super.key});

  final int chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ApiChatSummary? chat = ref.watch(chatByIdProvider(chatId));

    return Scaffold(
      backgroundColor: scheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(''),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/main/chats');
            }
          },
        ),
      ),
      body: chat == null
          ? PulseScaffoldBody(
              maxWidth: 980,
              child: Center(child: Text(context.l10n.chatNotFound)),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 920,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    0, 0, 0,
                    28 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  children: <Widget>[
                    _buildHeader(context, scheme, textTheme, chat),
                    if (chat.description.trim().isNotEmpty)
                      _buildInfoCard(
                        context, scheme, textTheme,
                        title: context.l10n.profileDescription,
                        child: Text(
                          chat.description,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            height: 1.45,
                          ),
                        ),
                      ),
                    if (chat.username != null && chat.username!.trim().isNotEmpty)
                      _buildPublicLink(context, scheme, textTheme, chat),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: PulseButton(
                              label: context.l10n.chatMembers,
                              icon: Icons.people_rounded,
                              onPressed: () => context.push('/chat/$chatId/members'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PulseButton(
                              label: context.l10n.groupProfileShare,
                              icon: Icons.share_rounded,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                  text: chat.inviteLink ?? chat.shareLink ?? 'https://niosmess.com/chat/$chatId',
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(context.l10n.groupProfileLinkCopied)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme, TextTheme textTheme, ApiChatSummary chat) {
    final bool isChannel = chat.chatType == 'channel';
    final IconData typeIcon = isChannel ? Icons.campaign_rounded : Icons.groups_rounded;
    final String typeLabel = isChannel ? context.l10n.groupTypeChannel : context.l10n.groupTypeGroup;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          height: 190,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                scheme.primary.withValues(alpha: 0.8),
                scheme.tertiary.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.screenHorizontalPadding, 110,
            AppConstants.screenHorizontalPadding, 0,
          ),
          child: Material(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.16)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  Hero(
                    tag: 'chat_avatar_${chat.id}',
                    child: PulseAvatar(
                      name: chat.name,
                      avatarUrl: chat.avatarUrl,
                      radius: 44,
                      fallbackColor: scheme.primaryContainer,
                      textColor: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    chat.name,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(typeIcon, size: 16, color: scheme.onPrimaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          typeLabel,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (chat.membersCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${chat.membersCount} ${isChannel ? 'subscribers' : 'members'}',
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, ColorScheme scheme, TextTheme textTheme, {
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: AppConstants.screenHorizontalPadding,
        right: AppConstants.screenHorizontalPadding,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPublicLink(BuildContext context, ColorScheme scheme, TextTheme textTheme, ApiChatSummary chat) {
    return Padding(
      padding: EdgeInsets.only(
        top: 12,
        left: AppConstants.screenHorizontalPadding,
        right: AppConstants.screenHorizontalPadding,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.link_rounded, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.groupProfilePublicLink,
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${chat.username}',
                    style: textTheme.bodyMedium?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '@${chat.username}'));
              },
            ),
          ],
        ),
      ),
    );
  }
}
