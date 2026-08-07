import 'package:admin_toolbox/core/theme/app_colors.dart';
import 'package:admin_toolbox/core/theme/app_theme.dart';
import 'package:admin_toolbox/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('maps severities to distinct colours', () {
      const colors = AppColors.dark;
      expect(colors.severity('critical'), colors.danger);
      expect(colors.severity('warning'), colors.warning);
      expect(colors.severity('info'), colors.info);
      expect(colors.severity('anything else'), colors.textMuted);
    });

    test('maps statuses to distinct colours', () {
      const colors = AppColors.dark;
      expect(colors.status('online'), colors.success);
      expect(colors.status('offline'), colors.danger);
      expect(colors.status('degraded'), colors.warning);
      expect(colors.status('unknown'), colors.textMuted);
    });

    test('is case-insensitive', () {
      const colors = AppColors.light;
      expect(colors.severity('CRITICAL'), colors.danger);
      expect(colors.status('Online'), colors.success);
    });

    test('grades health scores', () {
      const colors = AppColors.dark;
      expect(colors.health(100), colors.success);
      expect(colors.health(80), colors.success);
      expect(colors.health(65), colors.warning);
      expect(colors.health(20), colors.danger);
    });

    test('lerps between light and dark', () {
      final mid = AppColors.light.lerp(AppColors.dark, 0.5);
      expect(mid, isA<AppColors>());
      expect(mid.success, isNot(AppColors.light.success));
    });
  });

  group('AppTheme', () {
    test('registers AppColors on both themes', () {
      // Without this extension registered, every `context.colors` lookup would
      // silently fall back to the dark palette.
      expect(AppTheme.light.extension<AppColors>(), isNotNull);
      expect(AppTheme.dark.extension<AppColors>(), isNotNull);
    });

    test('carries the right brightness', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('light and dark use different surfaces', () {
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        isNot(AppTheme.dark.scaffoldBackgroundColor),
      );
    });

    test('uses Inter for interface text', () {
      expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, AppTypography.sans);
      expect(AppTheme.dark.textTheme.titleLarge?.fontFamily, AppTypography.sans);
    });
  });

  group('AppTypography', () {
    test('mono styles use JetBrains Mono', () {
      expect(AppTypography.monoStyle().fontFamily, AppTypography.mono);
      expect(AppTypography.monoSmall(const Color(0xFF000000)).fontFamily, AppTypography.mono);
      expect(AppTypography.monoMetric(const Color(0xFF000000)).fontFamily, AppTypography.mono);
    });

    test('terminal style honours the requested size', () {
      final style = AppTypography.monoTerminal(const Color(0xFF000000), 17);
      expect(style.fontSize, 17);
    });
  });

  testWidgets('context.colors resolves per theme', (tester) async {
    // MaterialApp wraps its theme in an AnimatedTheme, so swapping the theme
    // on an existing tree interpolates over ~200ms — sampling immediately
    // would read values still part-way between light and dark. A distinct key
    // per pump forces a fresh tree instead, and settling afterwards guards
    // against any animation that does start.
    Future<AppColors> colorsFor(ThemeData theme, Key key) async {
      late AppColors captured;
      await tester.pumpWidget(
        MaterialApp(
          key: key,
          theme: theme,
          home: Builder(
            builder: (context) {
              captured = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return captured;
    }

    final lightColors = await colorsFor(AppTheme.light, const ValueKey('light'));
    final darkColors = await colorsFor(AppTheme.dark, const ValueKey('dark'));

    expect(lightColors.surfaceMuted, AppColors.light.surfaceMuted);
    expect(darkColors.surfaceMuted, AppColors.dark.surfaceMuted);
    expect(lightColors.surfaceMuted, isNot(darkColors.surfaceMuted));
    expect(lightColors.border, isNot(darkColors.border));
  });
}
