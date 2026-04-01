import 'package:flutter/material.dart';

/// BuildContext extension that returns the correct color for the current theme
/// (dark or light). Import this file and call e.g. `context.scaffoldBg`.
extension AppColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Backgrounds ────────────────────────────────────────────────────────────
  Color get scaffoldBg =>
      _isDark ? const Color(0xFF0B0B0B) : Colors.white;

  Color get cardBg =>
      _isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2);

  Color get inputFillBg =>
      _isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

  Color get appBarBg =>
      _isDark ? const Color(0xFF0B0B0B) : Colors.white;

  // ── Dividers & Borders ─────────────────────────────────────────────────────
  Color get dividerColor =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFDDDDDD);

  Color get borderColor =>
      _isDark ? const Color(0xFF333333) : const Color(0xFFCCCCCC);

  // ── Text ───────────────────────────────────────────────────────────────────
  Color get primaryText =>
      _isDark ? Colors.white : const Color(0xFF1A1A1A);

  Color get secondaryText =>
      _isDark ? const Color(0xFFB8B8B8) : const Color(0xFF555555);

  Color get hintText =>
      _isDark ? const Color(0xFF666666) : const Color(0xFF999999);

  Color get tertiaryText =>
      _isDark ? const Color(0xFF999999) : const Color(0xFF777777);

  // ── Icons ──────────────────────────────────────────────────────────────────
  Color get iconColor =>
      _isDark ? Colors.white : const Color(0xFF1A1A1A);

  Color get chevronColor =>
      _isDark ? Colors.white : const Color(0xFF555555);

  // ── Accent (same in both themes) ───────────────────────────────────────────
  Color get accent => const Color(0xFF00B4D8);
}
