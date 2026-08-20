import 'package:flutter/material.dart';

export 'semantic_colors.dart';
export 'theme_context.dart';

/// Semantic colors that Material's [ColorScheme] has no slot for.
///
/// A [ThemeExtension], so values resolve in both brightnesses. Read it through
/// `context.colors` — reaching for the constants is how light mode silently
/// inherits dark surfaces.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.border,
    required this.textMuted,
    required this.surfaceMuted,
    required this.terminalBackground,
    required this.terminalForeground,
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  /// Hairline dividers and card outlines.
  final Color border;
  /// De-emphasised text: timestamps, captions, disabled labels.
  final Color textMuted;
  /// Recessed surfaces: input fills, path bars, table headers.
  final Color surfaceMuted;
  final Color terminalBackground;
  final Color terminalForeground;
  static const AppColors dark = AppColors(
    success: Color(0xFF3FB950),
    warning: Color(0xFFD29922),
    danger: Color(0xFFF85149),
    info: Color(0xFF39D2C0),
    border: Color(0xFF30363D),
    textMuted: Color(0xFF6E7681),
    surfaceMuted: Color(0xFF21262D),
    terminalBackground: Color(0xFF0D1117),
    terminalForeground: Color(0xFFE6EDF3),
  );
  static const AppColors light = AppColors(
    success: Color(0xFF1A7F37),
    warning: Color(0xFF9A6700),
    danger: Color(0xFFCF222E),
    info: Color(0xFF0F766E),
    border: Color(0xFFD0D7DE),
    textMuted: Color(0xFF8C959F),
    surfaceMuted: Color(0xFFF6F8FA),
    terminalBackground: Color(0xFF0D1117),
    terminalForeground: Color(0xFFE6EDF3),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? border,
    Color? textMuted,
    Color? surfaceMuted,
    Color? terminalBackground,
    Color? terminalForeground,
  }) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      terminalBackground: terminalBackground ?? this.terminalBackground,
      terminalForeground: terminalForeground ?? this.terminalForeground,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      terminalBackground: Color.lerp(terminalBackground, other.terminalBackground, t)!,
      terminalForeground: Color.lerp(terminalForeground, other.terminalForeground, t)!,
    );
  }
}
