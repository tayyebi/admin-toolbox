import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'components/buttons.dart';
import 'components/feedback.dart';
import 'components/inputs.dart';
import 'components/navigation.dart';
import 'components/surfaces.dart';

/// Light and dark themes built from one shared definition, so a change to
/// spacing, radius or component shape lands in both.
///
/// Each family of component themes lives in `components/`; this file decides
/// the palette and hands the same pieces to both brightnesses.
class AppTheme {
  AppTheme._();

  static final ThemeData light = _build(
    brightness: Brightness.light,
    colors: AppColors.light,
    scheme: const ColorScheme.light(
      primary: Color(0xFF0969DA),
      onPrimary: Colors.white,
      secondary: Color(0xFF0F766E),
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF1F2328),
      surfaceContainerHighest: Color(0xFFF6F8FA),
      onSurfaceVariant: Color(0xFF656D76),
      error: Color(0xFFCF222E),
      onError: Colors.white,
      outline: Color(0xFFD0D7DE),
    ),
    scaffoldBackground: const Color(0xFFF6F8FA),
    cardColor: Colors.white,
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    colors: AppColors.dark,
    scheme: const ColorScheme.dark(
      primary: Color(0xFF58A6FF),
      onPrimary: Color(0xFF0D1117),
      secondary: Color(0xFF39D2C0),
      onSecondary: Color(0xFF0D1117),
      surface: Color(0xFF161B22),
      onSurface: Color(0xFFE6EDF3),
      surfaceContainerHighest: Color(0xFF21262D),
      onSurfaceVariant: Color(0xFF8B949E),
      error: Color(0xFFF85149),
      onError: Colors.white,
      outline: Color(0xFF30363D),
    ),
    scaffoldBackground: const Color(0xFF0D1117),
    cardColor: const Color(0xFF161B22),
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppColors colors,
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color cardColor,
  }) {
    final textTheme = AppTypography.textTheme(scheme.onSurface, scheme.onSurfaceVariant);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: scaffoldBackground,
      fontFamily: AppTypography.sans,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[colors],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: buildAppBarTheme(scheme, textTheme, isDark, scaffoldBackground),
      cardTheme: buildCardTheme(colors, cardColor),
      inputDecorationTheme: buildInputDecorationTheme(colors, scheme, textTheme),
      navigationBarTheme: buildNavigationBarTheme(colors, scheme, textTheme, cardColor),
      dividerTheme: buildDividerTheme(colors),
      listTileTheme: buildListTileTheme(colors, textTheme),
      filledButtonTheme: buildFilledButtonTheme(textTheme),
      elevatedButtonTheme: buildElevatedButtonTheme(scheme, textTheme),
      outlinedButtonTheme: buildOutlinedButtonTheme(colors, scheme, textTheme),
      textButtonTheme: buildTextButtonTheme(scheme, textTheme),
      dialogTheme: buildDialogTheme(colors, textTheme, cardColor),
      bottomSheetTheme: buildBottomSheetTheme(cardColor),
      snackBarTheme: buildSnackBarTheme(colors, scheme, textTheme, isDark),
      chipTheme: buildChipTheme(colors, textTheme),
      popupMenuTheme: buildPopupMenuTheme(colors, scheme, textTheme, cardColor),
      switchTheme: buildSwitchTheme(colors, scheme),
      progressIndicatorTheme: buildProgressIndicatorTheme(colors, scheme),
      tooltipTheme: buildTooltipTheme(colors, scheme, textTheme, isDark),
    );
  }
}
