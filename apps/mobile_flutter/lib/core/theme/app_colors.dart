import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF1A237E);
  static const primaryLight = Color(0xFF534BAE);
  static const primaryDark = Color(0xFF000051);

  static const secondary = Color(0xFF00897B);
  static const secondaryLight = Color(0xFF4EBAAA);
  static const secondaryDark = Color(0xFF005B4F);

  static const error = Color(0xFFD32F2F);
  static const warning = Color(0xFFF57C00);
  static const success = Color(0xFF388E3C);
  static const info = Color(0xFF1976D2);

  static const surfaceLight = Color(0xFFFAFAFA);
  static const surfaceDark = Color(0xFF121212);

  static const onPrimaryLight = Colors.white;
  static const onPrimaryDark = Colors.white;

  static const severityCritical = Color(0xFFD32F2F);
  static const severityWarning = Color(0xFFF57C00);
  static const severityInfo = Color(0xFF1976D2);

  static const cameraOnline = Color(0xFF4CAF50);
  static const cameraOffline = Color(0xFF9E9E9E);
  static const cameraWarning = Color(0xFFF57C00);
}
