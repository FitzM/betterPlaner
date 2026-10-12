import 'package:flutter/material.dart';

class PlanColors {
  // Brand colors
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color accent = Color(0xFF0EA5E9);

  // Backgrounds & Neutrals - Light Mode
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSidebar = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Backgrounds & Neutrals - Dark Mode
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSidebar = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardHover = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Project Tag Palette
  static const List<Color> projectPalette = [
    Color(0xFF64748B), // Slate / Inbox
    Color(0xFF0284C7), // Sky Blue / Work
    Color(0xFF6366F1), // Indigo / Personal
    Color(0xFF10B981), // Emerald / Health
    Color(0xFFF59E0B), // Amber / Side Project
    Color(0xFFF43F5E), // Rose / Urgent
    Color(0xFF8B5CF6), // Purple / Creative
    Color(0xFF14B8A6), // Teal / Errands
  ];

  // Priority Colors
  static const Color priorityUrgent = Color(0xFFEF4444);
  static const Color priorityHigh = Color(0xFFF97316);
  static const Color priorityMedium = Color(0xFF3B82F6);
  static const Color priorityLow = Color(0xFF94A3B8);

  // Time indicator
  static const Color currentTimeIndicator = Color(0xFFEF4444);
}
