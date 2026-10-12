import 'package:flutter/material.dart';

class ProjectItem {
  final String id;
  final String userId;
  final String name;
  final int colorValue;
  final int sortOrder;
  final bool isDefault;

  const ProjectItem({
    required this.id,
    this.userId = '',
    required this.name,
    required this.colorValue,
    this.sortOrder = 0,
    this.isDefault = false,
  });

  Color get color => Color(colorValue);

  ProjectItem copyWith({
    String? id,
    String? userId,
    String? name,
    int? colorValue,
    int? sortOrder,
    bool? isDefault,
  }) {
    return ProjectItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'colorValue': colorValue,
      'sortOrder': sortOrder,
      'isDefault': isDefault,
    };
  }

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    return ProjectItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF64748B,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
