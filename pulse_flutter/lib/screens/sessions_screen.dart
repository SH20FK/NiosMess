import 'package:flutter/material.dart';
import 'package:pulse_flutter/features/sessions/presentation/sessions_screen.dart' as feature;

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    return feature.SessionsScreen(isEmbedded: isEmbedded);
  }
}
