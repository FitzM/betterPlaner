import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_settings.dart';

class UserSettingsNotifier extends Notifier<UserSettings> {
  @override
  UserSettings build() => const UserSettings();

  void setDefaultDuration(int minutes) {
    state = state.copyWith(defaultTaskDuration: minutes);
  }

  void setTimeSnap(int minutes) {
    state = state.copyWith(timeSnapMinutes: minutes);
  }

  void setVisibleHours(double hours) {
    state = state.copyWith(defaultVisibleHours: hours.clamp(3.0, 24.0));
  }

  void reset() {
    state = const UserSettings();
  }
}

final settingsProvider =
    NotifierProvider<UserSettingsNotifier, UserSettings>(UserSettingsNotifier.new);
