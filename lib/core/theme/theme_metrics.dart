import 'package:flutter/material.dart';

/// Shared geometry, so a corner radius is decided once rather than per widget.
const double themeRadius = 10;
const double themeRadiusSmall = 6;

OutlineInputBorder themeInputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(themeRadiusSmall),
    borderSide: BorderSide(color: color, width: width),
  );
}
