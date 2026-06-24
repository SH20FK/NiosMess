class AdminBadge {
  const AdminBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String description;
  final String icon;
  final String color;
  final DateTime createdAt;

  factory AdminBadge.fromJson(Map<String, dynamic> json) {
    return AdminBadge(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      color: json['color']?.toString() ?? '#0d6fad',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
