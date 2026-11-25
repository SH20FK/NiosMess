import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/profile/badge_selector_dialog.dart';
import 'package:pulse_flutter/widgets/profile/edit_profile_sheet.dart';
import 'package:pulse_flutter/widgets/profile/my_qr_code_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// The profile part of the Account section: the photo and the actions that
/// change how other people see the account. The settings hub only shows who
/// is signed in; everything that edits the profile starts here.
class AccountProfileSection extends ConsumerStatefulWidget {
  const AccountProfileSection({super.key});

  @override
  ConsumerState<AccountProfileSection> createState() =>
      _AccountProfileSectionState();
}

class _AccountProfileSectionState extends ConsumerState<AccountProfileSection> {
  bool _uploadingAvatar = false;

  Future<void> _uploadAvatar() async {
    if (_uploadingAvatar) return;
    final owner = ref.read(authProvider).session;
    bool ownsSession() =>
        mounted &&
        owner != null &&
        ref.read(authProvider).session?.userId == owner.userId &&
        ref.read(authProvider).session?.accessToken == owner.accessToken &&
        !ref.read(authProvider.notifier).isLoggingOut;
    if (!mounted || !ownsSession()) return;
    setState(() => _uploadingAvatar = true);
    try {
      final choice = await AppModal.showSheet<String>(
        context: context,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SettingsSection(
            children: [
              SettingsListItem.nav(
                icon: Icons.photo_library_outlined,
                title: context.l10n.settingsProfileChoosePhoto,
                subtitle: context.l10n.settingsProfilePhotoHint,
                onTap: () => Navigator.of(sheetContext).pop('photo'),
              ),
              SettingsListItem.nav(
                icon: Icons.videocam_outlined,
                title: context.l10n.settingsProfileChooseVideo,
                subtitle: context.l10n.settingsProfileVideoHint,
                onTap: () => Navigator.of(sheetContext).pop('video'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || choice == null || !ownsSession()) return;
      final isVideo = choice == 'video';
      final result = await FilePicker.pickFiles(
        type: isVideo ? FileType.video : FileType.image,
      );
      if (!mounted || result.isEmpty || !ownsSession()) return;
      final file = result.first;
      final knownLength = file.lengthSync();
      if (knownLength != null && knownLength > 8 * 1024 * 1024) {
        AppToast.showError(context, context.l10n.settingsProfileFileTooLarge);
        return;
      }
      final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
      final detected = FileTypeDetector.detectFromFileName(file.name);
      if (isVideo
          ? !{'mp4', 'mov', 'webm'}.contains(ext) || !detected.isVideo
          : !{'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ||
                !detected.isImage) {
        AppToast.showError(
          context,
          isVideo
              ? context.l10n.settingsProfileVideoFormats
              : context.l10n.settingsProfilePhotoFormats,
        );
        return;
      }
      Uint8List bytes = await file.readAsBytes();
      if (!mounted || bytes.isEmpty || !ownsSession()) return;
      if (bytes.length > 8 * 1024 * 1024) {
        AppToast.showError(context, context.l10n.settingsProfileFileTooLarge);
        return;
      }
      if (!isVideo) {
        bytes =
            await ImageCompressor.compressImageBytes(
              bytes: bytes,
              fileName: file.name,
            ) ??
            bytes;
        if (!mounted || !ownsSession()) return;
      }
      await ref
          .read(authRepositoryProvider)
          .uploadAvatar(bytes, filename: file.name, isVideo: isVideo);
      if (!mounted || !ownsSession()) return;
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted && ownsSession()) {
        AppToast.showSuccess(context, context.l10n.profileAvatarUpdated);
      }
    } catch (_) {
      if (mounted && ownsSession()) {
        AppToast.showError(context, context.l10n.settingsProfileAvatarFailed);
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _shareProfile(String username) async {
    if (ref.read(uiSettingsProvider).haptics) {
      HapticService.tap();
    }
    await Clipboard.setData(
      ClipboardData(text: 'https://ni-os.ru/u/$username'),
    );
    if (!mounted) return;
    AppToast.showSuccess(context, context.l10n.settingsV2ProfileCopied);
  }

  Future<void> _openBadgeSelector(AuthState auth) async {
    final List<int>? updated = await BadgeSelectorDialog.show(
      context,
      initialSelectedBadgeIds: auth.profile?.visibleBadgeIds ?? const <int>[],
    );
    if (updated != null && mounted) {
      await ref.read(authProvider.notifier).refreshProfile();
    }
  }

  Future<void> _openEditProfile(AuthState auth, String displayName) async {
    final bool? updated = await EditProfileSheet.show(
      context,
      initialName: auth.profile?.displayName.isNotEmpty == true
          ? auth.profile!.displayName
          : displayName,
      initialUsername: auth.profile?.username.isNotEmpty == true
          ? auth.profile!.username
          : (auth.session?.username ?? ''),
      initialBio: auth.profile?.bio ?? '',
      initialPhoneNumber: auth.profile?.phoneNumber,
      initialBirthday: auth.profile?.birthday,
      initialWorkingHours: auth.profile?.workingHours,
      onUploadAvatar: _uploadAvatar,
      onEditBadges: () => _openBadgeSelector(auth),
      // The QR code and the profile link are rows of the Account section.
      actions: const <Widget>[],
    );
    if (updated == true && mounted) {
      AppToast.showSuccess(context, context.l10n.settingsProfileSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLocalizations l = context.l10n;
    final String displayName =
        auth.profile?.displayName ??
        auth.session?.displayName ??
        l.profileGuestName;
    final String username =
        auth.profile?.username ?? auth.session?.username ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.lg,
          ),
          // The name is read from the row below; the picture adds nothing
          // for a screen reader.
          child: Center(
            child: ExcludeSemantics(
              child: PulseAvatar(
                name: displayName,
                avatarUrl: auth.profile?.avatarUrl,
                radius: 44,
                fallbackColor: scheme.primaryContainer,
                textColor: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        SettingsSection(
          children: <Widget>[
            SettingsListItem(
              key: const ValueKey<String>('settings-account-photo'),
              type: SettingsListItemType.action,
              icon: Icons.add_a_photo_outlined,
              title: l.settingsProfileChangePhoto,
              pending: _uploadingAvatar,
              onTap: _uploadAvatar,
            ),
            SettingsListItem.nav(
              key: const ValueKey<String>('settings-account-edit'),
              icon: Icons.edit_outlined,
              title: l.profileEdit,
              onTap: () => _openEditProfile(auth, displayName),
            ),
            SettingsListItem.nav(
              key: const ValueKey<String>('settings-account-qr'),
              icon: Icons.qr_code_rounded,
              title: l.settingsV2Qr,
              onTap: () => MyQrCodeSheet.show(context),
            ),
            if (username.isNotEmpty)
              SettingsListItem(
                key: const ValueKey<String>('settings-account-share'),
                type: SettingsListItemType.action,
                icon: Icons.share_outlined,
                title: l.settingsV2Share,
                onTap: () => _shareProfile(username),
              ),
          ],
        ),
      ],
    );
  }
}
