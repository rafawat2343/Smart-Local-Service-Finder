import 'package:flutter/material.dart';

class AppColors {
  // ── Brand Authority ─────────────────────────────────────────────────────────
  static const navy        = Color(0xFF1C2B3A);
  static const navyDark    = Color(0xFF111D28);
  static const navyMid     = Color(0xFF2C3E50);
  static const navyLight   = Color(0xFFEDF1F5);
  static const navySubtle  = Color(0xFFF4F6F9);

  // ── Accent (single, controlled) ─────────────────────────────────────────────
  static const accent      = Color(0xFFD4541A);
  static const accentLight = Color(0xFFFAEDE7);
  static const accentDark  = Color(0xFFAA4114);

  // ── Surfaces ────────────────────────────────────────────────────────────────
  static const background  = Color(0xFFF4F6F9);
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceAlt  = Color(0xFFF9FAFB);

  // ── Text ────────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1C2B3A);
  static const textSecondary = Color(0xFF5A6E82);
  static const textTertiary  = Color(0xFF98A8B8);
  static const textInverse   = Color(0xFFFFFFFF);

  // ── Structure ───────────────────────────────────────────────────────────────
  static const border      = Color(0xFFDDE3EA);
  static const borderStrong= Color(0xFFBEC9D5);
  static const divider     = Color(0xFFEEF2F5);

  // ── Status ──────────────────────────────────────────────────────────────────
  static const success     = Color(0xFF1A7A5E);
  static const successBg   = Color(0xFFE6F4F0);
  static const urgent      = Color(0xFFBF3030);
  static const urgentBg    = Color(0xFFFAEAEA);
  static const star        = Color(0xFFC8880A);
  static const starBg      = Color(0xFFFAF3E0);

  // ── Legacy aliases ──────────────────────────────────────────────────────────
  static const primary         = navy;
  static const primaryDark     = navyDark;
  static const primaryLight    = navyLight;
  static const primaryMid      = navyMid;
  static const surfaceElevated = surfaceAlt;
  static const textHint        = textTertiary;
}
