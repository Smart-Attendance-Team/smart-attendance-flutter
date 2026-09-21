import 'package:flutter/material.dart';

/// Design tokens for the whole app. Use these instead of raw colors.
abstract class AppColors {
  static const primary = Color(0xFF1D4ED8);
  static const primaryDark = Color(0xFF1E3A8A);
  static const primaryDarker = Color(0xFF172554);
  static const primaryLight = Color(0xFFDBEAFE);
  static const accent = Color(0xFF0D9488);
  static const accentLight = Color(0xFFCCFBF1);

  static const background = Color(0xFFF1F5F9);
  static const surface = Colors.white;

  static const textDark = Color(0xFF0F172A);
  static const textGrey = Color(0xFF64748B);

  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFEF3C7);
  static const error = Color(0xFFDC2626);
  static const errorBg = Color(0xFFFEE2E2);
  static const info = Color(0xFF2563EB);
  static const infoBg = Color(0xFFDBEAFE);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, Color(0xFF3B82F6)],
  );

  /// Pill colors for attendance / request statuses.
  static (Color, Color) statusColors(String status) {
    switch (status.toLowerCase()) {
      case 'present':
      case 'approved':
        return (success, successBg);
      case 'late':
        return (warning, warningBg);
      case 'absent':
      case 'rejected':
        return (error, errorBg);
      case 'excused':
      case 'pending':
      case 'duplicate':
        return (info, infoBg);
      default:
        return (textGrey, background);
    }
  }
}
