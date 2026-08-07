import 'package:flutter/material.dart';

/// Two families, each with one job.
///
/// Inter carries the interface — labels, body copy, headings. JetBrains Mono is
/// reserved for content where character alignment carries meaning: terminal
/// output, hostnames and IPs, key fingerprints, file paths, metric readouts.
class AppTypography {
  AppTypography._();

  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';

  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: _sans(32, FontWeight.w600, primary, height: 1.2, tracking: -0.5),
      displayMedium: _sans(28, FontWeight.w600, primary, height: 1.2, tracking: -0.4),
      displaySmall: _sans(24, FontWeight.w600, primary, height: 1.25, tracking: -0.3),
      headlineLarge: _sans(22, FontWeight.w600, primary, height: 1.3, tracking: -0.3),
      headlineMedium: _sans(20, FontWeight.w600, primary, height: 1.3, tracking: -0.2),
      headlineSmall: _sans(18, FontWeight.w600, primary, height: 1.35, tracking: -0.2),
      titleLarge: _sans(17, FontWeight.w600, primary, height: 1.35, tracking: -0.1),
      titleMedium: _sans(15, FontWeight.w500, primary, height: 1.4),
      titleSmall: _sans(13, FontWeight.w500, secondary, height: 1.4),
      bodyLarge: _sans(15, FontWeight.w400, primary, height: 1.5),
      bodyMedium: _sans(14, FontWeight.w400, secondary, height: 1.5),
      bodySmall: _sans(12, FontWeight.w400, secondary, height: 1.45),
      labelLarge: _sans(14, FontWeight.w500, primary, height: 1.4),
      labelMedium: _sans(12, FontWeight.w500, secondary, height: 1.35),
      labelSmall: _sans(11, FontWeight.w500, secondary, height: 1.3, tracking: 0.2),
    );
  }

  static TextStyle _sans(
    double size,
    FontWeight weight,
    Color color, {
    double? height,
    double? tracking,
  }) {
    return TextStyle(
      fontFamily: sans,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: tracking,
    );
  }

  /// Monospace styles. Pass a colour explicitly at the call site, or let it
  /// inherit from the surrounding [DefaultTextStyle].
  static TextStyle monoStyle({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.5,
  }) {
    return TextStyle(
      fontFamily: mono,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  /// Hostnames, paths, fingerprints inline in a list row.
  static TextStyle monoSmall(Color color) => monoStyle(size: 12, color: color, height: 1.4);

  /// Large numeric readouts on metric cards.
  static TextStyle monoMetric(Color color) =>
      monoStyle(size: 22, weight: FontWeight.w500, color: color, height: 1.1);

  /// Terminal and log output.
  static TextStyle monoTerminal(Color color, double size) =>
      monoStyle(size: size, color: color, height: 1.35);
}
