import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsAboutScreen extends StatefulWidget {
  const SettingsAboutScreen({super.key});

  @override
  State<SettingsAboutScreen> createState() => _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends State<SettingsAboutScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
    _packageInfo = PackageInfo.fromPlatform();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              expandedHeight: 0,
              backgroundColor: scheme.surface,
              surfaceTintColor: Colors.transparent,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              title: Text(context.l10n.settingsAboutTitle),
              centerTitle: true,
            ),
            SliverToBoxAdapter(child: _HeroBlock(animation: _heroController)),
            const SliverToBoxAdapter(child: _PremiumBadge()),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  unselectedLabelStyle:
                      Theme.of(context).textTheme.labelLarge,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerHeight: 0,
                  tabs: const <Tab>[
                    Tab(text: '👨‍💻', iconMargin: EdgeInsets.zero),
                    Tab(text: '❓', iconMargin: EdgeInsets.zero),
                    Tab(text: '💖', iconMargin: EdgeInsets.zero),
                    Tab(text: '🎉', iconMargin: EdgeInsets.zero),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: true,
              child: TabBarView(
                children: <Widget>[
                  _DevelopersTab(),
                  _FaqTab(),
                  _SupportTab(packageInfo: _packageInfo),
                  _ChangelogTab(packageInfo: _packageInfo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero Block ────────────────────────────────────────────────────────────

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.animation});
  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.surfaceContainerHigh,
              scheme.surfaceContainerLow,
            ],
          ),
        ),
        child: Column(
          children: <Widget>[
            _AnimatedLogoRow(
              animation: animation,
              scheme: scheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 20),
            _AnimatedTagline(
              animation: animation,
              scheme: scheme,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedLogoRow extends StatelessWidget {
  const _AnimatedLogoRow({
    required this.animation,
    required this.scheme,
    required this.textTheme,
  });
  final AnimationController animation;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    const String nios = 'Nios';
    const String mess = 'Mess';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < nios.length; i++)
          _AnimatedLetter(
            letter: nios[i],
            animation: animation,
            beginDelay: i * 80,
            totalDuration: 800,
            beginY: -30,
            beginX: 0,
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.primary,
              fontSize: 48,
              letterSpacing: -1,
            ) ?? const TextStyle(),
          ),
        const SizedBox(width: 4),
        Transform.rotate(
          angle: 18 * math.pi / 180,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (int i = 0; i < mess.length; i++)
                _AnimatedLetter(
                  letter: mess[i],
                  animation: animation,
                  beginDelay: 400 + i * 80,
                  totalDuration: 800,
                  beginY: 0,
                  beginX: -20,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.secondary,
                    fontSize: 34,
                  ) ?? const TextStyle(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedLetter extends StatelessWidget {
  const _AnimatedLetter({
    required this.letter,
    required this.animation,
    required this.beginDelay,
    required this.totalDuration,
    required this.beginY,
    required this.beginX,
    required this.style,
  });
  final String letter;
  final AnimationController animation;
  final int beginDelay;
  final int totalDuration;
  final double beginY;
  final double beginX;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final double start = beginDelay / totalDuration;
    final double end = math.min(1.0, (beginDelay + 400) / totalDuration);

    final Animation<double> opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );

    final Animation<double> translateY = Tween<double>(begin: beginY, end: 0)
        .animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      ),
    );

    final Animation<double> translateX = Tween<double>(begin: beginX, end: 0)
        .animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return Transform.translate(
          offset: Offset(translateX.value, translateY.value),
          child: Opacity(
            opacity: opacity.value,
            child: Text(letter, style: style),
          ),
        );
      },
    );
  }
}

class _AnimatedTagline extends StatelessWidget {
  const _AnimatedTagline({
    required this.animation,
    required this.scheme,
    required this.textTheme,
  });
  final AnimationController animation;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final Animation<double> opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.6, 0.85, curve: Curves.easeOut),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: opacity.value,
          child: Text(
            'Мессенджер нового поколения',
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

// ─── Premium Badge ─────────────────────────────────────────────────────────

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Следите за обновлениями!')),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                const Text('✨', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'NiosMess Premium — скоро',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      Text(
                        'Ранний доступ',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: scheme.onTertiaryContainer.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Developers Tab ────────────────────────────────────────────────────────

class _DevelopersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<_Developer> developers = <_Developer>[
      _Developer(
        name: 'Sanlsan',
        role: context.l10n.developersSanlsanRole,
        description: context.l10n.developersSanlsanDescription,
        assetPath: 'assets/developers/Sanlsan_clean.png',
        icon: Icons.dns_rounded,
        accentColor: Colors.blue,
        tags: <String>[
          context.l10n.developersTagBackend,
          context.l10n.developersTagApi,
          context.l10n.developersTagAuth,
        ],
      ),
      _Developer(
        name: 'SH20FK',
        role: context.l10n.developersSh20fkRole,
        description: context.l10n.developersSh20fkDescription,
        assetPath: 'assets/developers/SH20FK_clean.png',
        icon: Icons.phone_iphone_rounded,
        accentColor: Colors.purple,
        tags: <String>[
          context.l10n.developersTagFlutter,
          context.l10n.developersTagUx,
          context.l10n.developersTagClient,
        ],
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: developers.length,
      itemBuilder: (BuildContext context, int index) {
        return _DeveloperCard(developer: developers[index]);
      },
    );
  }
}

class _Developer {
  const _Developer({
    required this.name,
    required this.role,
    required this.description,
    required this.assetPath,
    required this.icon,
    required this.accentColor,
    required this.tags,
  });
  final String name;
  final String role;
  final String description;
  final String assetPath;
  final IconData icon;
  final Color accentColor;
  final List<String> tags;
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({required this.developer});
  final _Developer developer;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color accent = developer.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 76,
                height: 76,
                color: accent.withValues(alpha: 0.08),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        developer.icon,
                        size: 48,
                        color: accent.withValues(alpha: 0.07),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        developer.assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? trace,
                        ) {
                          return Center(
                            child: Icon(
                              Icons.person_rounded,
                              size: 32,
                              color: accent.withValues(alpha: 0.5),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          developer.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(developer.icon, color: accent, size: 16),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    developer.role,
                    style: textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    developer.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: developer.tags
                        .map(
                          (String tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag,
                              style: textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FAQ Tab ───────────────────────────────────────────────────────────────

class _FaqTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<(String, String)> faqs = <(String, String)>[
      (
        'Как сбросить пароль?',
        'Перейдите на экран входа и нажмите «Забыли пароль?». Мы отправим письмо с ссылкой для восстановления.',
      ),
      (
        'Что такое секретные чаты?',
        'Секретные чаты используют сквозное шифрование (E2EE). Сообщения доступны только вам и собеседнику.',
      ),
      (
        'Как присоединиться к группе?',
        'Нажмите «+» → «Присоединиться к группе» и введите код приглашения или ссылку.',
      ),
      (
        'Как защититься от спама?',
        'В настройках приватности включите фильтр спама и ограничьте кто может писать вам.',
      ),
      (
        'Где хранятся мои данные?',
        'Данные хранятся на защищённых серверах в России. Секретные чаты не покидают ваши устройства.',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: faqs.length,
      itemBuilder: (BuildContext context, int index) {
        final (String q, String a) = faqs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              q,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  a,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Support Tab ───────────────────────────────────────────────────────────

class _SupportTab extends StatelessWidget {
  const _SupportTab({required this.packageInfo});
  final Future<PackageInfo> packageInfo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        // Donate card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                scheme.primaryContainer,
                scheme.secondaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Поддержите NiosMess',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Проект развивается благодаря вам. Любая сумма помогает нам расти.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _openUrl(context, 'https://boosty.to/niosmess'),
                icon: const Icon(Icons.favorite_rounded, size: 18),
                label: const Text('Задонатить'),
              ),
              const SizedBox(height: 8),
              Text(
                'Visa • Mastercard • СБП',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Support actions
        _SupportAction(
          icon: Icons.support_agent_rounded,
          title: 'Написать в поддержку',
          subtitle: 'support@ni-os.ru',
          iconColor: scheme.primary,
          onTap: () => _composeSupportEmail(
            context,
            subject: 'Поддержка NiosMess',
            body: '',
          ),
        ),
        _SupportAction(
          icon: Icons.bug_report_rounded,
          title: context.l10n.settingsReportIssue,
          subtitle: context.l10n.settingsReportIssueSubtitle,
          iconColor: scheme.error,
          onTap: () => _showReportDialog(context),
        ),
        _SupportAction(
          icon: Icons.link_rounded,
          title: 'Копировать API URL',
          subtitle: ApiConstants.baseUrl,
          iconColor: scheme.secondary,
          onTap: () async {
            await Clipboard.setData(
              const ClipboardData(text: ApiConstants.baseUrl),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.settingsApiUrlCopied)),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsCouldNotOpenLink)),
      );
    }
  }

  Future<void> _composeSupportEmail(
    BuildContext context, {
    required String subject,
    required String body,
  }) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: 'support@ni-os.ru',
      queryParameters: <String, String>{'subject': subject, 'body': body},
    );
    final bool launched = await launchUrl(uri);
    if (!launched) {
      await Clipboard.setData(
        ClipboardData(text: 'support@ni-os.ru\n\n$subject\n\n$body'),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsSupportCopied)),
      );
    }
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final TextEditingController descController = TextEditingController();
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialog(
          title: context.l10n.settingsReportIssue,
          icon: Icons.bug_report_rounded,
          actions: <AppDialogAction>[
            AppDialogAction(
              label: context.l10n.commonCancel,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppDialogAction(
              label: context.l10n.settingsSubmit,
              isPrimary: true,
              onPressed: () async {
                final String description = descController.text.trim();
                Navigator.of(dialogContext).pop();
                await _composeSupportEmail(
                  context,
                  subject: context.l10n.settingsBugReportSubject,
                  body: description.isEmpty
                      ? context.l10n.settingsBugReportEmpty
                      : description,
                );
              },
            ),
          ],
          child: AppTextFieldDialogContent(
            controller: descController,
            hint: context.l10n.settingsReportIssueHint,
            maxLines: 5,
          ),
        );
      },
    );
    descController.dispose();
  }
}

class _SupportAction extends StatelessWidget {
  const _SupportAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ─── Changelog Tab ─────────────────────────────────────────────────────────

class _ChangelogTab extends StatelessWidget {
  const _ChangelogTab({required this.packageInfo});
  final Future<PackageInfo> packageInfo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<_Release> releases = <_Release>[
      _Release(
        version: 'v2.1.0',
        date: '2026',
        changes: <String>[
          'Предиктивный жест назад',
          'Улучшена производительность',
          'Новые темы оформления',
          'Работа в фоне',
        ],
      ),
      _Release(
        version: 'v2.0.5',
        date: '2025',
        changes: <String>[
          'Исправлены лаги в чатах',
          'Обновлён эмодзи-пикер',
          'Улучшены анимации',
        ],
      ),
      _Release(
        version: 'v2.0.0',
        date: '2025',
        changes: <String>[
          'Релиз NiosMess 2.0',
          'Полный редизайн',
          'Сквозное шифрование (E2EE)',
          'Новые emoji и реакции',
        ],
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        for (int i = 0; i < releases.length; i++)
          _ReleaseCard(release: releases[i], isFirst: i == 0),
        const SizedBox(height: 16),
        FutureBuilder<PackageInfo>(
          future: packageInfo,
          builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
            final String version = snapshot.data != null
                ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                : '...';
            return Text(
              'Текущая версия: $version',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            );
          },
        ),
      ],
    );
  }
}

class _Release {
  const _Release({
    required this.version,
    required this.date,
    required this.changes,
  });
  final String version;
  final String date;
  final List<String> changes;
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, this.isFirst = false});
  final _Release release;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isFirst ? scheme.primaryContainer.withValues(alpha: 0.3) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                release.version,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                release.date,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (isFirst) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Latest',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (final String change in release.changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '• ',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      change,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
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
}
