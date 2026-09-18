import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/screens/group_profile_screen.dart';
import 'package:pulse_flutter/screens/public_profile_screen.dart';

/// Opens user profile responsively: as a smooth right-side slide panel on Desktop (width >= Breakpoints.large)
/// or as a full route push on mobile.
Future<void> openResponsiveProfile(
  BuildContext context, {
  required String username,
}) async {
  final double width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.large) {
    context.push('/profile/$username');
    return;
  }

  await AppModal.showSideSheet<void>(
    context: context,
    barrierLabel: 'Profile',
    width: 440,
    child: PublicProfileScreen(username: username),
  );
}

/// Opens group/channel profile responsively: as a smooth right-side slide panel on Desktop (width >= Breakpoints.large)
/// or as a full route push on mobile.
Future<void> openResponsiveGroupProfile(
  BuildContext context, {
  required int chatId,
}) async {
  final double width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.large) {
    context.push('/chat/$chatId/profile');
    return;
  }

  await AppModal.showSideSheet<void>(
    context: context,
    barrierLabel: 'Chat Info',
    width: 440,
    child: GroupProfileScreen(chatId: chatId),
  );
}
