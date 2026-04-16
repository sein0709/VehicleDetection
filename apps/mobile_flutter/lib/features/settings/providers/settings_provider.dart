import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.locale = const Locale('ko'),
  });

  final ThemeMode themeMode;
  final Locale? locale;

  AppSettings copyWith({ThemeMode? themeMode, Locale? locale}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setLocale(Locale locale) {
    state = state.copyWith(locale: locale);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
