import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../theme_metrics.dart';

NavigationBarThemeData buildNavigationBarTheme(
  AppColors colors,
  ColorScheme scheme,
  TextTheme textTheme,
  Color cardColor,
) =>
    NavigationBarThemeData(
    backgroundColor: cardColor,
    surfaceTintColor: Colors.transparent,
    indicatorColor: scheme.primary.withValues(alpha: 0.14),
    elevation: 0,
    height: 64,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return textTheme.labelSmall?.copyWith(
        color: selected ? scheme.primary : colors.textMuted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        size: 22,
        color: selected ? scheme.primary : colors.textMuted,
      );
    }),
  );

DividerThemeData buildDividerTheme(
  AppColors colors,
) =>
    DividerThemeData(color: colors.border, thickness: 1, space: 1);

ListTileThemeData buildListTileTheme(
  AppColors colors,
  TextTheme textTheme,
) =>
    ListTileThemeData(
    iconColor: colors.textMuted,
    titleTextStyle: textTheme.titleMedium,
    subtitleTextStyle: textTheme.bodySmall,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(themeRadiusSmall)),
  );
