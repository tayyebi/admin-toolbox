import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../theme_metrics.dart';

InputDecorationTheme buildInputDecorationTheme(
  AppColors colors,
  ColorScheme scheme,
  TextTheme textTheme,
) =>
    InputDecorationTheme(
    filled: true,
    fillColor: colors.surfaceMuted,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: themeInputBorder(colors.border),
    enabledBorder: themeInputBorder(colors.border),
    focusedBorder: themeInputBorder(scheme.primary, width: 1.5),
    errorBorder: themeInputBorder(scheme.error),
    focusedErrorBorder: themeInputBorder(scheme.error, width: 1.5),
    labelStyle: textTheme.bodyMedium,
    floatingLabelStyle: TextStyle(color: scheme.primary, fontFamily: AppTypography.sans),
    hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
    helperStyle: textTheme.bodySmall?.copyWith(color: colors.textMuted),
    prefixIconColor: colors.textMuted,
    suffixIconColor: colors.textMuted,
  );

SwitchThemeData buildSwitchTheme(AppColors colors, ColorScheme scheme) => SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? Colors.white : colors.textMuted,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? scheme.primary : colors.surfaceMuted,
    ),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? scheme.primary : colors.border,
    ),
  );
