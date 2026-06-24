class ApiBadge {
  const ApiBadge({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final int id;
  final String name;
  final String icon;
  final String color;

  factory ApiBadge.fromJson(Map<String, dynamic> json) {
    return ApiBadge(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Badge',
      icon: json['icon'] as String? ?? 'verified',
      color: json['color'] as String? ?? 'primary',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }
}
