import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/quick_camera_capture_screen.dart';
import 'package:universal_io/io.dart';

class CreateChatWizardView extends ConsumerStatefulWidget {
  const CreateChatWizardView({
    this.initialType,
    this.isDialog = false,
    this.lockType = true,
    this.onClose,
    this.onChatCreated,
    super.key,
  });

  final String? initialType;
  final bool isDialog;
  final bool lockType;
  final VoidCallback? onClose;
  final ValueChanged<int>? onChatCreated;

  @override
  ConsumerState<CreateChatWizardView> createState() =>
      _CreateChatWizardViewState();
}

class _CreateChatWizardViewState extends ConsumerState<CreateChatWizardView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  int _step = 0; // 0: Information, 1: Members & Privacy
  late String _chatType;
  bool _isPublic = false;
  bool _commentsEnabled = true;
  bool _busy = false;

  Uint8List? _avatarBytes;
  String? _avatarFileName;

  final Set<int> _selectedUserIds = <int>{};
  final Map<int, String> _selectedUsernames = <int, String>{};
  final Map<int, String?> _selectedUserAvatars = <int, String?>{};

  String _searchQuery = '';

  static String _cleanUsername(String input) {
    final String trimmed = input.trim();
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }

  @override
  void initState() {
    super.initState();
    _chatType = widget.initialType == 'channel' ? 'channel' : 'group';
    _searchController.addListener(() {
      final String q = _searchController.text.trim();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
        ref.read(debouncedSearchProvider.notifier).search(q);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _nameController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _usernameController.text.trim().isNotEmpty ||
      _avatarBytes != null ||
      _selectedUserIds.isNotEmpty;

  void _nextStep() {
    final String name = _nameController.text.trim();
    if (name.length < 3) {
      AppToast.showInfo(context, context.l10n.groupNameTooShort);
      return;
    }
    HapticService.tap();
    setState(() => _step = 1);
  }

  void _previousStep() {
    HapticService.tap();
    setState(() => _step = 0);
  }

  Future<void> _handleCloseRequest() async {
    if (_step == 1) {
      _previousStep();
      return;
    }
    if (!_hasChanges) {
      widget.onClose?.call();
      return;
    }
    final bool? confirm = await showAppConfirmDialog(
      context: context,
      title: context.l10n.dialogCancelChatCreationTitle,
      subtitle: context.l10n.dialogCancelChatCreationBody,
      confirmLabel: context.l10n.commonYes,
      cancelLabel: context.l10n.commonNo,
      icon: Icons.close_rounded,
    );
    if (confirm == true && mounted) {
      widget.onClose?.call();
    }
  }

  Future<void> _pickAvatar() async {
    HapticService.tap();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  _chatType == 'channel'
                      ? sheetCtx.l10n.wizardChannelAvatar
                      : sheetCtx.l10n.wizardGroupAvatar,
                  style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(sheetCtx.l10n.wizardTakePhoto),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final String? photoPath =
                        await QuickCameraCaptureScreen.capturePhoto(context);
                    if (photoPath != null && mounted) {
                      final File f = File(photoPath);
                      final Uint8List bytes = await f.readAsBytes();
                      setState(() {
                        _avatarBytes = bytes;
                        _avatarFileName = f.uri.pathSegments.last;
                      });
                    }
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.secondaryContainer,
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(sheetCtx.l10n.wizardChooseGallery),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final List<PlatformFile> picked =
                        await FilePicker.pickFiles(type: FileType.image);
                    if (picked.isNotEmpty && mounted) {
                      final Uint8List bytes =
                          await picked.first.readAsBytes();
                      if (bytes.isNotEmpty) {
                        setState(() {
                          _avatarBytes = bytes;
                          _avatarFileName = picked.first.name;
                        });
                      }
                    }
                  },
                ),
                if (_avatarBytes != null)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.errorContainer,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    title: Text(
                      sheetCtx.l10n.wizardRemovePhoto,
                      style: TextStyle(color: scheme.error),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      setState(() {
                        _avatarBytes = null;
                        _avatarFileName = null;
                      });
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_busy) return;

    final String name = _nameController.text.trim();
    if (name.length < 3) {
      AppToast.showInfo(context, context.l10n.groupNameTooShort);
      return;
    }

    if (_isPublic) {
      final String username = _cleanUsername(_usernameController.text);
      final RegExp rx = RegExp(r'^[A-Za-z0-9._]{3,32}$');
      if (!rx.hasMatch(username)) {
        AppToast.showInfo(context, context.l10n.groupUsernameRules);
        return;
      }
    }

    setState(() => _busy = true);
    HapticService.tap();

    try {
      final String? publicUsername =
          _isPublic ? _cleanUsername(_usernameController.text) : null;

      final ChatCreateResult? result = await ref
          .read(chatRepositoryProvider)
          .createChat(
            name: name,
            chatType: _chatType,
            description: _descriptionController.text.trim(),
            username: publicUsername,
            commentsEnabled: _chatType == 'channel' ? _commentsEnabled : null,
            isPrivate: !_isPublic,
          );

      if (result == null || result.chatId <= 0) {
        throw ApiException(statusCode: 0, message: 'Could not create chat');
      }

      // Automatically upload avatar if selected
      if (_avatarBytes != null && _avatarBytes!.isNotEmpty) {
        try {
          await ref.read(chatRepositoryProvider).uploadChatAvatar(
                result.chatId,
                _avatarBytes!,
                _avatarFileName ?? 'avatar.jpg',
              );
        } catch (_) {
          // Ignore avatar upload error so chat creation still completes successfully
        }
      }

      if (_chatType == 'group' && _selectedUserIds.isNotEmpty) {
        await ref
            .read(chatRepositoryProvider)
            .inviteUsers(result.chatId, _selectedUserIds.toList());
      }

      await ref.read(chatsProvider.notifier).refresh();

      if (!mounted) return;
      AppToast.showSuccess(
        context,
        _chatType == 'channel'
            ? context.l10n.groupCreatedChannel
            : context.l10n.groupCreatedGroup,
      );
      widget.onChatCreated?.call(result.chatId);
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _handleCloseRequest();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(context, scheme, textTheme),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: M3SpringCurves.spatial,
              switchOutCurve: Curves.easeInCubic,
              child: _step == 0
                  ? _buildStep1Info(context, scheme, textTheme)
                  : _buildStep2MembersAndPrivacy(context, scheme, textTheme),
            ),
          ),
          _buildFooter(context, scheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final bool isChannel = _chatType == 'channel';
    final Color iconContainerColor =
        isChannel ? scheme.tertiaryContainer : scheme.primaryContainer;
    final Color iconColor =
        isChannel ? scheme.onTertiaryContainer : scheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (_step > 0) ...<Widget>[
                IconButton(
                  onPressed: _busy ? null : _previousStep,
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: context.l10n.groupBack,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerLow,
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(38, 38),
                  ),
                ),
                const SizedBox(width: 10),
              ] else ...<Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isChannel ? Icons.campaign_rounded : Icons.groups_rounded,
                    size: 22,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isChannel
                          ? context.l10n.groupNewChannel
                          : context.l10n.groupNewGroup,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      _step == 0
                          ? context.l10n.wizardStep1NameAvatar
                          : (isChannel
                              ? context.l10n.wizardStep2ChannelSettings
                              : context.l10n.wizardStep2GroupMembers),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _handleCloseRequest,
                icon: const Icon(Icons.close_rounded),
                tooltip: context.l10n.commonCancel,
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surfaceContainerLow,
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(38, 38),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List<Widget>.generate(2, (int index) {
              final bool active = index <= _step;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: M3SpringCurves.spatial,
                  margin: EdgeInsets.only(right: index == 0 ? 8 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? (isChannel ? scheme.tertiary : scheme.primary)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Info(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final bool isChannel = _chatType == 'channel';
    final String currentName = _nameController.text.trim();

    String initials = '';
    if (currentName.isNotEmpty) {
      final List<String> parts =
          currentName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = parts[0][0].toUpperCase();
      }
    }

    return SingleChildScrollView(
      key: const ValueKey<int>(0),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Avatar & Name Card ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Avatar Squircle Picker
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: _avatarBytes == null
                              ? LinearGradient(
                                  colors: isChannel
                                      ? <Color>[
                                          scheme.tertiaryContainer,
                                          scheme.primaryContainer,
                                        ]
                                      : <Color>[
                                          scheme.primaryContainer,
                                          scheme.secondaryContainer,
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: _avatarBytes != null
                              ? Image.memory(
                                  _avatarBytes!,
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: initials.isNotEmpty
                                      ? Text(
                                          initials,
                                          style: TextStyle(
                                            color: isChannel
                                                ? scheme.onTertiaryContainer
                                                : scheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 24,
                                          ),
                                        )
                                      : Icon(
                                          isChannel
                                              ? Icons.campaign_rounded
                                              : Icons.groups_rounded,
                                          size: 34,
                                          color: isChannel
                                              ? scheme.onTertiaryContainer
                                              : scheme.onPrimaryContainer,
                                        ),
                                ),
                        ),
                      ),
                      // Camera badge
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isChannel ? scheme.tertiary : scheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.surfaceContainerLow,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: isChannel
                                ? scheme.onTertiary
                                : scheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Name field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: _nameController,
                        onChanged: (String _) => setState(() {}),
                        maxLength: 128,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: isChannel ? context.l10n.wizardChannelName : context.l10n.wizardGroupName,
                          hintText: isChannel
                              ? context.l10n.wizardChannelNameHint
                              : context.l10n.wizardGroupNameHint,
                          filled: true,
                          fillColor: scheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.18),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.18),
                            ),
                          ),
                          counterText: '',
                          suffixIcon: currentName.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _nameController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.wizardTapAvatarHint,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Description field ────────────────────────────────────────
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            maxLength: 512,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: isChannel
                  ? context.l10n.groupDescriptionChannelLabel
                  : context.l10n.groupDescriptionGroupLabel,
              hintText: isChannel
                  ? context.l10n.groupDescriptionChannelHint
                  : context.l10n.groupDescriptionGroupHint,
              prefixIcon: const Icon(Icons.notes_rounded),
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Info Explanatory Card ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isChannel
                  ? scheme.tertiaryContainer.withValues(alpha: 0.35)
                  : scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isChannel ? scheme.tertiary : scheme.primary)
                    .withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  color: isChannel ? scheme.tertiary : scheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isChannel
                        ? context.l10n.wizardChannelDesc
                        : context.l10n.wizardGroupDesc,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2MembersAndPrivacy(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (_chatType == 'group') {
      return _buildGroupStep2(context, scheme, textTheme);
    } else {
      return _buildChannelStep2(context, scheme, textTheme);
    }
  }

  Widget _buildGroupStep2(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final List<ApiChatSummary> chats = ref.watch(chatsProvider).maybeWhen(
          data: (List<ApiChatSummary> list) => list,
          orElse: () => const <ApiChatSummary>[],
        );

    final List<ApiChatSummary> directContacts = chats
        .where((ApiChatSummary c) => c.chatType == 'direct')
        .toList(growable: false);

    return SingleChildScrollView(
      key: const ValueKey<int>(1),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Selected contacts chips
          if (_selectedUsernames.isNotEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.wizardSelectedCount(_selectedUsernames.length),
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedUsernames.entries
                        .map(
                          (MapEntry<int, String> e) => Chip(
                            avatar: PulseAvatar(
                              radius: 12,
                              name: e.value,
                              avatarUrl: _selectedUserAvatars[e.key],
                            ),
                            label: Text(e.value),
                            deleteIcon:
                                const Icon(Icons.close_rounded, size: 16),
                            onDeleted: () {
                              HapticService.tap();
                              setState(() {
                                _selectedUserIds.remove(e.key);
                                _selectedUsernames.remove(e.key);
                                _selectedUserAvatars.remove(e.key);
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Search members input
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.l10n.wizardSearchMembersHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Contact candidates
          Text(
            _searchQuery.isEmpty ? context.l10n.wizardRecentChats : context.l10n.wizardSearchResults,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: _searchQuery.isEmpty
                ? _buildDirectContactsList(directContacts, scheme, textTheme)
                : _buildGlobalSearchResults(scheme, textTheme),
          ),

          const SizedBox(height: 16),
          _privacySection(scheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildDirectContactsList(
    List<ApiChatSummary> contacts,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (contacts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          context.l10n.wizardNoRecentChats,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: contacts.length,
        separatorBuilder: (BuildContext context, int index) => Divider(
          height: 1,
          indent: 56,
          color: scheme.outlineVariant.withValues(alpha: 0.12),
        ),
        itemBuilder: (BuildContext ctx, int index) {
          final ApiChatSummary c = contacts[index];
          final String username = c.username ?? '';
          final bool isSelected = _selectedUsernames.containsValue(c.name);

          return ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            leading: PulseAvatar(
              radius: 18,
              name: c.name,
              avatarUrl: c.avatarUrl,
            ),
            title: Text(
              c.name,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: username.isNotEmpty
                ? Text(
                    '@$username',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  )
                : null,
            trailing: Checkbox(
              value: isSelected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: (bool? val) {
                HapticService.tap();
                setState(() {
                  if (val == true) {
                    _selectedUsernames[c.id] = c.name;
                    _selectedUserAvatars[c.id] = c.avatarUrl;
                  } else {
                    _selectedUsernames.remove(c.id);
                    _selectedUserAvatars.remove(c.id);
                  }
                });
              },
            ),
            onTap: () {
              HapticService.tap();
              setState(() {
                if (isSelected) {
                  _selectedUsernames.remove(c.id);
                  _selectedUserAvatars.remove(c.id);
                } else {
                  _selectedUsernames[c.id] = c.name;
                  _selectedUserAvatars[c.id] = c.avatarUrl;
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildGlobalSearchResults(
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final AsyncValue<ApiSearchResult> searchAsync =
        ref.watch(debouncedSearchProvider);

    return searchAsync.when(
      data: (ApiSearchResult result) {
        if (result.users.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              context.l10n.wizardNoUsersFound(_searchQuery),
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.12),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: result.users.length,
            separatorBuilder: (BuildContext context, int index) => Divider(
              height: 1,
              indent: 56,
              color: scheme.outlineVariant.withValues(alpha: 0.12),
            ),
            itemBuilder: (BuildContext ctx, int index) {
              final ApiSearchUser u = result.users[index];
              final bool isSelected = _selectedUserIds.contains(u.id);

              return ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                leading: PulseAvatar(
                  radius: 18,
                  name: u.displayName.isNotEmpty ? u.displayName : u.username,
                  avatarUrl: u.avatarUrl,
                ),
                title: Text(
                  u.displayName.isNotEmpty ? u.displayName : u.username,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '@${u.username}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                trailing: Checkbox(
                  value: isSelected,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onChanged: (bool? val) {
                    HapticService.tap();
                    setState(() {
                      if (val == true) {
                        _selectedUserIds.add(u.id);
                        _selectedUsernames[u.id] =
                            u.displayName.isNotEmpty ? u.displayName : u.username;
                        _selectedUserAvatars[u.id] = u.avatarUrl;
                      } else {
                        _selectedUserIds.remove(u.id);
                        _selectedUsernames.remove(u.id);
                        _selectedUserAvatars.remove(u.id);
                      }
                    });
                  },
                ),
                onTap: () {
                  HapticService.tap();
                  setState(() {
                    if (isSelected) {
                      _selectedUserIds.remove(u.id);
                      _selectedUsernames.remove(u.id);
                      _selectedUserAvatars.remove(u.id);
                    } else {
                      _selectedUserIds.add(u.id);
                      _selectedUsernames[u.id] =
                          u.displayName.isNotEmpty ? u.displayName : u.username;
                      _selectedUserAvatars[u.id] = u.avatarUrl;
                    }
                  });
                },
              );
            },
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const PulseLoadingIndicator(size: 24),
      ),
      error: (Object error, StackTrace stackTrace) => Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          context.l10n.wizardSearchError,
          style: textTheme.bodySmall?.copyWith(color: scheme.error),
        ),
      ),
    );
  }

  Widget _buildChannelStep2(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      key: const ValueKey<int>(2),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _privacySection(scheme, textTheme),
          const SizedBox(height: 12),

          // Comments switch card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.comment_rounded,
                    color: scheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.groupEnableComments,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.groupEnableCommentsSubtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _commentsEnabled,
                  onChanged: (bool val) {
                    HapticService.tap();
                    setState(() => _commentsEnabled = val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacySection(ColorScheme scheme, TextTheme textTheme) {
    final bool isChannel = _chatType == 'channel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.wizardAccessAndPrivacy,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _privacyCard(
          selected: !_isPublic,
          icon: Icons.lock_rounded,
          title: context.l10n.groupPrivate,
          subtitle: isChannel
              ? context.l10n.wizardPrivateChannelDesc
              : context.l10n.groupPrivateSubtitle,
          scheme: scheme,
          textTheme: textTheme,
          onTap: () {
            HapticService.tap();
            setState(() => _isPublic = false);
          },
        ),
        const SizedBox(height: 8),
        _privacyCard(
          selected: _isPublic,
          icon: Icons.public_rounded,
          title: context.l10n.groupPublic,
          subtitle: isChannel
              ? context.l10n.wizardPublicChannelDesc
              : context.l10n.groupPublicSubtitle,
          scheme: scheme,
          textTheme: textTheme,
          onTap: () {
            HapticService.tap();
            setState(() => _isPublic = true);
          },
        ),
        if (_isPublic) ...<Widget>[
          const SizedBox(height: 10),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: context.l10n.groupPublicUsername,
              hintText: isChannel ? 'channel_username' : 'group_username',
              prefixText: '@',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              helperText: context.l10n.wizardUsernameHelper,
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _privacyCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: M3SpringCurves.spatial,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? (_chatType == 'channel'
                  ? scheme.tertiaryContainer.withValues(alpha: 0.38)
                  : scheme.primaryContainer.withValues(alpha: 0.38))
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (_chatType == 'channel' ? scheme.tertiary : scheme.primary)
                : scheme.outlineVariant.withValues(alpha: 0.14),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? (_chatType == 'channel'
                        ? scheme.tertiary.withValues(alpha: 0.18)
                        : scheme.primary.withValues(alpha: 0.18))
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: selected
                    ? (_chatType == 'channel' ? scheme.tertiary : scheme.primary)
                    : scheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? (_chatType == 'channel' ? scheme.tertiary : scheme.primary)
                  : scheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (_step > 0) ...<Widget>[
            OutlinedButton.icon(
              onPressed: _busy ? null : _previousStep,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(context.l10n.groupBack),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: PulseButton(
              label: _step == 0
                  ? context.l10n.groupContinue
                  : (_chatType == 'channel'
                      ? context.l10n.wizardCreateChannel
                      : context.l10n.wizardCreateGroup),
              icon: _step == 0
                  ? Icons.arrow_forward_rounded
                  : (_chatType == 'channel'
                      ? Icons.campaign_rounded
                      : Icons.check_circle_rounded),
              isLoading: _busy,
              onPressed: _busy ? null : (_step == 0 ? _nextStep : _submit),
            ),
          ),
        ],
      ),
    );
  }
}
