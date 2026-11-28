import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/bot_detector.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/router/app_navigation.dart';
import 'package:pulse_flutter/widgets/chat/auto_delete_bottom_sheet.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_app_bar.dart';
import 'package:pulse_flutter/widgets/chat/interactive_composer.dart';
import 'package:pulse_flutter/widgets/chat/live_location_card.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';

/// Isolated header scope: the only place the app bar's metadata is watched.
///
/// Every controller entry point arrives as a parameter, so mounting this
/// widget rebuilds the header alone and never the message list or composer.
class ChatHeaderScope extends ConsumerWidget implements PreferredSizeWidget {
  const ChatHeaderScope({
    super.key,
    required this.chatId,
    required this.isDesktopSplit,
    required this.isSecret,
    required this.onBack,
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.onSecurityTap,
  });

  final int chatId;
  final bool isDesktopSplit;
  final bool isSecret;
  final VoidCallback onBack;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onSecurityTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  static IconData chatHeaderIcon(bool isChannel, bool isGroup) {
    if (isChannel) return Icons.campaign_rounded;
    if (isGroup) return Icons.groups_rounded;
    return Icons.person_rounded;
  }

  static String chatSubtitle(
    BuildContext context,
    ApiChatSummary? chat,
    bool isChannel,
    bool isGroup, {
    String? directUsername,
  }) {
    if (chat == null) return '';
    final String description = chat.description.trim();
    final String memberCount = context.l10n.chatMemberCount(chat.membersCount);
    if (isChannel) {
      return description.isEmpty ? memberCount : '$memberCount • $description';
    }
    if (isGroup) {
      return description.isEmpty ? memberCount : '$memberCount • $description';
    }
    if (chat.chatType == 'direct') {
      final String username = (directUsername ?? chat.username ?? '').trim();
      if (username.isEmpty) {
        return description;
      }
      if (description.isEmpty) return '@$username';
      return '@$username • $description';
    }
    return memberCount;
  }

  static String? resolveDirectUsername(
    ApiChatSummary? chat,
    List<ApiChatMember> members,
    int myUserId,
  ) {
    if (chat?.chatType == 'group' || chat?.chatType == 'channel') return null;
    final String chatUsername = (chat?.username ?? '').trim();
    if (chatUsername.isNotEmpty) return chatUsername;

    for (final ApiChatMember member in members) {
      if (member.userId != myUserId && member.username.trim().isNotEmpty) {
        return member.username.trim();
      }
    }
    return null;
  }

  static String resolveDirectDisplayName(
    BuildContext context,
    ApiChatSummary? chat,
    List<ApiChatMember> members,
    int myUserId,
    int chatId,
  ) {
    final String chatName = (chat?.name ?? '').trim();
    if (chatName.isNotEmpty) return chatName;

    for (final ApiChatMember member in members) {
      if (member.userId != myUserId && member.displayName.trim().isNotEmpty) {
        return member.displayName.trim();
      }
    }
    return context.l10n.chatTitleFallback(chatId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatByIdProvider(chatId));
    final List<ApiChatMember> members =
        ref.watch(chatMembersProvider(chatId)).value ?? const <ApiChatMember>[];
    final int myUserId = ref.watch(
      authProvider.select((a) => a.session?.userId ?? -1),
    );

    final bool isChannel = chat?.chatType == 'channel';
    final bool isGroup = chat?.chatType == 'group';
    final String? directUsername = resolveDirectUsername(
      chat,
      members,
      myUserId,
    );
    final String title = chat?.isSaved == true
        ? context.l10n.savedMessagesTitle
        : chat?.chatType == 'direct'
        ? resolveDirectDisplayName(context, chat, members, myUserId, chatId)
        : ((chat?.name ?? '').trim().isNotEmpty
              ? chat!.name.trim()
              : context.l10n.chatTitleFallback(chatId));

    return ChatDetailAppBar(
      onShareLocation:
          chat?.chatType == 'direct' &&
              chat?.isSecret != true &&
              !isSecret &&
              chat?.isBotChat != true &&
              chat?.isSaved != true
          ? () => showLiveLocationComposer(context, ref, chatId)
          : null,
      managementChatId: chat?.topicParentId,
      isSaved: chat?.isSaved == true,
      onScheduledMessages: isSecret || chat?.isSecret == true
          ? null
          : () => AppModal.showSheet<void>(
              context: context,
              isScrollable: true,
              builder: (sheetContext) => SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.75,
                child: ScheduledMessagesScreen(chatId: chatId),
              ),
            ),
      onTopics: isGroup
          ? () => pushAppRoute<void>(
              context,
              '/chat/${chat?.topicParentId ?? chatId}/topics',
              fallback: (_) =>
                  GroupTopicsScreen(chatId: chat?.topicParentId ?? chatId),
            )
          : null,
      onCreateInteractive:
          chat != null &&
              !isSecret &&
              !chat.isSecret &&
              !chat.isBotChat &&
              (chat.chatType == 'direct' || chat.chatType == 'group')
          ? (kind) async {
              final accountId = ref.read(authProvider).session?.userId;
              final content = await showInteractiveComposer(context, kind);
              if (!context.mounted ||
                  content == null ||
                  ref.read(authProvider).session?.userId != accountId) {
                return;
              }
              try {
                await ref
                    .read(chatMessagesProvider(chatId).notifier)
                    .send(content, requestAi: false);
              } catch (error) {
                if (context.mounted) {
                  AppToast.showError(
                    context,
                    context.l10n.interactiveSendFailed,
                  );
                }
              }
            }
          : null,
      chatId: chatId,
      isDesktopSplit: isDesktopSplit,
      title: title,
      avatarUrl: chat?.avatarUrl,
      headerIcon: chatHeaderIcon(isChannel, isGroup),
      statusEmoji: chat?.partnerStatusEmoji,
      isGroup: isGroup,
      isChannel: isChannel,
      isSecret: chat?.isSecret == true || isSecret,
      directUsername: directUsername,
      autoDeleteDuration: chat?.formattedAutoDeleteDuration,
      isVerified:
          chat?.isVerified == true ||
          chat?.username?.toLowerCase() == 'support' ||
          directUsername?.toLowerCase() == 'support',
      isBot:
          chat?.chatType == 'bot' ||
          BotDetector.isBot(chat?.username) ||
          BotDetector.isBot(directUsername),
      isOnline:
          chat?.isSaved != true &&
          chat?.chatType == 'direct' &&
          chat?.isOnline == true,
      onBack: onBack,
      onVoiceCall: onVoiceCall,
      onVideoCall: onVideoCall,
      onSecurityTap: onSecurityTap,
      onAutoDeleteTap: () {
        AutoDeleteBottomSheet.show(
          context,
          chatId: chatId,
          currentAutoDeleteSeconds: chat?.autoDeleteSeconds,
          isSecret: chat?.isSecret == true || isSecret,
        );
      },
      typingSubtitle: chat?.isSaved == true
          ? Text(
              context.l10n.savedMessagesSubtitle,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : _TypingSubtitle(
              chatId: chatId,
              isOnline: chat?.isOnline == true,
              isDirect: chat?.chatType == 'direct' && !isGroup && !isChannel,
              fallback: chatSubtitle(
                context,
                chat,
                isChannel,
                isGroup,
                directUsername: directUsername,
              ),
            ),
    );
  }
}

/// Typing / online line under the header title. Its own widget so a typing
/// ping never rebuilds the rest of the header.
class _TypingSubtitle extends ConsumerWidget {
  const _TypingSubtitle({
    required this.chatId,
    required this.fallback,
    this.isOnline = false,
    this.isDirect = false,
  });
  final int chatId;
  final String fallback;
  final bool isOnline;
  final bool isDirect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(
      typingProvider(chatId).select((TypingState s) => s.typingUserIds.length),
    );
    final String state = count == 1
        ? 'typing'
        : count > 1
        ? 'typing-many'
        : isDirect && isOnline
        ? 'online'
        : 'idle';

    // Every state is a single bodySmall line, so the cross-fade keeps the
    // header height fixed.
    return AnimatedSwitcher(
      duration: context.motionDuration(M3Durations.short4),
      switchInCurve: M3SpringCurves.effectsDefault,
      switchOutCurve: M3SpringCurves.effectsFast,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) =>
          Stack(
            alignment: AlignmentDirectional.centerStart,
            children: <Widget>[...previousChildren, ?currentChild],
          ),
      child: KeyedSubtree(
        key: ValueKey<String>(state),
        child: _content(context, count),
      ),
    );
  }

  Widget _content(BuildContext context, int count) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (count == 1) {
      return Text(
        context.l10n.chatTyping,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          height: 1.05,
        ),
      );
    } else if (count > 1) {
      return Text(
        context.l10n.chatTypingMultiple,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          height: 1.05,
        ),
      );
    }

    if (isDirect && isOnline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6.5,
            height: 6.5,
            margin: const EdgeInsets.only(right: 5),
            decoration: const BoxDecoration(
              color: AppColors.statusOnline,
              shape: BoxShape.circle,
            ),
          ),
          Flexible(
            child: Text(
              context.l10n.online,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.statusOnline,
                fontWeight: FontWeight.w600,
                height: 1.05,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      fallback,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.05,
      ),
    );
  }
}
