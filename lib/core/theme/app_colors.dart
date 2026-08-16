import 'package:flutter/material.dart';

/// Palet warna Kasir Pro — Dark Mode + Neon Green.
/// Nama-nama lama (sand*, charcoal*, emerald*) dipertahankan supaya seluruh
/// layar yang sudah dibuat otomatis ikut berubah tanpa perlu diedit satu-satu,
/// tapi nilainya sekarang mengarah ke skema gelap.
class AppColors {
  AppColors._();

  // Emerald — sekarang jadi aksen NEON GREEN (primary/aksi utama)
  static const Color emerald50 = Color(0xFF0F2A20);   // tint gelap untuk bg badge/chip
  static const Color emerald100 = Color(0xFF123A29);  // bg chip terpilih
  static const Color emerald200 = Color(0xFF1B5C3E);
  static const Color emerald400 = Color(0xFF19D97A);
  static const Color emerald500 = Color(0xFF12E27E);
  static const Color emerald600 = Color(0xFF00E676);  // neon green utama — tombol, aksen
  static const Color emerald700 = Color(0xFF2CF39A);  // teks aksen terang di atas bg gelap

  // Charcoal — sekarang jadi TEKS (di atas background gelap, ini yang paling terang)
  static const Color charcoal900 = Color(0xFFF3F6F5); // teks utama (hampir putih)
  static const Color charcoal800 = Color(0xFFD7DEDC);
  static const Color charcoal700 = Color(0xFFAAB6B2);
  static const Color charcoal500 = Color(0xFF8A9A95); // teks sekunder/label
  static const Color charcoal300 = Color(0xFF5B6B66); // teks tersier/disabled

  // Sand — sekarang jadi SURFACE gelap (latar & panel)
  static const Color sand50 = Color(0xFF0A1210);   // scaffold background (paling gelap)
  static const Color sand100 = Color(0xFF141F1C);  // surface/card
  static const Color sand200 = Color(0xFF223330);  // border halus
  static const Color sand300 = Color(0xFF34473F);  // border lebih tegas / divider kuat

  // Alias eksplisit biar jelas dipakai di mana (dipakai file baru: sidebar, dsb.)
  static const Color background = sand50;
  static const Color surface = sand100;
  static const Color surfaceElevated = Color(0xFF1B2925);
  static const Color border = sand200;
  static const Color textPrimary = charcoal900;
  static const Color textSecondary = charcoal500;
  static const Color textDisabled = charcoal300;
  static const Color neonGreen = emerald600;
  static const Color neonGreenBright = emerald700;

  // Semantik
  static const Color danger = Color(0xFFFF5C72);
  static const Color dangerBg = Color(0xFF2E1218);
  static const Color warning = Color(0xFFFFB238);
  static const Color warningBg = Color(0xFF2E230E);
  static const Color info = Color(0xFF4EA1FF);
  static const Color infoBg = Color(0xFF10202E);

  static const Color success = emerald600;
  static const Color successBg = emerald50;
}
