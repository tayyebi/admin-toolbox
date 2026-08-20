import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../theme_metrics.dart';

SnackBarThemeData buildSnackBarTheme(
  AppColors colors,
  ColorScheme scheme,
  TextTheme textTheme,
  bool isDark,
) =>
    SnackBarThemeData(
    backgroundColor: isDark ? colors.surfaceMuted : const Color(0xFF1F2328),
    contentTextStyle: textTheme.bodyMedium?.copyWith(
      color: isDark ? scheme.onSurface : Colors.white,
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(themeRadiusSmall)),
  );

ChipThemeData buildChipTheme(AppColors colors, TextTheme textTheme) => ChipThemeData(
    backgroundColor: colors.surfaceMuted,
    side: BorderSide(color: colors.border),
    labelStyle: textTheme.labelSmall,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(themeRadiusSmall)),
  );

ProgressIndicatorThemeData buildProgressIndicatorTheme(
  AppColors colors,
  ColorScheme scheme,
) =>
    ProgressIndicatorThemeData(
    color: scheme.primary,
    linearTrackColor: colors.surfaceMuted,
    circularTrackColor: Colors.transparent,
  );

TooltipThemeData buildTooltipTheme(
  AppColors colors,
  ColorScheme scheme,
  TextTheme textTheme,
  bool isDark,
) =>
    TooltipThemeData(
    decoration: BoxDecoration(
      color: isDark ? colors.surfaceMuted : const Color(0xFF1F2328),
      borderRadius: BorderRadius.circular(themeRadiusSmall),
    ),
    textStyle: textTheme.bodySmall?.copyWith(
      color: isDark ? scheme.onSurface : Colors.white,
    ),
  );
