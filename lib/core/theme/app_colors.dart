import 'package:flutter/material.dart';

class AppColors {
  // Ultra Premium Dark Theme (Matching Web Bank)
  static const Color background = Color(0xFF020817); // Web Bank Background
  static const Color surface = Color(0xFF0F172A); // Slate-900 surface
  static const Color surfaceHighlight = Color(0xFF1E293B); // Slate-800 highlight
  
  static const Color primary = Color(0xFF10B981); // Web Bank Emerald
  static const Color primaryDark = Color(0xFF059669);
  static const Color secondary = Color(0xFF34D399);
  
  static const Color error = Color(0xFFEF4444); // Slate Red
  
  static const Color textPrimary = Color(0xFFFFFFFF); // White Text
  static const Color textSecondary = Color(0xFF9CA3AF); // Slate-400 text
  
  static const Color border = Color(0xFF1E293B);
  
  // Gradients
  static const LinearGradient walletGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF020817)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
