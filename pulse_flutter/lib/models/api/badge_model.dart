class ApiBadge {
  const ApiBadge({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.description,
  });

  final int id;
  final String name;
  final String icon;
  final String color;
  final String? description;

  factory ApiBadge.fromJson(Map<String, dynamic> json) {
    return ApiBadge(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Badge',
      icon: json['icon'] as String? ?? 'verified',
      color: json['color'] as String? ?? 'primary',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      if (description != null) 'description': description,
    };
  }

  ApiBadge copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
    String? description,
  }) {
    return ApiBadge(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiBadge &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          icon == other.icon &&
          color == other.color &&
          description == other.description;

  @override
  int get hashCode => Object.hash(id, name, icon, color, description);

  @override
  String toString() =>
      'ApiBadge(id: $id, name: $name, icon: $icon, color: $color, description: $description)';
}

