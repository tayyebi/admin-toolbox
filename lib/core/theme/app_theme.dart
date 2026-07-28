import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryBlue = Color(0xFF58A6FF);
  static const Color successGreen = Color(0xFF3FB950);
  static const Color warningOrange = Color(0xFFD29922);
  static const Color dangerRed = Color(0xFFF85149);
  static const Color infoCyan = Color(0xFF39D2C0);
  static const Color bgDark = Color(0xFF0D1117);
  static const Color bgCard = Color(0xFF161B22);
  static const Color bgSurface = Color(0xFF21262D);
  static const Color borderDefault = Color(0xFF30363D);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);

  static final ThemeData dark = FlexThemeData.dark(
    scheme: FlexScheme.custom,
    surface: bgDark,
    scaffoldBackground: bgDark,
    appBarBackground: bgDark,
    dialogBackground: bgCard,
    tabBarStyle: FlexTabBarStyle.forAppBar,
    fontFamily: 'JetBrainsMono',
    useMaterial3: true,
  ).copyWith(
    colorScheme: const ColorScheme.dark(
      primary: primaryBlue,
      secondary: infoCyan,
      surface: bgCard,
      error: dangerRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onError: Colors.white,
    ),
    cardTheme: const CardThemeData(
      color: bgCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: borderDefault, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: dangerRed),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textMuted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bgCard,
      selectedItemColor: primaryBlue,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: primaryBlue,
      unselectedLabelColor: textSecondary,
      indicatorColor: primaryBlue,
    ),
    dividerTheme: const DividerThemeData(
      color: borderDefault,
      thickness: 0.5,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: textPrimary, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: textPrimary, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: textPrimary, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: textPrimary, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textPrimary, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: textSecondary, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textPrimary, fontFamily: 'JetBrainsMono'),
      bodyMedium: TextStyle(color: textSecondary, fontFamily: 'JetBrainsMono'),
      bodySmall: TextStyle(color: textMuted, fontFamily: 'JetBrainsMono'),
      labelLarge: TextStyle(color: textPrimary, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: textSecondary, fontFamily: 'JetBrainsMono'),
      labelSmall: TextStyle(color: textMuted, fontFamily: 'JetBrainsMono'),
    ),
  );

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return dangerRed;
      case 'warning':
      case 'high':
        return warningOrange;
      case 'info':
      case 'low':
        return infoCyan;
      case 'success':
      case 'ok':
        return successGreen;
      default:
        return textMuted;
    }
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
      case 'active':
      case 'running':
      case 'healthy':
        return successGreen;
      case 'offline':
      case 'stopped':
      case 'critical':
        return dangerRed;
      case 'warning':
      case 'degraded':
        return warningOrange;
      case 'pending':
      case 'unknown':
        return textMuted;
      default:
        return textSecondary;
    }
  }
}
