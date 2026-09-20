import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

enum LegalDocType { privacy, tos, consent }

class LegalViewerScreen extends ConsumerStatefulWidget {
  const LegalViewerScreen({
    required this.docType,
    this.initialContent,
    super.key,
  });

  final LegalDocType docType;
  final String? initialContent;

  @override
  ConsumerState<LegalViewerScreen> createState() => _LegalViewerScreenState();
}

class _LegalViewerScreenState extends ConsumerState<LegalViewerScreen> {
  String _rawContent = '';
  bool _loading = true;
  _ParsedLegalDoc? _parsedDoc;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _sectionKeys = <int, GlobalKey>{};
  bool _searchActive = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _rawContent = widget.initialContent!;
      _parsedDoc = _parseDoc(widget.initialContent!);
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadContent();
        }
      });
    }
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    String assetPath;
    try {
      final String locale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'ru';
      switch (widget.docType) {
        case LegalDocType.privacy:
          assetPath = 'assets/legal/Privacy.txt';
          break;
        case LegalDocType.tos:
          assetPath = 'assets/legal/ToS.txt';
          break;
        case LegalDocType.consent:
          assetPath = locale == 'ru'
              ? 'assets/legal/Consent_RU.txt'
              : 'assets/legal/Consent_EN.txt';
          break;
      }
      final String text = await rootBundle.loadString(assetPath);
      if (mounted) {
        setState(() {
          _rawContent = text;
          _parsedDoc = _parseDoc(text);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rawContent = 'Не удалось загрузить документ: $e';
          _parsedDoc = null;
          _loading = false;
        });
      }
    }
  }

  _ParsedLegalDoc _parseDoc(String text) {
    final List<String> rawLines = text.split('\n');
    String title = '';
    String? effectiveDate;
    final List<String> preamble = <String>[];
    final List<_LegalSection> sections = <_LegalSection>[];
    final List<String> closingNotes = <String>[];

    int lineIndex = 0;
    // 1. Extract title (strip markdown hashes and asterisks)
    while (lineIndex < rawLines.length && rawLines[lineIndex].trim().isEmpty) {
      lineIndex++;
    }
    if (lineIndex < rawLines.length) {
      title = rawLines[lineIndex]
          .replaceFirst(RegExp(r'^#+\s*'), '')
          .replaceAll('*', '')
          .trim();
      lineIndex++;
    }

    // 2. Extract date and sections
    // Matches both "1. Section" and "## 1. Section"
    final RegExp sectionHeaderRegex = RegExp(r'^(?:##\s+)?(\d+)\.\s+(.*)');
    bool inPreamble = true;
    _LegalSection? currentSection;

    for (; lineIndex < rawLines.length; lineIndex++) {
      final String line = rawLines[lineIndex].trim();
      if (line.isEmpty) continue;

      final String lower = line.toLowerCase();
      if (lower.contains('effective date:') ||
          lower.contains('last updated:') ||
          lower.contains('дата вступления в силу:')) {
        effectiveDate = line.replaceAll('*', '').trim();
        continue;
      }

      final Match? match = sectionHeaderRegex.firstMatch(line);
      if (match != null) {
        inPreamble = false;
        if (currentSection != null) {
          sections.add(currentSection);
        }
        final String number = match.group(1)!;
        final String cleanTitle = match.group(2)!.replaceAll('*', '').trim();
        currentSection = _LegalSection(
          number: number,
          title: cleanTitle,
          paragraphs: <String>[],
          category: _detectCategory(cleanTitle),
        );
        continue;
      }

      if (inPreamble) {
        preamble.add(line);
      } else if (currentSection != null) {
        // If line is closing confirmation (like "Настоящим я подтверждаю...")
        if (line.startsWith('Настоящим я подтверждаю') ||
            line.startsWith('I hereby confirm')) {
          sections.add(currentSection);
          currentSection = null;
          closingNotes.add(line);
        } else {
          currentSection.paragraphs.add(line);
        }
      } else {
        closingNotes.add(line);
      }
    }

    if (currentSection != null) {
      sections.add(currentSection);
    }

    // Calculate reading time
    final int words = text.split(RegExp(r'\s+')).length;
    final int readMinutes = math.max(1, (words / 170).ceil());

    return _ParsedLegalDoc(
      title: title,
      effectiveDate: effectiveDate,
      readingTimeMinutes: readMinutes,
      preamble: preamble,
      sections: sections,
      closingNotes: closingNotes,
    );
  }

  String get _screenTitle {
    switch (widget.docType) {
      case LegalDocType.privacy:
        return context.l10n.legalPrivacyTitle;
      case LegalDocType.tos:
        return context.l10n.legalToSTitle;
      case LegalDocType.consent:
        return context.l10n.legalConsentTitle;
    }
  }

  IconData get _docIcon {
    switch (widget.docType) {
      case LegalDocType.privacy:
        return Icons.shield_outlined;
      case LegalDocType.tos:
        return Icons.gavel_rounded;
      case LegalDocType.consent:
        return Icons.verified_user_outlined;
    }
  }

  void _scrollToSection(int index) {
    HapticService.selection();
    final GlobalKey? key = _sectionKeys[index];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        alignment: 0.08,
      );
    }
  }

  void _copyDocument() {
    Clipboard.setData(ClipboardData(text: _rawContent));
    HapticService.lightImpact();
    AppToast.showSuccess(context, 'Текст документа скопирован');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: _searchActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Поиск по документу...',
                  hintStyle: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                ),
              )
            : Text(
                _screenTitle,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: scheme.onSurface,
                ),
              ),
        centerTitle: false,
        backgroundColor: scheme.surface,
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_searchActive)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Закрыть поиск',
              onPressed: () {
                setState(() {
                  _searchActive = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Поиск в документе',
              onPressed: () {
                setState(() => _searchActive = true);
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Скопировать текст',
              onPressed: _copyDocument,
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : _parsedDoc == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_rawContent, textAlign: TextAlign.center),
                    ),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Hero Document Header ────────────────────────
                            _buildHeroHeader(scheme, textTheme),
                            const SizedBox(height: 16),

                            // ── Sticky / Scrollable Section Chips Bar ────────
                            if (_searchQuery.isEmpty &&
                                _parsedDoc!.sections.isNotEmpty) ...[
                              _buildSectionChipsBar(scheme, textTheme),
                              const SizedBox(height: 16),
                            ],

                            // ── Preamble Card ───────────────────────────────
                            if (_parsedDoc!.preamble.isNotEmpty) ...[
                              _buildPreambleCard(scheme, textTheme),
                              const SizedBox(height: 16),
                            ],

                            // ── Document Sections & Body ────────────────────
                            for (int i = 0; i < _parsedDoc!.sections.length; i++) ...[
                              if (_searchQuery.isEmpty ||
                                  _parsedDoc!.sections[i].title
                                      .toLowerCase()
                                      .contains(_searchQuery) ||
                                  _parsedDoc!.sections[i].paragraphs
                                      .any((p) => p.toLowerCase().contains(_searchQuery))) ...[
                                Padding(
                                  key: _sectionKeys.putIfAbsent(i, () => GlobalKey()),
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildSectionCard(
                                    _parsedDoc!.sections[i],
                                    i,
                                    scheme,
                                    textTheme,
                                  ),
                                ),
                              ],
                            ],

                            // ── Closing Notes / Confirmation ────────────────
                            if (_parsedDoc!.closingNotes.isNotEmpty)
                              _buildClosingNotesCard(scheme, textTheme),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
      bottomNavigationBar: _buildBottomConfirmBar(scheme, textTheme),
    );
  }

  Widget _buildHeroHeader(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Icon(_docIcon, size: 26, color: scheme.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _screenTitle,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NiosMess Official Agreement',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Metadata Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_parsedDoc?.effectiveDate != null)
                _buildInfoBadge(
                  icon: Icons.calendar_today_rounded,
                  label: _parsedDoc!.effectiveDate!,
                  scheme: scheme,
                  textTheme: textTheme,
                ),
              _buildInfoBadge(
                icon: Icons.schedule_rounded,
                label: '~${_parsedDoc?.readingTimeMinutes ?? 2} мин. чтения',
                scheme: scheme,
                textTheme: textTheme,
              ),
              if (_parsedDoc != null && _parsedDoc!.sections.isNotEmpty)
                _buildInfoBadge(
                  icon: Icons.format_list_numbered_rounded,
                  label: '${_parsedDoc!.sections.length} разделов',
                  scheme: scheme,
                  textTheme: textTheme,
                ),
              _buildInfoBadge(
                icon: Icons.verified_rounded,
                label: 'GDPR & E2EE Verified',
                scheme: scheme,
                textTheme: textTheme,
                isAccent: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required ColorScheme scheme,
    required TextTheme textTheme,
    bool isAccent = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAccent
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAccent
              ? scheme.primary.withValues(alpha: 0.3)
              : scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isAccent ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: isAccent ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionChipsBar(ColorScheme scheme, TextTheme textTheme) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _parsedDoc!.sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final _LegalSection section = _parsedDoc!.sections[index];
          final bool isSpecial = section.isSecurity;
          return ActionChip(
            avatar: CircleAvatar(
              radius: 10,
              backgroundColor: isSpecial ? scheme.primary : scheme.primaryContainer,
              child: Text(
                section.number,
                style: textTheme.labelSmall?.copyWith(
                  color: isSpecial ? scheme.onPrimary : scheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
            label: Text(
              section.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
            backgroundColor: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSpecial
                    ? scheme.primary.withValues(alpha: 0.4)
                    : scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            onPressed: () => _scrollToSection(index),
          );
        },
      ),
    );
  }

  Widget _buildPreambleCard(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _parsedDoc!.preamble.map((String p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text.rich(
              TextSpan(
                children: _parseMarkdownSpans(
                  p,
                  scheme: scheme,
                  textTheme: textTheme,
                ),
              ),
              style: textTheme.bodyMedium?.copyWith(
                height: 1.55,
                color: scheme.onSurfaceVariant,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionCard(
    _LegalSection section,
    int index,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final bool isSpecial = section.isSecurity;
    final bool isSanction = section.isSanctions;

    final Color cardBg = isSpecial
        ? scheme.primaryContainer.withValues(alpha: 0.16)
        : isSanction
            ? scheme.tertiaryContainer.withValues(alpha: 0.12)
            : scheme.surfaceContainerLow;

    final Color borderColor = isSpecial
        ? scheme.primary.withValues(alpha: 0.35)
        : isSanction
            ? scheme.tertiary.withValues(alpha: 0.28)
            : scheme.outlineVariant.withValues(alpha: 0.35);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
          width: isSpecial || isSanction ? 1.2 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSpecial
                      ? scheme.primary
                      : isSanction
                          ? scheme.tertiary
                          : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  section.number.padLeft(2, '0'),
                  style: textTheme.labelMedium?.copyWith(
                    color: isSpecial || isSanction
                        ? scheme.onPrimary
                        : scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                _categoryIcon(section.category),
                size: 20,
                color: isSpecial
                    ? scheme.primary
                    : isSanction
                        ? scheme.tertiary
                        : scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section Paragraphs and items
          ...section.paragraphs.map((String paragraph) {
            return _buildParagraphItem(paragraph, section, scheme, textTheme);
          }),
        ],
      ),
    );
  }

  Widget _buildParagraphItem(
    String text,
    _LegalSection section,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    // 1. H3 Subsections: "### 3.1. Data you provide" or "### 1.1 The Service"
    final RegExp h3Regex = RegExp(r'^###\s+(\d+\.\d+)\.?\s*(.*)');
    final Match? h3Match = h3Regex.firstMatch(text);
    if (h3Match != null) {
      final String subNum = h3Match.group(1)!;
      final String subTitle = h3Match.group(2)!.replaceAll('*', '').trim();
      return _buildSubsectionHeader(subNum, subTitle, scheme, textTheme);
    }

    final RegExp h3PlainRegex = RegExp(r'^###\s+(.*)');
    final Match? h3PlainMatch = h3PlainRegex.firstMatch(text);
    if (h3PlainMatch != null) {
      final String subTitle = h3PlainMatch.group(1)!.replaceAll('*', '').trim();
      return _buildSubsectionHeader('', subTitle, scheme, textTheme);
    }

    // 2. Bold Subsections: "**7.1. Location.** Personal data..." or "**8.1.** We do not..."
    final RegExp boldSubRegex = RegExp(r'^\*\*(\d+\.\d+)\.?\s*([^*]+)?\*\*\.?\s*(.*)');
    final Match? boldSubMatch = boldSubRegex.firstMatch(text);
    if (boldSubMatch != null) {
      final String subNum = boldSubMatch.group(1)!;
      final String rawSubTitle = (boldSubMatch.group(2) ?? '').trim();
      final String subTitle = rawSubTitle.endsWith('.')
          ? rawSubTitle.substring(0, rawSubTitle.length - 1).trim()
          : rawSubTitle;
      final String body = boldSubMatch.group(3)!.trim();

      if (subTitle.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubsectionHeader(subNum, subTitle, scheme, textTheme),
            if (body.isNotEmpty) _buildBodyParagraph(body, scheme, textTheme),
          ],
        );
      } else if (body.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                margin: const EdgeInsets.only(right: 8, top: 2),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subNum,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: _parseMarkdownSpans(
                      body,
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    height: 1.55,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    // 3. Bullet Point list items: "- item" or "* item"
    if (text.startsWith('- ') || text.startsWith('* ')) {
      final String itemText = text.substring(2).trim();
      return Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 10),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: _parseMarkdownSpans(
                    itemText,
                    scheme: scheme,
                    textTheme: textTheme,
                  ),
                ),
                style: textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 4. Definition Tile: "**Operator** — definition" or "Operator — definition" in terms section
    final RegExp defRegex = RegExp(r'^(?:\*\*)?([^*—–-]+?)(?:\*\*)?\s*([—–-])\s*(.+)');
    final Match? defMatch = defRegex.firstMatch(text);
    if (defMatch != null && (section.isTerms || text.startsWith('**'))) {
      final String term = defMatch.group(1)!.trim();
      final String definition = defMatch.group(3)!.trim();
      return _buildDefinitionTile(term, definition, scheme, textTheme);
    }

    // 5. Topic Paragraphs: "**Illegal activity.** Facilitate..."
    final RegExp topicRegex = RegExp(r'^\*\*([^*]+?)\.\*\*\s+(.+)');
    final Match? topicMatch = topicRegex.firstMatch(text);
    if (topicMatch != null) {
      final String topic = topicMatch.group(1)!.trim();
      final String body = topicMatch.group(2)!.trim();
      return _buildTopicItem(topic, body, scheme, textTheme);
    }

    // 6. Callout / Notice: Important Note, We do not record calls, etc.
    final String lower = text.toLowerCase();
    final bool isCallout = text.startsWith('> ') ||
        lower.contains('important note') ||
        lower.contains('важное примечание') ||
        lower.contains('we do not record calls') ||
        lower.contains('do not send sensitive information to niosai') ||
        lower.contains('do not send to niosai anything') ||
        lower.contains('secret chat content cannot be recovered');

    if (isCallout) {
      final String cleanText = text.startsWith('> ') ? text.substring(2).trim() : text;
      final bool isShield = lower.contains('we do not record calls') ||
          lower.contains('secret chat') ||
          lower.contains('e2ee');

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isShield
              ? scheme.primaryContainer.withValues(alpha: 0.28)
              : scheme.tertiaryContainer.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isShield
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.tertiary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isShield ? Icons.shield_outlined : Icons.info_outline_rounded,
              size: 20,
              color: isShield ? scheme.primary : scheme.tertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: _parseMarkdownSpans(
                    cleanText,
                    scheme: scheme,
                    textTheme: textTheme,
                    boldPrimary: true,
                  ),
                ),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 7. Interactive Contact email helper
    final RegExp emailRegex = RegExp(r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})');
    final Match? emailMatch = emailRegex.firstMatch(text);
    if (emailMatch != null &&
        (section.isContact ||
            lower.contains('contact') ||
            lower.contains('email') ||
            lower.contains('почт'))) {
      final String email = emailMatch.group(1)!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBodyParagraph(text, scheme, textTheme),
            const SizedBox(height: 6),
            ActionChip(
              avatar: Icon(Icons.copy_rounded, size: 16, color: scheme.primary),
              label: Text('Скопировать: $email'),
              labelStyle: textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: scheme.primaryContainer.withValues(alpha: 0.4),
              side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: email));
                HapticService.selection();
                AppToast.showSuccess(context, 'Email скопирован: $email');
              },
            ),
          ],
        ),
      );
    }

    // 8. Standard paragraph
    return _buildBodyParagraph(text, scheme, textTheme);
  }

  Widget _buildSubsectionHeader(
    String number,
    String title,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (number.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                number,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (title.isNotEmpty)
            Expanded(
              child: Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: scheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefinitionTile(
    String term,
    String definition,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_outline_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  term,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: _parseMarkdownSpans(
                definition,
                scheme: scheme,
                textTheme: textTheme,
              ),
            ),
            style: textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicItem(
    String topic,
    String body,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.secondary,
                ),
              ),
              Expanded(
                child: Text(
                  topic,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text.rich(
              TextSpan(
                children: _parseMarkdownSpans(
                  body,
                  scheme: scheme,
                  textTheme: textTheme,
                ),
              ),
              style: textTheme.bodyMedium?.copyWith(
                height: 1.55,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyParagraph(
    String text,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          children: _parseMarkdownSpans(
            text,
            scheme: scheme,
            textTheme: textTheme,
          ),
        ),
        style: textTheme.bodyMedium?.copyWith(
          height: 1.55,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  List<InlineSpan> _parseMarkdownSpans(
    String text, {
    required ColorScheme scheme,
    required TextTheme textTheme,
    TextStyle? overrideStyle,
    bool boldPrimary = false,
  }) {
    final TextStyle baseStyle = overrideStyle ??
        textTheme.bodyMedium!.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.55,
        );
    final TextStyle boldStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: boldPrimary ? scheme.primary : scheme.onSurface,
    );
    final TextStyle codeStyle = baseStyle.copyWith(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: scheme.primary,
    );
    final TextStyle linkStyle = baseStyle.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary.withValues(alpha: 0.4),
    );

    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp regex = RegExp(
      r'\*\*(.+?)\*\*|`([^`]+)`|([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
    );

    int lastIndex = 0;
    for (final Match match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: boldStyle,
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: codeStyle,
        ));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: match.group(3),
          style: linkStyle,
        ));
      }
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }
    return spans;
  }

  Widget _buildClosingNotesCard(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 24, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _parsedDoc!.closingNotes.map((String note) {
                return Text.rich(
                  TextSpan(
                    children: _parseMarkdownSpans(
                      note,
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: scheme.onSurface,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomConfirmBar(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SizedBox(
              width: double.infinity,
              height: 52,
            child: FilledButton.icon(
              onPressed: () {
                HapticService.lightImpact();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text(
                'Понятно, закрыть',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}

class _ParsedLegalDoc {
  const _ParsedLegalDoc({
    required this.title,
    required this.effectiveDate,
    required this.readingTimeMinutes,
    required this.preamble,
    required this.sections,
    required this.closingNotes,
  });

  final String title;
  final String? effectiveDate;
  final int readingTimeMinutes;
  final List<String> preamble;
  final List<_LegalSection> sections;
  final List<String> closingNotes;
}

enum _SectionCategory {
  general,
  terms,
  security,
  sanctions,
  ai,
  payments,
  rights,
  contact,
}

_SectionCategory _detectCategory(String title) {
  final String t = title.toLowerCase();
  if (t.contains('security') ||
      t.contains('e2ee') ||
      t.contains('encrypt') ||
      t.contains('шифрован') ||
      t.contains('защита') ||
      t.contains('secret chat')) {
    return _SectionCategory.security;
  }
  if (t.contains('sanction') ||
      t.contains('spamblock') ||
      t.contains('freeze') ||
      t.contains('ban') ||
      t.contains('блокиров') ||
      t.contains('модерация') ||
      t.contains('enforcement') ||
      t.contains('acceptable use')) {
    return _SectionCategory.sanctions;
  }
  if (t.contains('ai') ||
      t.contains('assistant') ||
      t.contains('искусствен')) {
    return _SectionCategory.ai;
  }
  if (t.contains('payment') ||
      t.contains('subscription') ||
      t.contains('nios+') ||
      t.contains('оплат')) {
    return _SectionCategory.payments;
  }
  if (t.contains('right') ||
      t.contains('права') ||
      t.contains('consent') ||
      t.contains('согласи')) {
    return _SectionCategory.rights;
  }
  if (t.contains('contact') ||
      t.contains('контакт') ||
      t.contains('support')) {
    return _SectionCategory.contact;
  }
  if (t.contains('term') ||
      t.contains('definition') ||
      t.contains('термин') ||
      t.contains('определен')) {
    return _SectionCategory.terms;
  }
  return _SectionCategory.general;
}

IconData _categoryIcon(_SectionCategory category) {
  switch (category) {
    case _SectionCategory.security:
      return Icons.lock_outline_rounded;
    case _SectionCategory.sanctions:
      return Icons.gavel_rounded;
    case _SectionCategory.ai:
      return Icons.auto_awesome_rounded;
    case _SectionCategory.payments:
      return Icons.star_rounded;
    case _SectionCategory.rights:
      return Icons.verified_user_outlined;
    case _SectionCategory.contact:
      return Icons.alternate_email_rounded;
    case _SectionCategory.terms:
      return Icons.menu_book_rounded;
    case _SectionCategory.general:
      return Icons.article_outlined;
  }
}

class _LegalSection {
  const _LegalSection({
    required this.number,
    required this.title,
    required this.paragraphs,
    required this.category,
  });

  final String number;
  final String title;
  final List<String> paragraphs;
  final _SectionCategory category;

  bool get isSecurity => category == _SectionCategory.security;
  bool get isSanctions => category == _SectionCategory.sanctions;
  bool get isAi => category == _SectionCategory.ai;
  bool get isPayments => category == _SectionCategory.payments;
  bool get isRights => category == _SectionCategory.rights;
  bool get isContact => category == _SectionCategory.contact;
  bool get isTerms => category == _SectionCategory.terms;
}
