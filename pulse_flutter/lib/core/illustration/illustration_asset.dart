import 'package:flutter/material.dart';

@immutable
class IllustrationAsset {
  const IllustrationAsset({
    required this.id,
    required this.assetPath,
    required this.title,
    required this.fallbackIcon,
    this.description,
    this.width = 120,
    this.height = 120,
  });

  final String id;
  final String assetPath;
  final String title;
  final IconData fallbackIcon;
  final String? description;
  final double width;
  final double height;
}
