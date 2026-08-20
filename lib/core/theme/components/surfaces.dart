import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../theme_metrics.dart';

AppBarTheme buildAppBarTheme(
  ColorScheme scheme,
  TextTheme textTheme,
  bool isDark,
  Color scaffoldBackground,
) =>
    AppBarTheme(
    backgroundColor: scaffoldBackground,
    foregroundColor: scheme.onSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: textTheme.titleLarge,
    systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
  );

CardThemeData buildCardTheme(AppColors colors, Color cardColor) => CardThemeData(
    color: cardColor,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(themeRadius),
      side: BorderSide(color: colors.border, width: 1),
    ),
  );

DialogThemeData buildDialogTheme(
  AppColors colors,
  TextTheme textTheme,
  Color cardColor,
) =>
    DialogThemeData(
    backgroundColor: cardColor,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(themeRadius),
      side: BorderSide(color: colors.border),
    ),
    titleTextStyle: textTheme.titleLarge,
    contentTextStyle: textTheme.bodyMedium,
  );

BottomSheetThemeData buildBottomSheetTheme(Color cardColor) => BottomSheetThemeData(
    backgroundColor: cardColor,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
  );

PopupMenuThemeData buildPopupMenuTheme(
  AppColors colors,
  ColorScheme scheme,
  TextTheme textTheme,
  Color cardColor,
) =>
    PopupMenuThemeData(
    color: cardColor,
    surfaceTintColor: Colors.transparent,
    elevation: 4,
    textStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(themeRadius),
      side: BorderSide(color: colors.border),
    ),
  );
