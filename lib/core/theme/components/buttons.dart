import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../theme_metrics.dart';

FilledButtonThemeData buildFilledButtonTheme(
  TextTheme textTheme,
) =>
    FilledButtonThemeData(
    style: FilledButton.styleFrom(
      textStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(themeRadiusSmall)),
    ),
  );

ElevatedButtonThemeData buildElevatedButtonTheme(
  ColorScheme scheme,
  TextTheme textTheme,
) =>
    ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      textStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(themeRadiusSmall)),
    ),
  );

OutlinedButtonThemeData buildOutlinedButtonTheme(
  AppColors colors,
  ColorScheme scheme,
  TextTheme textTheme,
) =>
    OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: scheme.onSurface,
      side: BorderSide(color: colors.border),
      textStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(themeRadiusSmall)),
    ),
  );

TextButtonThemeData buildTextButtonTheme(
  ColorScheme scheme,
  TextTheme textTheme,
) =>
    TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: scheme.primary,
      textStyle: textTheme.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(themeRadiusSmall)),
    ),
  );
