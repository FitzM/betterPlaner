import 'package:flutter/material.dart';

class ProjectItem {
  final String id;
  final String userId;
  final String name;
  final String? folderName;
  final int colorValue;
  final int sortOrder;
  final bool isDefault;
  final String? viewMode;
  final String? projectKind;

  const ProjectItem({
    required this.id,
    this.userId = '',
    required this.name,
    this.folderName,
    required this.colorValue,
    this.sortOrder = 0,
    this.isDefault = false,
    this.viewMode,
    this.projectKind,
  });

  Color get color => Color(colorValue);

  bool get isValidProjectName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('-P') ||
        trimmed.startsWith('P0D') ||
        trimmed.startsWith('-PT') ||
        trimmed.startsWith('PT') ||
        trimmed.startsWith('FREQ=') ||
        trimmed.startsWith('Status:') ||
        trimmed.startsWith('Version:') ||
        trimmed.startsWith('Date:') ||
        trimmed.contains('Completed"') ||
        trimmed.contains('Abandoned')) {
      return false;
    }
    return true;
  }

  ProjectItem copyWith({
    String? id,
    String? userId,
    String? name,
    String? folderName,
    int? colorValue,
    int? sortOrder,
    bool? isDefault,
    String? viewMode,
    String? projectKind,
  }) {
    return ProjectItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      folderName: folderName ?? this.folderName,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      viewMode: viewMode ?? this.viewMode,
      projectKind: projectKind ?? this.projectKind,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      if (folderName != null) 'folderName': folderName,
      'colorValue': colorValue,
      'sortOrder': sortOrder,
      'isDefault': isDefault,
      if (viewMode != null) 'viewMode': viewMode,
      if (projectKind != null) 'projectKind': projectKind,
    };
  }

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    return ProjectItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled',
      folderName: json['folderName'] as String?,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF64748B,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
      viewMode: json['viewMode'] as String?,
      projectKind: json['projectKind'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
