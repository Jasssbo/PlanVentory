import 'package:flutter/material.dart';

/// App color palette
class AppColors {
  AppColors._();

  // Brand colors
  static const Color primary = Color(0xFF6366F1);       // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  static const Color secondary = Color(0xFF10B981);     // Emerald
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color secondaryDark = Color(0xFF059669);

  // Semantic colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Neutral colors
  static const Color background = Color(0xFFEEF2F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE2E8F0);

  // Text colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textHint = Color(0xFF64748B);

  // Icon colors for better visibility
  static const Color iconOnSurface = Color(0xFF334155);
  static const Color iconOnSurfaceDark = Color(0xFFCBD5E1);

  // Dark theme colors
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariantDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Event status colors
  static const Color statusUpcoming = Color(0xFF3B82F6);
  static const Color statusOngoing = Color(0xFF22C55E);
  static const Color statusCompleted = Color(0xFF64748B);
  static const Color statusCancelled = Color(0xFFEF4444);

  // Warning severity colors
  static const Color severityCritical = Color(0xFFEF4444);
  static const Color severityWarning = Color(0xFFF59E0B);
  static const Color severityInfo = Color(0xFF3B82F6);
}
