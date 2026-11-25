import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/wallpaper/presentation/widgets/tabs/colors_tab.dart';
import 'package:pulse_flutter/features/wallpaper/presentation/widgets/tabs/effects_tab.dart';
import 'package:pulse_flutter/features/wallpaper/presentation/widgets/tabs/pattern_tab.dart';
import 'package:pulse_flutter/features/wallpaper/presentation/widgets/tabs/presets_tab.dart';
import 'package:pulse_flutter/features/wallpaper/presentation/widgets/wallpaper_preview_pane.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/providers/chat_wallpaper_provider.dart';
import 'package:pulse_flutter/widgets/settings/settings_pane_scope.dart';

class WallpaperStudioScreen extends ConsumerStatefulWidget {
  const WallpaperStudioScreen({
    this.chatId,
    this.chatTitle,
    this.initialCode,
    this.isEmbedded = false,
    super.key,
  });

  final String? chatId;
  final String? chatTitle;
  final String? initialCode;
  final bool isEmbedded;

  @override
  ConsumerState<WallpaperStudioScreen> createState() =>
      _WallpaperStudioScreenState();
}

class _WallpaperStudioScreenState extends ConsumerState<WallpaperStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ChatWallpaperConfig _draftConfig;
  bool _applyToChatOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final ChatWallpaperState state = ref.read(chatWallpaperProvider);
    if (widget.chatId != null && state.hasCustomWallpaper(widget.chatId!)) {
      _draftConfig = state.forChat(widget.chatId!);
      _applyToChatOnly = true;
    } else {
      _draftConfig = state.global;
    }

    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _importCode(widget.initialCode!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateConfig(ChatWallpaperConfig newConfig) {
    setState(() {
      _draftConfig = newConfig;
    });
  }

  void _applyWallpaper() {
    HapticService.confirm();
    final ChatWallpaperNotifier notifier = ref.read(
      chatWallpaperProvider.notifier,
    );
    if (_applyToChatOnly && widget.chatId != null) {
      notifier.setChatWallpaper(widget.chatId!, _draftConfig);
    } else {
      notifier.updateGlobalConfig(_draftConfig);
    }
    if (mounted) {
      // In the settings pane this returns to the section, not out of the tab.
      closeSettingsPage(context);
    }
  }

  void _importCode(String code) {
    try {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(code)));
      if (decoded is Map<String, dynamic>) {
        setState(() {
          _draftConfig = ChatWallpaperConfig.fromMap(decoded);
        });
      }
    } catch (_) {}
  }

  void _exportCode() {
    try {
      final jsonStr = jsonEncode(_draftConfig.toMap());
      final code = base64Url.encode(utf8.encode(jsonStr));
      Clipboard.setData(ClipboardData(text: code));
      if (mounted) {
        AppToast.showSuccess(context, context.l10n.noticeCopied);
      }
    } catch (_) {}
  }

  void _resetToDefault() {
    setState(() {
      _draftConfig = const ChatWallpaperConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= Breakpoints.medium;

        final Widget scopeRow = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: <Widget>[
              ChoiceChip(
                label: Text(context.l10n.wallpaperForAllChats),
                selected: !_applyToChatOnly,
                onSelected: (bool selected) {
                  if (selected) setState(() => _applyToChatOnly = false);
                },
              ),
              if (widget.chatId != null) ...<Widget>[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    widget.chatTitle != null
                        ? context.l10n.wallpaperForChatNamed(widget.chatTitle!)
                        : context.l10n.wallpaperForThisChat,
                  ),
                  selected: _applyToChatOnly,
                  onSelected: (bool selected) {
                    if (selected) setState(() => _applyToChatOnly = true);
                  },
                ),
              ],
            ],
          ),
        );

        final Widget tabBar = TabBar(
          controller: _tabController,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: <Widget>[
            Tab(text: context.l10n.wallpaperTabPresets),
            Tab(text: context.l10n.wallpaperTabPattern),
            Tab(text: context.l10n.wallpaperTabColors),
            Tab(text: context.l10n.wallpaperTabEffects),
          ],
        );

        final Widget tabView = TabBarView(
          controller: _tabController,
          children: <Widget>[
            PresetsTab(
              currentConfig: _draftConfig,
              onSelectConfig: _updateConfig,
            ),
            PatternTab(config: _draftConfig, onChanged: _updateConfig),
            ColorsTab(config: _draftConfig, onChanged: _updateConfig),
            EffectsTab(config: _draftConfig, onChanged: _updateConfig),
          ],
        );

        final Widget bottomActions = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: _applyWallpaper,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    context.l10n.wallpaperApply,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => closeSettingsPage(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(context.l10n.wallpaperDiscard),
              ),
            ],
          ),
        );

        final PreferredSizeWidget appBar = AppBar(
          // The settings pane has its own way back to the section.
          automaticallyImplyLeading: !widget.isEmbedded,
          title: Text(context.l10n.wallpaperScreenTitle),
          actions: <Widget>[
            MenuAnchor(
              builder:
                  (
                    BuildContext context,
                    MenuController controller,
                    Widget? child,
                  ) => IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).moreButtonTooltip,
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                  ),
              menuChildren: <Widget>[
                MenuItemButton(
                  leadingIcon: const Icon(Icons.restart_alt_rounded),
                  onPressed: _resetToDefault,
                  child: Text(context.l10n.wallpaperResetDefault),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.copy_rounded),
                  onPressed: _exportCode,
                  child: Text(context.l10n.wallpaperCopyCode),
                ),
              ],
            ),
          ],
        );

        if (isWide) {
          // Desktop 55/45 split
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: <Widget>[
                // Left 55% Preview
                Expanded(
                  flex: 55,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: WallpaperPreviewPane(
                      config: _draftConfig,
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
                // Right 45% Inspector
                Expanded(
                  flex: 45,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        scopeRow,
                        tabBar,
                        Expanded(child: tabView),
                        bottomActions,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile layout
        return Scaffold(
          appBar: appBar,
          body: Column(
            children: <Widget>[
              // Sticky top preview pane (~40% of height)
              SizedBox(
                height: constraints.maxHeight * 0.40,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: WallpaperPreviewPane(
                    config: _draftConfig,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              scopeRow,
              tabBar,
              Expanded(child: tabView),
              bottomActions,
            ],
          ),
        );
      },
    );
  }
}
