import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';

class CreateChatScreen extends ConsumerStatefulWidget {
  const CreateChatScreen({this.initialType, super.key});

  final String? initialType;

  @override
  ConsumerState<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends ConsumerState<CreateChatScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  int _step = 0;
  late String _chatType;
  bool _commentsEnabled = true;
  bool _isPublic = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _chatType = widget.initialType == 'channel' ? 'channel' : 'group';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .createChat(
            name: _nameController.text.trim(),
            chatType: _chatType,
            description: _descriptionController.text.trim(),
            username: _isPublic ? _usernameController.text.trim() : null,
            commentsEnabled: _chatType == 'channel' ? _commentsEnabled : null,
          );

      if (result == null || result.chatId <= 0) {
        throw ApiException(statusCode: 0, message: 'Could not create chat');
      }

      await ref.read(chatsProvider.notifier).refresh();

      if (!mounted) return;
      context.replace('/chat/${result.chatId}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _chatType == 'channel'
                ? context.l10n.groupCreatedChannel
                : context.l10n.groupCreatedGroup,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final String message = error is ApiException
          ? error.message
          : context.l10n.groupCreateFailed('$error');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validateStep() {
    if (_step == 1 && _nameController.text.trim().length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.groupNameTooShort)));
      return false;
    }

    if (_step == 2 && _isPublic) {
      final String username = _usernameController.text.trim();
      final RegExp rx = RegExp(r'^[A-Za-z0-9._]{3,32}$');
      if (!rx.hasMatch(username)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.groupUsernameRules)),
        );
        return false;
      }
    }

    return true;
  }

  void _nextStep() {
    if (!_validateStep()) return;
    if (_step < 3) {
      setState(() => _step += 1);
    }
  }

  void _previousStep() {
    if (_step > 0) {
      setState(() => _step -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Отменить?'),
            content: const Text('Идёт создание чата. Отменить?'),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Нет')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Да')),
            ],
          ),
        );
        if (confirm == true && mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _chatType == 'channel'
                ? context.l10n.groupNewChannel
                : context.l10n.groupNewGroup,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenHorizontalPadding,
              vertical: 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _stepHeader(context),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _stepContent(context, scheme, textTheme),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _previousStep,
                          child: Text(context.l10n.groupBack),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: PulseButton(
                        label: _step == 3
                            ? (_busy
                                  ? context.l10n.groupCreating
                                  : context.l10n.groupCreate)
                            : context.l10n.groupContinue,
                        icon: _step == 3
                            ? Icons.add_circle_outline_rounded
                            : Icons.arrow_forward_rounded,
                        isLoading: _step == 3 ? _busy : false,
                        onPressed: _busy
                            ? null
                            : (_step == 3 ? _submit : _nextStep),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_step < 3)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push('/join'),
                      icon: const Icon(Icons.link_rounded),
                      label: Text(context.l10n.groupAlreadyHaveInvite),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepHeader(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<String> labels = <String>[
      context.l10n.groupTypeStep,
      context.l10n.groupDetailsStep,
      context.l10n.groupPrivacyStep,
      context.l10n.groupReviewStep,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: List<Widget>.generate(labels.length, (int index) {
            final bool active = index <= _step;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: index == labels.length - 1 ? 0 : 8,
                ),
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(labels[_step], style: textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          switch (_step) {
            0 => context.l10n.groupWizardTypeSubtitle,
            1 => context.l10n.groupWizardDetailsSubtitle,
            2 => context.l10n.groupWizardPrivacySubtitle,
            _ => context.l10n.groupWizardReviewSubtitle,
          },
          style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _stepContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return switch (_step) {
      0 => _typeStep(context, scheme, textTheme),
      1 => _detailsStep(context, scheme, textTheme),
      2 => _privacyStep(context, scheme, textTheme),
      _ => _reviewStep(context, scheme, textTheme),
    };
  }

  Widget _typeStep(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    Widget card({
      required String type,
      required IconData icon,
      required String title,
      required String subtitle,
    }) {
      final bool selected = _chatType == type;
      return Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.70)
            : scheme.surfaceContainerLow.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: () => setState(() => _chatType = type),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: 0.14)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 26, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey<String>('type-step'),
      children: <Widget>[
        card(
          type: 'group',
          icon: Icons.groups_rounded,
          title: context.l10n.groupTypeGroup,
          subtitle: context.l10n.groupTypeGroupSubtitle,
        ),
        const SizedBox(height: 12),
        card(
          type: 'channel',
          icon: Icons.campaign_rounded,
          title: context.l10n.groupTypeChannel,
          subtitle: context.l10n.groupTypeChannelSubtitle,
        ),
      ],
    );
  }

  Widget _detailsStep(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Column(
      key: const ValueKey<String>('details-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _chatType == 'channel'
                      ? Icons.campaign_rounded
                      : Icons.groups_rounded,
                  size: 28,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _chatType == 'channel'
                          ? context.l10n.groupYourNewChannel
                          : context.l10n.groupYourNewGroup,
                      style: textTheme.titleLarge,
                    ),
                    Text(
                      context.l10n.groupEditLater,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: context.l10n.groupNameLabel,
            hintText: context.l10n.groupNameHint,
            prefixIcon: Icon(Icons.title_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: _chatType == 'channel'
                ? context.l10n.groupDescriptionChannelLabel
                : context.l10n.groupDescriptionGroupLabel,
            hintText: _chatType == 'channel'
                ? context.l10n.groupDescriptionChannelHint
                : context.l10n.groupDescriptionGroupHint,
            prefixIcon: const Icon(Icons.description_rounded),
          ),
        ),
      ],
    );
  }

  Widget _privacyStep(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    Widget privacyCard({
      required bool selected,
      required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.70)
            : scheme.surfaceContainerLow.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey<String>('privacy-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        privacyCard(
          selected: !_isPublic,
          title: context.l10n.groupPrivate,
          subtitle: context.l10n.groupPrivateSubtitle,
          icon: Icons.lock_rounded,
          onTap: () => setState(() => _isPublic = false),
        ),
        const SizedBox(height: 10),
        privacyCard(
          selected: _isPublic,
          title: context.l10n.groupPublic,
          subtitle: context.l10n.groupPublicSubtitle,
          icon: Icons.public_rounded,
          onTap: () => setState(() => _isPublic = true),
        ),
        if (_isPublic) ...<Widget>[
          const SizedBox(height: 14),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: context.l10n.groupPublicUsername,
              hintText: 'team_updates',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
        ],
        if (_chatType == 'channel') ...<Widget>[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.groupEnableComments,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.groupEnableCommentsSubtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _commentsEnabled,
                  onChanged: (bool value) {
                    setState(() => _commentsEnabled = value);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _reviewStep(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final String effectiveName = _nameController.text.trim().isEmpty
        ? (_chatType == 'channel'
              ? context.l10n.groupNewChannel
              : context.l10n.groupNewGroup)
        : _nameController.text.trim();
    final String description = _descriptionController.text.trim();

    Widget row({required String label, required String value}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: Text(value, style: textTheme.bodyLarge)),
          ],
        ),
      );
    }

    return Column(
      key: const ValueKey<String>('review-step'),
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _chatType == 'channel'
                          ? Icons.campaign_rounded
                          : Icons.groups_rounded,
                      size: 28,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(effectiveName, style: textTheme.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          _chatType == 'channel'
                              ? context.l10n.groupTypeChannel
                              : context.l10n.groupTypeGroup,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              row(
                label: context.l10n.groupVisibility,
                value: _isPublic
                    ? context.l10n.groupPublic
                    : context.l10n.groupPrivate,
              ),
              if (_isPublic)
                row(
                  label: context.l10n.groupUsernameLabel,
                  value: '@${_usernameController.text.trim()}',
                ),
              if (description.isNotEmpty)
                row(label: context.l10n.profileDescription, value: description),
              if (_chatType == 'channel')
                row(
                  label: context.l10n.chatComments,
                  value: _commentsEnabled ? 'Enabled' : 'Disabled',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
