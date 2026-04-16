import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Space-indigo primary ──────────────────────────────────────────────
  static const primary = Color(0xFF293154);
  static const primaryLight = Color(0xFF4A5578);
  static const primaryDark = Color(0xFF1A2040);
  static const primaryContainer = Color(0xFFD9DDED);
  static const onPrimaryContainer = Color(0xFF0F1730);

  // ── Dark-grey secondary ───────────────────────────────────────────────
  static const secondary = Color(0xFF44444F);
  static const secondaryLight = Color(0xFF6B6B78);
  static const secondaryDark = Color(0xFF2C2C34);
  static const secondaryContainer = Color(0xFFE2E1EC);
  static const onSecondaryContainer = Color(0xFF1A1A24);

  // ── Neutral greys ─────────────────────────────────────────────────────
  static const neutral = Color(0xFF767680);
  static const neutralDark = Color(0xFF343438);

  // ── Surfaces (white-based) ────────────────────────────────────────────
  static const surfaceLight = Color(0xFFFCFCFF);
  static const surfaceDark = Color(0xFF1B1B1F);
  static const surfaceContainerLight = Color(0xFFF1F1F6);
  static const surfaceContainerHighLight = Color(0xFFE8E8EE);

  // ── Semantic ──────────────────────────────────────────────────────────
  static const error = Color(0xFFBA1A1A);
  static const warning = Color(0xFFF57C00);
  static const success = Color(0xFF2E7D32);
  static const info = Color(0xFF293154);

  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const onPrimaryDark = Color(0xFFFFFFFF);

  static const severityCritical = Color(0xFFBA1A1A);
  static const severityWarning = Color(0xFFF57C00);
  static const severityInfo = Color(0xFF293154);

  static const cameraOnline = Color(0xFF2E7D32);
  static const cameraOffline = Color(0xFF767680);
  static const cameraWarning = Color(0xFFF57C00);

  // ── Chart palette (indigo / grey family) ──────────────────────────────
  static const chartPalette = <Color>[
    Color(0xFF293154),
    Color(0xFF4A5578),
    Color(0xFF6B6B78),
    Color(0xFF3D5A8A),
    Color(0xFF1A2040),
    Color(0xFF44444F),
    Color(0xFF5C6FA0),
    Color(0xFF8E8E96),
    Color(0xFF2C2C34),
    Color(0xFF7585B0),
    Color(0xFF343438),
    Color(0xFF9FA4B8),
  ];
}
