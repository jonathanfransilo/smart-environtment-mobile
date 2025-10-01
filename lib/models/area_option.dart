class AreaOption {
  AreaOption({
    required this.id,
    required this.name,
    required this.level,
    this.parent,
  });

  final String id;
  final String name;
  final String level;
  final AreaOption? parent;

  factory AreaOption.fromJson(Map<String, dynamic> json) {
    return AreaOption(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '-',
      level: json['level']?.toString() ?? '',
      parent: json['parent'] is Map<String, dynamic>
          ? AreaOption.fromJson(json['parent'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  String toString() => name;
}
