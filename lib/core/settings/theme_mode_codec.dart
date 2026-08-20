import 'package:flutter/material.dart';

/// Stored as a name so the preference survives a reordering of the enum.
ThemeMode themeModeFromName(String? name) {
  switch (name) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}
