import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

enum LegalDocType { privacy, tos, consent }

class LegalViewerScreen extends ConsumerStatefulWidget {
  const LegalViewerScreen({required this.docType, super.key});

  final LegalDocType docType;

  @override
  ConsumerState<LegalViewerScreen> createState() => _LegalViewerScreenState();
}

class _LegalViewerScreenState extends ConsumerState<LegalViewerScreen> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final String locale = Localizations.localeOf(context).languageCode;
    String assetPath;

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

    try {
      final String text = await rootBundle.loadString(assetPath);
      if (mounted) {
        setState(() {
          _content = text;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _content = 'Failed to load document: $e';
          _loading = false;
        });
      }
    }
  }

  String get _title {
    switch (widget.docType) {
      case LegalDocType.privacy:
        return context.l10n.legalPrivacyTitle;
      case LegalDocType.tos:
        return context.l10n.legalToSTitle;
      case LegalDocType.consent:
        return context.l10n.legalConsentTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: SelectableText(
                  _content,
                  style: textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: scheme.onSurface,
                  ),
                ),
              ),
      ),
    );
  }
}
