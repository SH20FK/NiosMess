import 'package:flutter/material.dart';

class MessageFormatter {
  MessageFormatter._();

  static final RegExp fwdRegExp = RegExp(r'^_fwd from\s+(.+?):\s*(.*)$');
  static final RegExp mentionRegExp = RegExp(r'@(\w+)');

  static String displayText(String raw) {
    final String trimmed = raw.trim();
    final Match? result = fwdRegExp.firstMatch(trimmed);
    if (result == null) return raw;
    final String body = (result.group(2) ?? '').trim();
    return body;
  }
}
