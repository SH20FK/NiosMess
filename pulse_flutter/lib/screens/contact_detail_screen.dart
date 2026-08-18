import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/screens/public_profile_screen.dart';

class ContactDetailScreen extends ConsumerStatefulWidget {
  const ContactDetailScreen({required this.username, super.key});

  final String username;

  @override
  ConsumerState<ContactDetailScreen> createState() =>
      _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return PublicProfileScreen(username: widget.username);
  }
}
