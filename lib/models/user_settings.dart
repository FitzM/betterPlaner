class UserSettings {
  final int defaultTaskDuration; // In minutes: 15, 30, 45, 60, etc.
  final int timeSnapMinutes; // In minutes: 5, 15, etc.
  final double defaultVisibleHours; // In hours: 3.0 to 24.0

  const UserSettings({
    this.defaultTaskDuration = 30,
    this.timeSnapMinutes = 5,
    this.defaultVisibleHours = 9.0,
  });

  UserSettings copyWith({
    int? defaultTaskDuration,
    int? timeSnapMinutes,
    double? defaultVisibleHours,
  }) {
    return UserSettings(
      defaultTaskDuration: defaultTaskDuration ?? this.defaultTaskDuration,
      timeSnapMinutes: timeSnapMinutes ?? this.timeSnapMinutes,
      defaultVisibleHours: defaultVisibleHours ?? this.defaultVisibleHours,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultTaskDuration': defaultTaskDuration,
      'timeSnapMinutes': timeSnapMinutes,
      'defaultVisibleHours': defaultVisibleHours,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      defaultTaskDuration: json['defaultTaskDuration'] as int? ?? 30,
      timeSnapMinutes: json['timeSnapMinutes'] as int? ?? 5,
      defaultVisibleHours: (json['defaultVisibleHours'] as num?)?.toDouble() ?? 9.0,
    );
  }
}
