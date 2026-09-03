import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/screens/group_profile_screen.dart';
import 'package:pulse_flutter/screens/public_profile_screen.dart';

/// Opens user profile responsively: as a smooth right-side slide panel on Desktop (width >= 800)
/// or as a full route push on mobile.
Future<void> openResponsiveProfile(BuildContext context, {required String username}) async {
  final double width = MediaQuery.sizeOf(context).width;
  if (width < 800) {
    context.push('/profile/$username');
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Profile',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, anim1, anim2) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: scheme.surface,
          elevation: 16,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 440,
            height: double.infinity,
            child: PublicProfileScreen(username: username),
          ),
        ),
      );
    },
    transitionBuilder: (dialogContext, anim1, anim2, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

/// Opens group/channel profile responsively: as a smooth right-side slide panel on Desktop (width >= 800)
/// or as a full route push on mobile.
Future<void> openResponsiveGroupProfile(BuildContext context, {required int chatId}) async {
  final double width = MediaQuery.sizeOf(context).width;
  if (width < 800) {
    context.push('/chat/$chatId/profile');
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Chat Info',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, anim1, anim2) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: scheme.surface,
          elevation: 16,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 440,
            height: double.infinity,
            child: GroupProfileScreen(chatId: chatId),
          ),
        ),
      );
    },
    transitionBuilder: (dialogContext, anim1, anim2, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}
